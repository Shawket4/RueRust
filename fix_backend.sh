#!/usr/bin/env bash
# =============================================================================
#  RuePOS Backend — Bug Fixes + HTTPS Support
#
#  Fixes:
#    #2  Order number race condition (pg_advisory_xact_lock)
#    #6  get_current_shift opened_at alias (sed patch)
#    #8  Upload handler operation order (write→DB→delete old)
#    #9  Void order with optional inventory restoration
#    #38 HTTPS via rustls (reads SSL_CERT_FILE + SSL_KEY_FILE from .env)
#
#  Usage:  bash fix_backend.sh [path/to/rue-rust]
#  Default: current directory (.)
# =============================================================================
set -e
PROJ="${1:-.}"
[ -d "$PROJ" ] || { echo "ERROR: Directory not found: $PROJ"; exit 1; }
echo "==> Patching rue-rust at: $(cd "$PROJ" && pwd)"

write() {
  local dest="$PROJ/$1"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest"
  echo "  written: $1"
}

# ──────────────────────────────────────────────────────────────────────
# src/orders/handlers.rs
# ──────────────────────────────────────────────────────────────────────
write 'src/orders/handlers.rs' << 'RUST_EOF'
use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use sqlx::PgPool;
use uuid::Uuid;
use serde::{Deserialize, Serialize};
use crate::{auth::jwt::Claims, errors::AppError, models::UserRole, permissions::checker::check_permission};

// ── helpers ───────────────────────────────────────────────────────────────────
fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions().get::<Claims>().cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

// ── request types ─────────────────────────────────────────────────────────────
#[derive(Deserialize)]
pub struct CreateOrderRequest {
    pub shift_id:       Uuid,
    pub payment_method: String,
    pub customer_name:  Option<String>,
    pub notes:          Option<String>,
    pub discount_type:  Option<String>,
    pub discount_value: Option<i32>,
    pub items: Vec<OrderItemRequest>,
}

#[derive(Deserialize)]
pub struct OrderItemRequest {
    pub menu_item_id: Uuid,
    pub size_label:   Option<String>,
    pub quantity:     i32,
    pub notes:        Option<String>,
    pub addons:       Option<Vec<AddonRequest>>,
}

#[derive(Deserialize)]
pub struct AddonRequest {
    pub addon_item_id:        Uuid,
    pub drink_option_item_id: Option<Uuid>,
}

#[derive(Deserialize)]
pub struct VoidOrderRequest {
    pub reason:             Option<String>,
    pub restore_inventory:  Option<bool>,
}

#[derive(Deserialize)]
pub struct ListOrdersQuery {
    pub shift_id:  Option<Uuid>,
    pub branch_id: Option<Uuid>,
}

