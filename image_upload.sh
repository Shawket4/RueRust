#!/usr/bin/env bash
# =============================================================================
#  RuePOS Backend — Image Upload Feature
#  Usage:  bash add_image_upload.sh [path/to/rue-rust]
#  Default: current directory (.)
# =============================================================================
set -e
PROJ="${1:-.}"
[ -d "$PROJ" ] || { echo "ERROR: Directory not found: $PROJ"; exit 1; }
echo "==> Updating rue-rust at: $(cd "$PROJ" && pwd)"

write() {
  local dest="$PROJ/$1"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest"
  echo "  written: $1"
}

# ────────────────────────────────────────────────────────────────────────
# src/uploads/mod.rs
# ────────────────────────────────────────────────────────────────────────
write 'src/uploads/mod.rs' << 'RUST_EOF'
pub mod handlers;
pub mod routes;
RUST_EOF

# ────────────────────────────────────────────────────────────────────────
# src/uploads/routes.rs
# ────────────────────────────────────────────────────────────────────────
write 'src/uploads/routes.rs' << 'RUST_EOF'
use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, uploads::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/uploads")
            .service(
                web::scope("/menu-items")
                    .wrap(JwtMiddleware)
                    .route("/{menu_item_id}", web::post().to(handlers::upload_menu_item_image)),
            ),
    );
}
RUST_EOF

# ────────────────────────────────────────────────────────────────────────
# src/uploads/handlers.rs
# ────────────────────────────────────────────────────────────────────────
write 'src/uploads/handlers.rs' << 'RUST_EOF'
use actix_multipart::Multipart;
use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use futures::StreamExt;
use image::{ImageFormat, ImageReader};
use serde::Serialize;
use sqlx::PgPool;
use std::{
    io::Cursor,
    path::{Path, PathBuf},
};
use uuid::Uuid;

use crate::{
    auth::jwt::Claims,
    errors::AppError,
    models::UserRole,
    permissions::checker::check_permission,
};

// Accepted MIME types (all Flutter-supported image formats)
const ALLOWED_MIME: &[&str] = &[
    "image/jpeg",
    "image/png",
    "image/gif",
    "image/webp",
    "image/bmp",
    "image/x-bmp",
    "image/x-ms-bmp",
];

const MAX_BYTES: usize = 2 * 1024 * 1024; // 2 MB target

#[derive(Serialize)]
pub struct UploadResponse {
    pub image_url: String,
}

