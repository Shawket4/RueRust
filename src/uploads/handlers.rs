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