// ── POST /orders ───────────────────────────────────────────────────────────────
pub async fn create_order(
    req:     HttpRequest,
    pool:    web::Data<PgPool>,
    payload: web::Json<CreateOrderRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "create").await?;

    let shift_id = payload.shift_id;

    // Verify shift is open and belongs to a branch the teller can access
    let shift_row = sqlx::query!(
        r#"SELECT id, branch_id, status FROM shifts WHERE id = $1"#,
        shift_id
    )
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Shift not found".into()))?;

    if shift_row.status != "open" {
        return Err(AppError::BadRequest("Shift is not open".into()));
    }

    let branch_id = shift_row.branch_id;

    // ── Transactional order creation with advisory lock ───────────────────────
    // pg_advisory_xact_lock serialises order creation per shift,
    // preventing duplicate order_number under concurrent requests.
    let mut tx = pool.begin().await?;

    // Lock on the shift_id hash — released automatically at transaction end
    sqlx::query!("SELECT pg_advisory_xact_lock(hashtext($1::text))", shift_id.to_string())
        .execute(&mut *tx)
        .await?;

    // Safe MAX+1 inside the locked transaction
    let order_number: i32 = sqlx::query_scalar!(
        "SELECT COALESCE(MAX(order_number), 0) + 1 FROM orders WHERE shift_id = $1",
        shift_id
    )
    .fetch_one(&mut *tx)
    .await?
    .unwrap_or(1);

    // Resolve pricing
    let org_id: Uuid = sqlx::query_scalar!(
        "SELECT org_id FROM branches WHERE id = $1",
        branch_id
    )
    .fetch_one(&mut *tx)
    .await?;

    let tax_rate: bigdecimal::BigDecimal = sqlx::query_scalar!(
        "SELECT tax_rate FROM organizations WHERE id = $1",
        org_id
    )
    .fetch_one(&mut *tx)
    .await?
    .unwrap_or_else(|| bigdecimal::BigDecimal::from(0));

    let teller_id = claims.sub;
    let teller_name: String = sqlx::query_scalar!(
        "SELECT name FROM users WHERE id = $1",
        teller_id
    )
    .fetch_one(&mut *tx)
    .await?;

    // Calculate subtotal
    let mut subtotal: i32 = 0;
    for item in &payload.items {
        let base_price: i32 = {
            let bp: i32 = sqlx::query_scalar!(
                "SELECT base_price FROM menu_items WHERE id = $1",
                item.menu_item_id
            )
            .fetch_one(&mut *tx)
            .await?;
            if let Some(ref size) = item.size_label {
                sqlx::query_scalar!(
                    "SELECT price_override FROM menu_item_sizes WHERE menu_item_id = $1 AND label = $2",
                    item.menu_item_id, size
                )
                .fetch_optional(&mut *tx)
                .await?
                .unwrap_or(bp)
            } else {
                bp
            }
        };

        let mut addon_total: i32 = 0;
        if let Some(ref addons) = item.addons {
            for addon in addons {
                let price: i32 = sqlx::query_scalar!(
                    "SELECT default_price FROM addon_items WHERE id = $1",
                    addon.addon_item_id
                )
                .fetch_one(&mut *tx)
                .await?;
                addon_total += price;
            }
        }

        subtotal += (base_price + addon_total) * item.quantity;
    }

    // Discount
    let discount_amount: i32 = match (payload.discount_type.as_deref(), payload.discount_value) {
        (Some("percent"), Some(v)) => (subtotal as f64 * v as f64 / 100.0) as i32,
        (Some("amount"),  Some(v)) => v.min(subtotal),
        _ => 0,
    };

    let taxable      = subtotal - discount_amount;
    let tax_rate_f64: f64 = tax_rate.to_string().parse().unwrap_or(0.0);
    let tax_amount   = (taxable as f64 * tax_rate_f64) as i32;
    let total_amount = taxable + tax_amount;

    // Insert order
    let order_id = Uuid::new_v4();
    sqlx::query!(
        r#"INSERT INTO orders
           (id, branch_id, shift_id, teller_id, order_number, status,
            payment_method, customer_name, notes,
            discount_type, discount_value, discount_amount,
            tax_amount, subtotal, total_amount)
           VALUES ($1,$2,$3,$4,$5,'active',$6,$7,$8,$9,$10,$11,$12,$13,$14)"#,
        order_id, branch_id, shift_id, teller_id, order_number,
        payload.payment_method,
        payload.customer_name,
        payload.notes,
        payload.discount_type,
        payload.discount_value.unwrap_or(0),
        discount_amount,
        tax_amount,
        subtotal,
        total_amount
    )
    .execute(&mut *tx)
    .await?;

    // Insert order items + deduct inventory
    for item in &payload.items {
        let item_id = Uuid::new_v4();
        let base_price: i32 = {
            let bp: i32 = sqlx::query_scalar!(
                "SELECT base_price FROM menu_items WHERE id = $1",
                item.menu_item_id
            )
            .fetch_one(&mut *tx)
            .await?;
            if let Some(ref size) = item.size_label {
                sqlx::query_scalar!(
                    "SELECT price_override FROM menu_item_sizes WHERE menu_item_id = $1 AND label = $2",
                    item.menu_item_id, size
                )
                .fetch_optional(&mut *tx)
                .await?
                .unwrap_or(bp)
            } else {
                bp
            }
        };

        let mut addon_total: i32 = 0;
        if let Some(ref addons) = item.addons {
            for addon in addons {
                let price: i32 = sqlx::query_scalar!(
                    "SELECT default_price FROM addon_items WHERE id = $1",
                    addon.addon_item_id
                )
                .fetch_one(&mut *tx)
                .await?;
                addon_total += price;
            }
        }

        let unit_price  = base_price + addon_total;
        let line_total  = unit_price * item.quantity;
        let item_name: String = sqlx::query_scalar!(
            "SELECT name FROM menu_items WHERE id = $1",
            item.menu_item_id
        )
        .fetch_one(&mut *tx)
        .await?;

        sqlx::query!(
            r#"INSERT INTO order_items
               (id, order_id, menu_item_id, item_name, size_label,
                unit_price, quantity, line_total, notes)
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)"#,
            item_id,
            order_id,
            item.menu_item_id,
            item_name,
            item.size_label,
            unit_price,
            item.quantity,
            line_total,
            item.notes
        )
        .execute(&mut *tx)
        .await?;

        // Insert addons
        if let Some(ref addons) = item.addons {
            for addon in addons {
                let addon_name: String = sqlx::query_scalar!(
                    "SELECT name FROM addon_items WHERE id = $1",
                    addon.addon_item_id
                )
                .fetch_one(&mut *tx)
                .await?;
                let addon_price: i32 = sqlx::query_scalar!(
                    "SELECT default_price FROM addon_items WHERE id = $1",
                    addon.addon_item_id
                )
                .fetch_one(&mut *tx)
                .await?;

                sqlx::query!(
                    r#"INSERT INTO order_item_addons
                       (id, order_item_id, addon_item_id, drink_option_item_id,
                        addon_name, unit_price, quantity, line_total)
                       VALUES ($1,$2,$3,$4,$5,$6,1,$7)"#,
                    Uuid::new_v4(),
                    item_id,
                    addon.addon_item_id,
                    addon.drink_option_item_id,
                    addon_name,
                    addon_price,
                    addon_price
                )
                .execute(&mut *tx)
                .await?;
            }
        }

        // Deduct inventory based on recipes
        let size_label = item.size_label.as_deref().unwrap_or("one_size");
        let recipes = sqlx::query!(
            r#"SELECT inventory_item_id, quantity_used FROM drink_recipes
               WHERE menu_item_id = $1 AND size_label = $2"#,
            item.menu_item_id, size_label
        )
        .fetch_all(&mut *tx)
        .await?;

        for recipe in recipes {
            let qty_to_deduct = recipe.quantity_used * bigdecimal::BigDecimal::from(item.quantity);
            sqlx::query!(
                "UPDATE inventory_items SET current_stock = current_stock - $1 WHERE id = $2",
                qty_to_deduct, recipe.inventory_item_id
            )
            .execute(&mut *tx)
            .await?;

            sqlx::query!(
                r#"INSERT INTO inventory_deduction_logs
                   (id, order_id, inventory_item_id, quantity_deducted, deduction_type)
                   VALUES ($1,$2,$3,$4,'recipe')"#,
                Uuid::new_v4(), order_id, recipe.inventory_item_id, qty_to_deduct
            )
            .execute(&mut *tx)
            .await?;
        }
    }

    tx.commit().await?;

    // Return the created order
    get_order_by_id(pool.get_ref(), order_id).await
        .map(|o| HttpResponse::Created().json(o))
}