// ── POST /uploads/menu-items/:menu_item_id ────────────────────────────────────
pub async fn upload_menu_item_image(
    req:          HttpRequest,
    pool:         web::Data<PgPool>,
    menu_item_id: web::Path<Uuid>,
    mut payload:  Multipart,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    // Fetch menu item — verify it exists and get org_id
    let row: Option<(Uuid, Option<String>)> = sqlx::query_as(
        "SELECT org_id, image_url FROM menu_items WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(*menu_item_id)
    .fetch_optional(pool.get_ref())
    .await?;

    let (org_id, old_image_url) = row
        .ok_or_else(|| AppError::NotFound("Menu item not found".into()))?;

    // Non-super-admins must belong to the same org
    if claims.role != UserRole::SuperAdmin {
        if claims.org_id() != Some(org_id) {
            return Err(AppError::Forbidden("Menu item belongs to a different org".into()));
        }
    }

    // Read env config
    let uploads_dir = std::env::var("UPLOADS_DIR")
        .map_err(|_| AppError::Internal)?;
    let base_url = std::env::var("UPLOADS_BASE_URL")
        .map_err(|_| AppError::Internal)?;

    // Read multipart field named "image"
    let mut file_bytes: Option<Vec<u8>> = None;
    let mut detected_mime: Option<String> = None;

    while let Some(item) = payload.next().await {
        let mut field = item.map_err(|_| AppError::BadRequest("Invalid multipart data".into()))?;

        let content_type = field
            .content_type()
            .map(|m| m.to_string())
            .unwrap_or_default();

        // Accept only the "image" field
        let field_name = field
            .content_disposition()
            .and_then(|cd| cd.get_name())
            .unwrap_or("")
            .to_string();

        if field_name != "image" {
            continue;
        }

        if !ALLOWED_MIME.contains(&content_type.as_str()) {
            return Err(AppError::BadRequest(format!(
                "Unsupported image type: {}. Allowed: jpeg, png, gif, webp, bmp",
                content_type
            )));
        }

        detected_mime = Some(content_type);

        // Stream bytes — cap at 20MB raw (before compression)
        let mut bytes = Vec::new();
        while let Some(chunk) = field.next().await {
            let chunk = chunk.map_err(|_| AppError::BadRequest("Failed reading upload".into()))?;
            bytes.extend_from_slice(&chunk);
            if bytes.len() > 20 * 1024 * 1024 {
                return Err(AppError::BadRequest(
                    "File too large (max 20 MB raw before compression)".into(),
                ));
            }
        }

        file_bytes = Some(bytes);
        break;
    }

    let raw_bytes = file_bytes
        .ok_or_else(|| AppError::BadRequest("No image field found in upload".into()))?;
    let _mime = detected_mime
        .ok_or_else(|| AppError::BadRequest("Could not detect image MIME type".into()))?;

    // ── Decode + compress to JPEG ─────────────────────────────────────────────
    let jpeg_bytes = compress_to_jpeg(&raw_bytes)?;

    // ── Build output path: uploads/{org_id}/menu-items/{uuid}.jpg ────────────
    let filename  = format!("{}.jpg", Uuid::new_v4());
    let dir_path  = Path::new(&uploads_dir)
        .join(org_id.to_string())
        .join("menu-items");

    tokio::fs::create_dir_all(&dir_path)
        .await
        .map_err(|e| {
            tracing::error!("Failed to create upload dir: {}", e);
            AppError::Internal
        })?;

    let file_path: PathBuf = dir_path.join(&filename);

    tokio::fs::write(&file_path, &jpeg_bytes)
        .await
        .map_err(|e| {
            tracing::error!("Failed to write image: {}", e);
            AppError::Internal
        })?;

    // ── Delete old image file if it existed ───────────────────────────────────
    if let Some(old_url) = old_image_url {
        delete_old_image(&old_url, &base_url, &uploads_dir).await;
    }

    // ── Build public URL ──────────────────────────────────────────────────────
    let base = base_url.trim_end_matches('/');
    let image_url = format!(
        "{}/uploads/{}/menu-items/{}",
        base,
        org_id,
        filename,
    );

    // ── Update DB ─────────────────────────────────────────────────────────────
    sqlx::query("UPDATE menu_items SET image_url = $1 WHERE id = $2")
        .bind(&image_url)
        .bind(*menu_item_id)
        .execute(pool.get_ref())
        .await?;

    tracing::info!(
        "Uploaded image for menu_item {} → {} ({} KB)",
        menu_item_id,
        image_url,
        jpeg_bytes.len() / 1024
    );

    Ok(HttpResponse::Ok().json(UploadResponse { image_url }))
}

// ── JPEG compression ──────────────────────────────────────────────────────────
fn compress_to_jpeg(raw: &[u8]) -> Result<Vec<u8>, AppError> {
    // Decode from any supported format
    let img = ImageReader::new(Cursor::new(raw))
        .with_guessed_format()
        .map_err(|_| AppError::BadRequest("Could not decode image".into()))?
        .decode()
        .map_err(|e| AppError::BadRequest(format!("Invalid image: {}", e)))?;

    // If already under 2 MB, encode at quality 85 and return
    let qualities: &[u8] = if raw.len() <= MAX_BYTES {
        &[85]
    } else {
        // Try progressively lower quality until under 2 MB
        &[85, 75, 65, 50, 40]
    };

    for &quality in qualities {
        let mut buf = Cursor::new(Vec::new());
        let mut encoder = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut buf, quality);
        encoder
            .encode_image(&img)
            .map_err(|e| AppError::BadRequest(format!("Encoding failed: {}", e)))?;
        let bytes = buf.into_inner();
        if bytes.len() <= MAX_BYTES || quality == 40 {
            return Ok(bytes);
        }
    }

    Err(AppError::Internal) // unreachable
}

// ── Delete old image from disk ────────────────────────────────────────────────
async fn delete_old_image(old_url: &str, base_url: &str, uploads_dir: &str) {
    // Extract path after base_url → relative path on disk
    let base = base_url.trim_end_matches('/');
    let prefix = format!("{}/uploads/", base);
    if let Some(rel) = old_url.strip_prefix(&prefix) {
        let full_path = Path::new(uploads_dir).join(rel);
        if full_path.exists() {
            if let Err(e) = tokio::fs::remove_file(&full_path).await {
                tracing::warn!("Could not delete old image {:?}: {}", full_path, e);
            } else {
                tracing::info!("Deleted old image: {:?}", full_path);
            }
        }
    }
}

// ── Helper ────────────────────────────────────────────────────────────────────
fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}
RUST_EOF

# ────────────────────────────────────────────────────────────────────────
# src/main.rs
# ────────────────────────────────────────────────────────────────────────
write 'src/main.rs' << 'RUST_EOF'
mod auth;
mod errors;
mod models;
mod orgs;
mod permissions;
mod users;
mod branches;
mod menu;
mod inventory;
mod recipes;
mod adjustments;
mod soft_serve;
mod shifts;
mod orders;
mod reports;
mod uploads;