// ── GET /orders ────────────────────────────────────────────────────────────────
pub async fn list_orders(
    req:   HttpRequest,
    pool:  web::Data<PgPool>,
    query: web::Query<ListOrdersQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "read").await?;

    let rows = if let Some(shift_id) = query.shift_id {
        sqlx::query_as!(
            OrderRow,
            r#"SELECT o.id, o.branch_id, o.shift_id, o.teller_id,
                      COALESCE(u.name,'') AS "teller_name!",
                      o.order_number, o.status, o.payment_method,
                      o.customer_name, o.notes,
                      o.discount_type, o.discount_value, o.discount_amount,
                      o.tax_amount, o.subtotal, o.total_amount,
                      o.voided_at, o.void_reason, o.voided_by,
                      o.created_at
               FROM orders o
               LEFT JOIN users u ON u.id = o.teller_id
               WHERE o.shift_id = $1
               ORDER BY o.order_number"#,
            shift_id
        )
        .fetch_all(pool.get_ref())
        .await?
    } else if let Some(branch_id) = query.branch_id {
        sqlx::query_as!(
            OrderRow,
            r#"SELECT o.id, o.branch_id, o.shift_id, o.teller_id,
                      COALESCE(u.name,'') AS "teller_name!",
                      o.order_number, o.status, o.payment_method,
                      o.customer_name, o.notes,
                      o.discount_type, o.discount_value, o.discount_amount,
                      o.tax_amount, o.subtotal, o.total_amount,
                      o.voided_at, o.void_reason, o.voided_by,
                      o.created_at
               FROM orders o
               LEFT JOIN users u ON u.id = o.teller_id
               WHERE o.branch_id = $1
               ORDER BY o.created_at DESC
               LIMIT 100"#,
            branch_id
        )
        .fetch_all(pool.get_ref())
        .await?
    } else {
        return Err(AppError::BadRequest("shift_id or branch_id required".into()));
    };

    Ok(HttpResponse::Ok().json(rows))
}

// ── GET /orders/:id ────────────────────────────────────────────────────────────
pub async fn get_order(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "read").await?;
    get_order_by_id(pool.get_ref(), *id)
        .await
        .map(|o| HttpResponse::Ok().json(o))
}

// ── POST /orders/:id/void ──────────────────────────────────────────────────────
pub async fn void_order(
    req:     HttpRequest,
    pool:    web::Data<PgPool>,
    id:      web::Path<Uuid>,
    payload: web::Json<VoidOrderRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "update").await?;

    // Check order exists and is not already voided
    let order = sqlx::query!(
        "SELECT id, status FROM orders WHERE id = $1",
        *id
    )
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Order not found".into()))?;

    if order.status == "voided" {
        return Err(AppError::BadRequest("Order is already voided".into()));
    }

    let mut tx = pool.begin().await?;

    // Void the order
    sqlx::query!(
        r#"UPDATE orders
           SET status = 'voided',
               void_reason = $1,
               voided_by   = $2,
               voided_at   = now()
           WHERE id = $3"#,
        payload.reason,
        claims.sub,
        *id
    )
    .execute(&mut *tx)
    .await?;

    // Optionally restore inventory
    if payload.restore_inventory.unwrap_or(false) {
        // Fetch all deduction logs for this order
        let logs = sqlx::query!(
            r#"SELECT inventory_item_id, quantity_deducted
               FROM inventory_deduction_logs
               WHERE order_id = $1"#,
            *id
        )
        .fetch_all(&mut *tx)
        .await?;

        for log in &logs {
            // Add stock back
            sqlx::query!(
                "UPDATE inventory_items SET current_stock = current_stock + $1 WHERE id = $2",
                log.quantity_deducted, log.inventory_item_id
            )
            .execute(&mut *tx)
            .await?;

            // Log the restoration as an adjustment
            sqlx::query!(
                r#"INSERT INTO inventory_adjustments
                   (id, inventory_item_id, adjustment_type, quantity, notes, created_by)
                   VALUES ($1, $2, 'add', $3, 'Void reversal for order', $4)"#,
                Uuid::new_v4(),
                log.inventory_item_id,
                log.quantity_deducted,
                claims.sub
            )
            .execute(&mut *tx)
            .await?;
        }

        tracing::info!(
            "Restored inventory for voided order {} ({} deductions reversed)",
            id,
            logs.len()
        );
    }

    tx.commit().await?;

    get_order_by_id(pool.get_ref(), *id)
        .await
        .map(|o| HttpResponse::Ok().json(o))
}

// ── internal: fetch full order with items ─────────────────────────────────────
#[derive(Serialize, sqlx::FromRow)]
pub struct OrderRow {
    pub id:              Uuid,
    pub branch_id:       Uuid,
    pub shift_id:        Uuid,
    pub teller_id:       Option<Uuid>,
    pub teller_name:     String,
    pub order_number:    i32,
    pub status:          String,
    pub payment_method:  String,
    pub customer_name:   Option<String>,
    pub notes:           Option<String>,
    pub discount_type:   Option<String>,
    pub discount_value:  i32,
    pub discount_amount: i32,
    pub tax_amount:      i32,
    pub subtotal:        i32,
    pub total_amount:    i32,
    pub voided_at:       Option<chrono::DateTime<chrono::Utc>>,
    pub void_reason:     Option<String>,
    pub voided_by:       Option<Uuid>,
    pub created_at:      chrono::DateTime<chrono::Utc>,
}