use actix_cors::Cors;
use actix_files::Files;
use actix_web::{web, App, HttpServer};
use dotenvy::dotenv;
use sqlx::postgres::PgPoolOptions;
use std::env;
use tracing_subscriber::EnvFilter;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let db_url     = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let jwt_secret = env::var("JWT_SECRET").expect("JWT_SECRET must be set");
    let uploads_dir = env::var("UPLOADS_DIR").unwrap_or_else(|_| "./uploads".to_string());

    // Ensure uploads root exists on startup
    std::fs::create_dir_all(&uploads_dir)
        .expect("Failed to create uploads directory");

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&db_url)
        .await
        .expect("Failed to connect to PostgreSQL");

    let pool       = web::Data::new(pool);
    let jwt_secret = web::Data::new(auth::jwt::JwtSecret(jwt_secret));
    let uploads_dir_clone = uploads_dir.clone();

    tracing::info!("Starting rue-rust on 0.0.0.0:8080");
    tracing::info!("Uploads directory: {}", uploads_dir);

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .wrap(cors)
            .app_data(pool.clone())
            .app_data(jwt_secret.clone())
            // Static file serving — public, no auth required
            .service(
                Files::new("/uploads", &uploads_dir_clone)
                    // listing disabled by default
                    .use_last_modified(true),
            )
            .configure(auth::routes::configure)
            .configure(orgs::routes::configure)
            .configure(users::routes::configure)
            .configure(permissions::routes::configure)
            .configure(branches::routes::configure)
            .configure(menu::routes::configure)
            .configure(inventory::routes::configure)
            .configure(recipes::routes::configure)
            .configure(adjustments::routes::configure)
            .configure(soft_serve::routes::configure)
            .configure(shifts::routes::configure)
            .configure(orders::routes::configure)
            .configure(reports::routes::configure)
            .configure(uploads::routes::configure)
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
RUST_EOF

# ────────────────────────────────────────────────────────────────────────
# Cargo.toml
# ────────────────────────────────────────────────────────────────────────
write 'Cargo.toml' << 'RUST_EOF'
[package]
name = "rue-rust"
version = "0.1.0"
edition = "2024"

[dependencies]
actix-web          = "4"
actix-cors         = "0.7"
actix-multipart    = "0.7"
actix-files        = "0.6"
tokio              = { version = "1", features = ["full"] }
serde              = { version = "1", features = ["derive"] }
serde_json         = "1"
uuid               = { version = "1", features = ["v4", "serde"] }
chrono             = { version = "0.4", features = ["serde"] }
jsonwebtoken       = "9"
bcrypt             = "0.15"
dotenvy            = "0.15"
thiserror          = "1"
tracing            = "0.1"
tracing-actix-web  = "0.7"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
futures            = "0.3"
image              = { version = "0.25", features = ["jpeg", "png", "gif", "webp", "bmp"] }
sqlx               = { version = "0.7", features = ["runtime-tokio-rustls", "postgres", "uuid", "chrono", "macros", "bigdecimal"] }
bigdecimal         = { version = "0.3", features = ["serde"] }
RUST_EOF

write 'migrations/004_image_upload.sql' << 'SQL_EOF'
-- Migration 004: image upload support
-- No schema changes needed, image_url already exists on menu_items.
SELECT 1;
SQL_EOF


# =============================================================================
#  Patch .env
# =============================================================================
ENV_FILE="$PROJ/.env"
touch "$ENV_FILE"
add_env() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    echo "  .env: $key already set, skipping"
  else
    echo "${key}=${val}" >> "$ENV_FILE"
    echo "  .env: added $key=$val"
  fi
}
echo ""
echo "==> Patching .env..."
add_env "UPLOADS_DIR" "./uploads"
add_env "UPLOADS_BASE_URL" "http://187.124.33.153:8080"

echo ""
echo "==> Creating uploads directory..."
mkdir -p "$PROJ/uploads"

# =============================================================================
#  Build
# =============================================================================
echo ""
echo "==> Running cargo build --release..."
cd "$PROJ" && cargo build --release

echo ""
echo "========================================"
echo "  Image upload feature added!"
echo "========================================"
echo ""
echo "New endpoints:"
echo "  POST /uploads/menu-items/:menu_item_id"
echo "       Content-Type: multipart/form-data, field: image"
echo "       Accepts: JPEG, PNG, GIF, WebP, BMP"
echo "       Compresses to JPEG, max 2MB"
echo "       Returns: { image_url: string }"
echo ""
echo "  GET  /uploads/{org_id}/menu-items/{filename}.jpg  (public)"
echo ""
echo "Update .env if needed:"
echo "  UPLOADS_DIR      — disk path for stored files"
echo "  UPLOADS_BASE_URL — public base URL for image_url responses"
echo ""