async fn get_order_by_id(pool: &PgPool, id: Uuid) -> Result<serde_json::Value, AppError> {
    let order = sqlx::query_as!(
        OrderRow,
        r#"SELECT o.id, o.branch_id, o.shift_id, o.teller_id,
                  COALESCE(u.name,'') AS "teller_name!",
                  o.order_number, o.status, o.payment_method,
                  o.customer_name, o.notes,
                  o.discount_type, o.discount_value, o.discount_amount,
                  o.tax_amount, o.subtotal, o.total_amount,
                  o.voided_at, o.void_reason, o.voided_by,
                  o.created_at
           FROM orders o
           LEFT JOIN users u ON u.id = o.teller_id
           WHERE o.id = $1"#,
        id
    )
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Order not found".into()))?;

    let items = sqlx::query!(
        r#"SELECT
             oi.id, oi.menu_item_id, oi.item_name, oi.size_label,
             oi.unit_price, oi.quantity, oi.line_total, oi.notes,
             COALESCE(
               json_agg(
                 json_build_object(
                   'id',            oia.id,
                   'addon_item_id', oia.addon_item_id,
                   'addon_name',    oia.addon_name,
                   'unit_price',    oia.unit_price,
                   'quantity',      oia.quantity,
                   'line_total',    oia.line_total
                 ) ORDER BY oia.addon_name
               ) FILTER (WHERE oia.id IS NOT NULL),
               '[]'::json
             ) AS "addons!"
           FROM order_items oi
           LEFT JOIN order_item_addons oia ON oia.order_item_id = oi.id
           WHERE oi.order_id = $1
           GROUP BY oi.id
           ORDER BY oi.id"#,
        id
    )
    .fetch_all(pool)
    .await?;

    let items_json: Vec<serde_json::Value> = items.iter().map(|i| serde_json::json!({
        "id":         i.id,
        "menu_item_id": i.menu_item_id,
        "item_name":  i.item_name,
        "size_label": i.size_label,
        "unit_price": i.unit_price,
        "quantity":   i.quantity,
        "line_total": i.line_total,
        "notes":      i.notes,
        "addons":     i.addons,
    })).collect();

    Ok(serde_json::json!({
        "id":              order.id,
        "branch_id":       order.branch_id,
        "shift_id":        order.shift_id,
        "teller_id":       order.teller_id,
        "teller_name":     order.teller_name,
        "order_number":    order.order_number,
        "status":          order.status,
        "payment_method":  order.payment_method,
        "customer_name":   order.customer_name,
        "notes":           order.notes,
        "discount_type":   order.discount_type,
        "discount_value":  order.discount_value,
        "discount_amount": order.discount_amount,
        "tax_amount":      order.tax_amount,
        "subtotal":        order.subtotal,
        "total_amount":    order.total_amount,
        "voided_at":       order.voided_at,
        "void_reason":     order.void_reason,
        "voided_by":       order.voided_by,
        "created_at":      order.created_at,
        "items":           items_json,
    }))
}

RUST_EOF

# ──────────────────────────────────────────────────────────────────────
# src/uploads/handlers.rs
# ──────────────────────────────────────────────────────────────────────
write 'src/uploads/handlers.rs' << 'RUST_EOF'
use actix_multipart::Multipart;
use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use futures::StreamExt;
use image::ImageReader;
use serde::Serialize;
use sqlx::PgPool;
use std::{io::Cursor, path::{Path, PathBuf}};
use uuid::Uuid;
use crate::{auth::jwt::Claims, errors::AppError, models::UserRole, permissions::checker::check_permission};

const ALLOWED_MIME: &[&str] = &[
    "image/jpeg","image/png","image/gif","image/webp",
    "image/bmp","image/x-bmp","image/x-ms-bmp",
];
const MAX_BYTES: usize = 2 * 1024 * 1024;

#[derive(Serialize)]
pub struct UploadResponse { pub image_url: String }

pub async fn upload_menu_item_image(
    req:          HttpRequest,
    pool:         web::Data<PgPool>,
    menu_item_id: web::Path<Uuid>,
    mut payload:  Multipart,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let row: Option<(Uuid, Option<String>)> = sqlx::query_as(
        "SELECT org_id, image_url FROM menu_items WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(*menu_item_id)
    .fetch_optional(pool.get_ref())
    .await?;

    let (org_id, old_image_url) = row
        .ok_or_else(|| AppError::NotFound("Menu item not found".into()))?;

    if claims.role != UserRole::SuperAdmin {
        if claims.org_id() != Some(org_id) {
            return Err(AppError::Forbidden("Menu item belongs to a different org".into()));
        }
    }

    let uploads_dir = std::env::var("UPLOADS_DIR").map_err(|_| AppError::Internal)?;
    let base_url    = std::env::var("UPLOADS_BASE_URL").map_err(|_| AppError::Internal)?;

    let mut file_bytes: Option<Vec<u8>> = None;

    while let Some(item) = payload.next().await {
        let mut field = item.map_err(|_| AppError::BadRequest("Invalid multipart data".into()))?;
        let content_type = field.content_type().map(|m| m.to_string()).unwrap_or_default();
        let field_name   = field
            .content_disposition()
            .and_then(|cd| cd.get_name())
            .unwrap_or("")
            .to_string();

        if field_name != "image" { continue; }
        if !ALLOWED_MIME.contains(&content_type.as_str()) {
            return Err(AppError::BadRequest(format!("Unsupported image type: {}", content_type)));
        }

        let mut bytes = Vec::new();
        while let Some(chunk) = field.next().await {
            let chunk = chunk.map_err(|_| AppError::BadRequest("Failed reading upload".into()))?;
            bytes.extend_from_slice(&chunk);
            if bytes.len() > 20 * 1024 * 1024 {
                return Err(AppError::BadRequest("File too large (max 20 MB raw)".into()));
            }
        }
        file_bytes = Some(bytes);
        break;
    }

    let raw_bytes = file_bytes
        .ok_or_else(|| AppError::BadRequest("No image field found in upload".into()))?;

    let jpeg_bytes = compress_to_jpeg(&raw_bytes)?;

    let filename  = format!("{}.jpg", Uuid::new_v4());
    let dir_path  = Path::new(&uploads_dir).join(org_id.to_string()).join("menu-items");
    tokio::fs::create_dir_all(&dir_path).await.map_err(|e| {
        tracing::error!("Failed to create upload dir: {}", e); AppError::Internal
    })?;
    let file_path: PathBuf = dir_path.join(&filename);

    // 1. Write new file to disk first
    tokio::fs::write(&file_path, &jpeg_bytes).await.map_err(|e| {
        tracing::error!("Failed to write image: {}", e); AppError::Internal
    })?;

    let base      = base_url.trim_end_matches('/');
    let image_url = format!("{}/uploads/{}/menu-items/{}", base, org_id, filename);

    // 2. Update DB — if this fails, clean up the newly written file
    if let Err(e) = sqlx::query("UPDATE menu_items SET image_url = $1 WHERE id = $2")
        .bind(&image_url)
        .bind(*menu_item_id)
        .execute(pool.get_ref())
        .await
    {
        let _ = tokio::fs::remove_file(&file_path).await;
        tracing::error!("DB update failed, cleaned up new file: {}", e);
        return Err(AppError::from(e));
    }

    // 3. Delete old image ONLY after successful DB update
    if let Some(old_url) = old_image_url {
        delete_old_image(&old_url, &base_url, &uploads_dir).await;
    }

    tracing::info!("Uploaded image for menu_item {} → {} ({} KB)",
        menu_item_id, image_url, jpeg_bytes.len() / 1024);

    Ok(HttpResponse::Ok().json(UploadResponse { image_url }))
}

fn compress_to_jpeg(raw: &[u8]) -> Result<Vec<u8>, AppError> {
    let img = ImageReader::new(Cursor::new(raw))
        .with_guessed_format()
        .map_err(|_| AppError::BadRequest("Could not decode image".into()))?
        .decode()
        .map_err(|e| AppError::BadRequest(format!("Invalid image: {}", e)))?;

    let qualities: &[u8] = if raw.len() <= MAX_BYTES { &[85] } else { &[85, 75, 65, 50, 40] };
    for &quality in qualities {
        let mut buf = Cursor::new(Vec::new());
        let mut enc = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut buf, quality);
        enc.encode_image(&img)
            .map_err(|e| AppError::BadRequest(format!("Encoding failed: {}", e)))?;
        let bytes = buf.into_inner();
        if bytes.len() <= MAX_BYTES || quality == 40 { return Ok(bytes); }
    }
    Err(AppError::Internal)
}

async fn delete_old_image(old_url: &str, base_url: &str, uploads_dir: &str) {
    let prefix = format!("{}/uploads/", base_url.trim_end_matches('/'));
    if let Some(rel) = old_url.strip_prefix(&prefix) {
        let full = Path::new(uploads_dir).join(rel);
        if full.exists() {
            if let Err(e) = tokio::fs::remove_file(&full).await {
                tracing::warn!("Could not delete old image {:?}: {}", full, e);
            }
        }
    }
}

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions().get::<Claims>().cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

RUST_EOF

# ──────────────────────────────────────────────────────────────────────
# src/main.rs
# ──────────────────────────────────────────────────────────────────────
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
use std::{env, fs};
use tracing_subscriber::EnvFilter;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let db_url      = env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let uploads_dir = env::var("UPLOADS_DIR").unwrap_or_else(|_| "./uploads".to_string());

    fs::create_dir_all(&uploads_dir).expect("Failed to create uploads directory");

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .connect(&db_url)
        .await
        .expect("Failed to connect to PostgreSQL");

    let pool          = web::Data::new(pool);
    let uploads_clone = uploads_dir.clone();
    let bind_addr     = env::var("BIND_ADDR").unwrap_or_else(|_| "0.0.0.0:8080".to_string());
    let https_port    = env::var("HTTPS_PORT").unwrap_or_else(|_| "8443".to_string());
    let https_addr    = format!("0.0.0.0:{}", https_port);

    let tls_config = build_tls_config();

    tracing::info!("Starting rue-rust");
    tracing::info!("Uploads directory: {}", uploads_dir);

    let server = HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .wrap(cors)
            .app_data(pool.clone())
            .service(Files::new("/uploads", &uploads_clone).use_last_modified(true))
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
    });

    if let Some(tls) = tls_config {
        tracing::info!("HTTPS on {}", https_addr);
        tracing::info!("HTTP  on {}", bind_addr);
        server.bind(&bind_addr)?.bind_rustls_0_23(&https_addr, tls)?.run().await
    } else {
        tracing::info!("HTTP on {} (no TLS certs found)", bind_addr);
        server.bind(&bind_addr)?.run().await
    }
}

fn build_tls_config() -> Option<rustls::ServerConfig> {
    let cert_file = env::var("SSL_CERT_FILE").ok()?;
    let key_file  = env::var("SSL_KEY_FILE").ok()?;
    if cert_file.is_empty() || key_file.is_empty() { return None; }

    let cert_pem = fs::read(&cert_file).ok().or_else(|| {
        tracing::warn!("SSL_CERT_FILE not found: {}", cert_file); None
    })?;
    let key_pem = fs::read(&key_file).ok().or_else(|| {
        tracing::warn!("SSL_KEY_FILE not found: {}", key_file); None
    })?;

    let certs: Vec<rustls::pki_types::CertificateDer> =
        rustls_pemfile::certs(&mut cert_pem.as_slice())
            .filter_map(|c| c.ok()).collect();

    let mut keys: Vec<rustls::pki_types::PrivateKeyDer> =
        rustls_pemfile::pkcs8_private_keys(&mut key_pem.as_slice())
            .filter_map(|k| k.ok().map(rustls::pki_types::PrivateKeyDer::from))
            .collect();

    if keys.is_empty() {
        keys = rustls_pemfile::rsa_private_keys(&mut key_pem.as_slice())
            .filter_map(|k| k.ok().map(rustls::pki_types::PrivateKeyDer::from))
            .collect();
    }

    if certs.is_empty() || keys.is_empty() {
        tracing::warn!("Could not parse TLS certs/keys — falling back to HTTP");
        return None;
    }

    rustls::ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(certs, keys.remove(0))
        .map_err(|e| { tracing::warn!("TLS config error: {}", e); e })
        .ok()
}

RUST_EOF

# ──────────────────────────────────────────────────────────────────────
# Cargo.toml
# ──────────────────────────────────────────────────────────────────────
write 'Cargo.toml' << 'RUST_EOF'
[package]
name = "rue-rust"
version = "0.1.0"
edition = "2024"

[dependencies]
actix-web          = { version = "4", features = ["rustls-0_23"] }
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
rustls             = "0.23"
rustls-pemfile     = "2"
sqlx               = { version = "0.7", features = ["runtime-tokio-rustls", "postgres", "uuid", "chrono", "macros", "bigdecimal"] }
bigdecimal         = { version = "0.3", features = ["serde"] }

RUST_EOF


# =============================================================================
#  Fix #6 — get_current_shift: s.created_at AS opened_at → s.opened_at
#  (single sed replacement in shifts/handlers.rs)
# =============================================================================
SHIFTS_FILE="$PROJ/src/shifts/handlers.rs"
if [ -f "$SHIFTS_FILE" ]; then
    if grep -q "created_at AS opened_at" "$SHIFTS_FILE"; then
        sed -i 's/s\.created_at AS opened_at/s.opened_at/g' "$SHIFTS_FILE"
        echo "  patched: src/shifts/handlers.rs (opened_at alias)"
    else
        echo "  skip:    src/shifts/handlers.rs (alias already fixed or different)"
    fi
else
    echo "  WARN: src/shifts/handlers.rs not found — skipping opened_at patch"
fi

# =============================================================================
#  Patch .env — add SSL vars and new optional env keys
# =============================================================================
ENV_FILE="$PROJ/.env"
touch "$ENV_FILE"

add_env() {
    local key="$1" val="$2"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        echo "  .env: $key already set"
    else
        echo "${key}=${val}" >> "$ENV_FILE"
        echo "  .env: added ${key}=${val}"
    fi
}

echo ""
echo "==> Patching .env..."
add_env "UPLOADS_DIR"        "./uploads"
add_env "UPLOADS_BASE_URL"   "https://yourdomain.com"
add_env "BIND_ADDR"          "0.0.0.0:8080"
add_env "HTTPS_PORT"         "8443"
add_env "SSL_CERT_FILE"      ""
add_env "SSL_KEY_FILE"       ""

echo ""
echo "  NOTE: Set SSL_CERT_FILE and SSL_KEY_FILE in .env to enable HTTPS."
echo "  Example (Let's Encrypt):"
echo "    SSL_CERT_FILE=/etc/letsencrypt/live/yourdomain.com/fullchain.pem"
echo "    SSL_KEY_FILE=/etc/letsencrypt/live/yourdomain.com/privkey.pem"
echo "  When certs are not set, the server falls back to HTTP only."

# =============================================================================
#  Build
# =============================================================================
echo ""
echo "==> Running cargo build --release..."
cd "$PROJ" && cargo build --release

echo ""
echo "========================================"
echo "  Backend fixes applied!"
echo "========================================"
echo ""
echo "Changes:"
echo "  #2  Order numbers now use pg_advisory_xact_lock — no more race condition"
echo "  #6  get_current_shift uses s.opened_at (not s.created_at alias)"
echo "  #8  Upload: write file → update DB → delete old (correct order)"
echo "  #9  POST /orders/:id/void now accepts { restore_inventory: bool }"
echo "       true  → reverses inventory_deduction_logs entries"
echo "       false → voids order only, stock not restored (default)"
echo "  #38 HTTPS via rustls — set SSL_CERT_FILE + SSL_KEY_FILE in .env"
echo "       Falls back to HTTP if certs not found"
echo ""
echo "New .env keys added (edit as needed):"
echo "  BIND_ADDR       — HTTP bind address (default 0.0.0.0:8080)"
echo "  HTTPS_PORT      — HTTPS port (default 8443)"
echo "  SSL_CERT_FILE   — Path to PEM certificate"
echo "  SSL_KEY_FILE    — Path to PEM private key"
echo ""