#!/usr/bin/env bash
# =============================================================================
# Rue POS — Rust backend patch (all 7 features)
# Run from the root of the Rust project (where Cargo.toml lives)
# =============================================================================
set -e

echo "=== Rue POS — Rust backend patch ==="

# ── 1. New module: discounts ──────────────────────────────────────────────────
mkdir -p src/discounts

cat > src/discounts/mod.rs << 'EOF'
pub mod handlers;
pub mod routes;
EOF

cat > src/discounts/routes.rs << 'EOF'
use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, discounts::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/discounts")
            .wrap(JwtMiddleware)
            .route("",      web::get().to(handlers::list_discounts))
            .route("",      web::post().to(handlers::create_discount))
            .route("/{id}", web::patch().to(handlers::update_discount))
            .route("/{id}", web::delete().to(handlers::delete_discount)),
    );
}
EOF

cat > src/discounts/handlers.rs << 'EOF'
use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    auth::jwt::Claims,
    errors::AppError,
    models::UserRole,
};

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Discount {
    pub id:         Uuid,
    pub org_id:     Uuid,
    pub name:       String,
    pub dtype:      String,
    pub value:      i32,
    pub is_active:  bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct ListQuery {
    pub org_id: Uuid,
}

#[derive(Deserialize)]
pub struct CreateDiscountRequest {
    pub org_id:    Uuid,
    pub name:      String,
    pub dtype:     String,
    pub value:     i32,
    pub is_active: Option<bool>,
}

#[derive(Deserialize)]
pub struct UpdateDiscountRequest {
    pub name:      Option<String>,
    pub dtype:     Option<String>,
    pub value:     Option<i32>,
    pub is_active: Option<bool>,
}

pub async fn list_discounts(
    req:   HttpRequest,
    pool:  web::Data<PgPool>,
    query: web::Query<ListQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_org_access(&claims, query.org_id)?;

    let rows = sqlx::query_as::<_, Discount>(
        r#"
        SELECT id, org_id, name, type::text AS dtype, value, is_active, created_at, updated_at
        FROM discounts
        WHERE org_id = $1
        ORDER BY name
        "#,
    )
    .bind(query.org_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

pub async fn create_discount(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateDiscountRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_org_access(&claims, body.org_id)?;
    validate_dtype(&body.dtype)?;
    validate_value(body.value, &body.dtype)?;

    let row = sqlx::query_as::<_, Discount>(
        r#"
        INSERT INTO discounts (org_id, name, type, value, is_active)
        VALUES ($1, $2, $3::discount_type, $4, $5)
        RETURNING id, org_id, name, type::text AS dtype, value, is_active, created_at, updated_at
        "#,
    )
    .bind(body.org_id)
    .bind(&body.name)
    .bind(&body.dtype)
    .bind(body.value)
    .bind(body.is_active.unwrap_or(true))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(row))
}

pub async fn update_discount(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<UpdateDiscountRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    let existing = fetch_or_404(pool.get_ref(), *id).await?;
    require_org_access(&claims, existing.org_id)?;

    if let Some(ref dt) = body.dtype { validate_dtype(dt)?; }
    if let (Some(v), Some(dt)) = (body.value, &body.dtype) { validate_value(v, dt)?; }

    let row = sqlx::query_as::<_, Discount>(
        r#"
        UPDATE discounts SET
            name       = COALESCE($2, name),
            type       = COALESCE($3::discount_type, type),
            value      = COALESCE($4, value),
            is_active  = COALESCE($5, is_active),
            updated_at = NOW()
        WHERE id = $1
        RETURNING id, org_id, name, type::text AS dtype, value, is_active, created_at, updated_at
        "#,
    )
    .bind(*id)
    .bind(&body.name)
    .bind(&body.dtype)
    .bind(body.value)
    .bind(body.is_active)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Discount not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

pub async fn delete_discount(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    let existing = fetch_or_404(pool.get_ref(), *id).await?;
    require_org_access(&claims, existing.org_id)?;

    sqlx::query("DELETE FROM discounts WHERE id = $1")
        .bind(*id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::NoContent().finish())
}

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_or_404(pool: &PgPool, id: Uuid) -> Result<Discount, AppError> {
    sqlx::query_as::<_, Discount>(
        "SELECT id, org_id, name, type::text AS dtype, value, is_active, created_at, updated_at
         FROM discounts WHERE id = $1",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Discount not found".into()))
}

fn require_org_access(claims: &Claims, org_id: Uuid) -> Result<(), AppError> {
    if claims.role == UserRole::SuperAdmin { return Ok(()); }
    if claims.org_id() != Some(org_id) {
        return Err(AppError::Forbidden("Not your org".into()));
    }
    Ok(())
}

fn validate_dtype(dt: &str) -> Result<(), AppError> {
    match dt {
        "percentage" | "fixed" => Ok(()),
        _ => Err(AppError::BadRequest("type must be 'percentage' or 'fixed'".into())),
    }
}

fn validate_value(value: i32, dtype: &str) -> Result<(), AppError> {
    if value < 0 {
        return Err(AppError::BadRequest("value must be >= 0".into()));
    }
    if dtype == "percentage" && value > 100 {
        return Err(AppError::BadRequest("percentage value must be 0-100".into()));
    }
    Ok(())
}
EOF

echo "✓ src/discounts/"

# ── 2. Rewrite orders/handlers.rs ────────────────────────────────────────────
cat > src/orders/handlers.rs << 'EOF'
use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    auth::jwt::Claims,
    errors::AppError,
    models::UserRole,
    permissions::checker::check_permission,
};

// ── Models ────────────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Order {
    pub id:              Uuid,
    pub branch_id:       Uuid,
    pub shift_id:        Uuid,
    pub teller_id:       Uuid,
    pub teller_name:     String,
    pub order_number:    i32,
    pub status:          String,
    pub payment_method:  String,
    pub subtotal:        i32,
    pub discount_type:   Option<String>,
    pub discount_value:  i32,
    pub discount_amount: i32,
    pub tax_amount:      i32,
    pub total_amount:    i32,
    pub amount_tendered: Option<i32>,
    pub change_given:    Option<i32>,
    pub tip_amount:      Option<i32>,
    pub discount_id:     Option<Uuid>,
    pub customer_name:   Option<String>,
    pub notes:           Option<String>,
    pub voided_at:       Option<chrono::DateTime<chrono::Utc>>,
    pub void_reason:     Option<String>,
    pub voided_by:       Option<Uuid>,
    pub created_at:      chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct OrderItem {
    pub id:           Uuid,
    pub order_id:     Uuid,
    pub menu_item_id: Uuid,
    pub item_name:    String,
    pub size_label:   Option<String>,
    pub unit_price:   i32,
    pub quantity:     i32,
    pub line_total:   i32,
    pub notes:        Option<String>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct OrderItemAddon {
    pub id:            Uuid,
    pub order_item_id: Uuid,
    pub addon_item_id: Uuid,
    pub addon_name:    String,
    pub unit_price:    i32,
    pub quantity:      i32,
    pub line_total:    i32,
}

#[derive(Debug, Serialize)]
pub struct OrderFull {
    #[serde(flatten)]
    pub order: Order,
    pub items: Vec<OrderItemFull>,
}

#[derive(Debug, Serialize)]
pub struct OrderItemFull {
    #[serde(flatten)]
    pub item:   OrderItem,
    pub addons: Vec<OrderItemAddon>,
}

#[derive(Deserialize)]
pub struct PaymentSplitInput {
    pub method:    String,
    pub amount:    i32,
    pub reference: Option<String>,
}

#[derive(Deserialize)]
pub struct AddonInput {
    pub addon_item_id:        Uuid,
    pub drink_option_item_id: Uuid,
    #[serde(default = "default_addon_qty")]
    pub quantity: i32,
}

fn default_addon_qty() -> i32 { 1 }

#[derive(Deserialize)]
pub struct OrderItemInput {
    pub menu_item_id: Uuid,
    pub size_label:   Option<String>,
    pub quantity:     i32,
    pub addons:       Vec<AddonInput>,
    pub notes:        Option<String>,
}

#[derive(Deserialize)]
pub struct CreateOrderRequest {
    pub branch_id:       Uuid,
    pub shift_id:        Uuid,
    pub payment_method:  String,
    pub customer_name:   Option<String>,
    pub notes:           Option<String>,
    pub discount_type:   Option<String>,
    pub discount_value:  Option<i32>,
    pub discount_id:     Option<Uuid>,
    pub amount_tendered: Option<i32>,
    pub tip_amount:      Option<i32>,
    pub payment_splits:  Option<Vec<PaymentSplitInput>>,
    pub items:           Vec<OrderItemInput>,
    pub created_at:      Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Deserialize)]
pub struct VoidOrderRequest {
    pub reason:            String,
    pub restore_inventory: Option<bool>,
    pub voided_at:         Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Deserialize)]
pub struct ListOrdersQuery {
    pub branch_id:     Option<Uuid>,
    pub shift_id:      Option<Uuid>,
    pub updated_after: Option<chrono::DateTime<chrono::Utc>>,
}

// ── POST /orders ──────────────────────────────────────────────

pub async fn create_order(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateOrderRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "create").await?;
    require_branch_access(pool.get_ref(), &claims, body.branch_id).await?;

    let idempotency_key = req
        .headers()
        .get("Idempotency-Key")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| Uuid::parse_str(s).ok());

    if let Some(key) = idempotency_key {
        if let Some(existing) = fetch_order_by_idempotency_key(pool.get_ref(), key).await? {
            let items = fetch_order_items_full(pool.get_ref(), existing.id).await?;
            return Ok(HttpResponse::Ok().json(OrderFull { order: existing, items }));
        }
    }

    if body.items.is_empty() {
        return Err(AppError::BadRequest("Order must have at least one item".into()));
    }

    let shift_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM shifts WHERE id = $1 AND branch_id = $2)"
    )
    .bind(body.shift_id)
    .bind(body.branch_id)
    .fetch_one(pool.get_ref())
    .await?;

    if !shift_exists {
        return Err(AppError::BadRequest(
            "Shift not found or does not belong to this branch".into(),
        ));
    }

    validate_payment_method(&body.payment_method)?;
    if let Some(dt) = &body.discount_type { validate_discount_type(dt)?; }

    // Resolve discount_id -> inline discount fields
    let (resolved_discount_type, resolved_discount_value) =
        if let Some(disc_id) = body.discount_id {
            let row: Option<(String, i32)> = sqlx::query_as(
                "SELECT type::text, value FROM discounts WHERE id = $1 AND is_active = true"
            )
            .bind(disc_id)
            .fetch_optional(pool.get_ref())
            .await?;

            match row {
                Some((dtype, dvalue)) => (Some(dtype), dvalue),
                None => return Err(AppError::BadRequest("Discount not found or inactive".into())),
            }
        } else {
            (body.discount_type.clone(), body.discount_value.unwrap_or(0))
        };

    let tax_rate: sqlx::types::BigDecimal = sqlx::query_scalar(
        "SELECT o.tax_rate FROM organizations o JOIN branches b ON b.org_id = o.id WHERE b.id = $1"
    )
    .bind(body.branch_id)
    .fetch_one(pool.get_ref())
    .await?;

    struct ResolvedItem {
        menu_item_id: Uuid,
        item_name:    String,
        size_label:   Option<String>,
        unit_price:   i32,
        quantity:     i32,
        notes:        Option<String>,
        addons:       Vec<ResolvedAddon>,
        deductions:   Vec<InventoryDeduction>,
    }
    struct ResolvedAddon {
        addon_item_id: Uuid,
        addon_name:    String,
        unit_price:    i32,
        quantity:      i32,
    }
    struct InventoryDeduction {
        inventory_item_id: Uuid,
        quantity:          f64,
        source:            String,
    }

    let mut resolved_items: Vec<ResolvedItem> = Vec::new();
    let mut subtotal: i32 = 0;

    for item_input in &body.items {
        if item_input.quantity <= 0 {
            return Err(AppError::BadRequest("Item quantity must be greater than 0".into()));
        }

        let (item_name, base_price): (String, i32) = sqlx::query_as(
            "SELECT m.name, m.base_price FROM menu_items m WHERE m.id = $1 AND m.deleted_at IS NULL",
        )
        .bind(item_input.menu_item_id)
        .fetch_optional(pool.get_ref())
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Menu item {} not found", item_input.menu_item_id)))?;

        let unit_price: i32 = match &item_input.size_label {
            Some(size) => {
                let size_price: Option<i32> = sqlx::query_scalar(
                    "SELECT price_override FROM item_sizes WHERE menu_item_id = $1 AND label = $2::item_size AND is_active = true"
                )
                .bind(item_input.menu_item_id)
                .bind(size)
                .fetch_optional(pool.get_ref())
                .await?
                .flatten();
                size_price.unwrap_or(base_price)
            }
            None => base_price,
        };

        let mut item_deductions: Vec<InventoryDeduction> = Vec::new();

        let size_for_recipe = item_input.size_label.as_deref().unwrap_or("one_size");
        let recipe_rows: Vec<(Uuid, f64)> = sqlx::query_as(
            "SELECT inventory_item_id, quantity_used::float8 FROM menu_item_recipes WHERE menu_item_id = $1 AND size_label = $2::item_size",
        )
        .bind(item_input.menu_item_id)
        .bind(size_for_recipe)
        .fetch_all(pool.get_ref())
        .await?;

        for (inv_id, qty) in recipe_rows {
            item_deductions.push(InventoryDeduction {
                inventory_item_id: inv_id,
                quantity:          qty * item_input.quantity as f64,
                source:            "drink_recipe".into(),
            });
        }

        let mut resolved_addons: Vec<ResolvedAddon> = Vec::new();

        for addon_input in &item_input.addons {
            let (addon_name, default_price): (String, i32) = sqlx::query_as(
                "SELECT name, default_price FROM addon_items WHERE id = $1"
            )
            .bind(addon_input.addon_item_id)
            .fetch_optional(pool.get_ref())
            .await?
            .ok_or_else(|| AppError::NotFound(format!("Addon {} not found", addon_input.addon_item_id)))?;

            let price_override: Option<i32> = sqlx::query_scalar(
                "SELECT price_override FROM drink_option_items WHERE id = $1"
            )
            .bind(addon_input.drink_option_item_id)
            .fetch_optional(pool.get_ref())
            .await?
            .flatten();

            let addon_price = price_override.unwrap_or(default_price);

            resolved_addons.push(ResolvedAddon {
                addon_item_id: addon_input.addon_item_id,
                addon_name,
                unit_price: addon_price,
                quantity:   addon_input.quantity.max(1),
            });

            let size_label = item_input.size_label.as_deref();
            let override_rows: Vec<(Uuid, f64)> = if let Some(size) = size_label {
                sqlx::query_as(
                    r#"
                    SELECT inventory_item_id, quantity_used::float8
                    FROM drink_option_ingredient_overrides
                    WHERE drink_option_item_id = $1
                      AND (size_label = $2::item_size OR size_label IS NULL)
                    ORDER BY size_label DESC NULLS LAST
                    "#,
                )
                .bind(addon_input.drink_option_item_id)
                .bind(size)
                .fetch_all(pool.get_ref())
                .await?
            } else {
                sqlx::query_as(
                    "SELECT inventory_item_id, quantity_used::float8 FROM drink_option_ingredient_overrides WHERE drink_option_item_id = $1 AND size_label IS NULL",
                )
                .bind(addon_input.drink_option_item_id)
                .fetch_all(pool.get_ref())
                .await?
            };

            if !override_rows.is_empty() {
                let mut seen = std::collections::HashSet::new();
                for (inv_id, qty) in override_rows {
                    if seen.insert(inv_id) {
                        item_deductions.push(InventoryDeduction {
                            inventory_item_id: inv_id,
                            quantity: qty * item_input.quantity as f64,
                            source: "addon_override".into(),
                        });
                    }
                }
            } else {
                let base_rows: Vec<(Uuid, f64)> = sqlx::query_as(
                    "SELECT inventory_item_id, quantity_used::float8 FROM addon_item_ingredients WHERE addon_item_id = $1"
                )
                .bind(addon_input.addon_item_id)
                .fetch_all(pool.get_ref())
                .await?;
                for (inv_id, qty) in base_rows {
                    item_deductions.push(InventoryDeduction {
                        inventory_item_id: inv_id,
                        quantity: qty * item_input.quantity as f64,
                        source: "addon_base".into(),
                    });
                }
            }
        }

        let item_line  = unit_price * item_input.quantity;
        let addon_line: i32 = resolved_addons.iter().map(|a| a.unit_price * a.quantity).sum::<i32>() * item_input.quantity;
        subtotal += item_line + addon_line;

        resolved_items.push(ResolvedItem {
            menu_item_id: item_input.menu_item_id,
            item_name,
            size_label: item_input.size_label.clone(),
            unit_price,
            quantity: item_input.quantity,
            notes: item_input.notes.clone(),
            addons: resolved_addons,
            deductions: item_deductions,
        });
    }

    let discount_amount = match resolved_discount_type.as_deref() {
        Some("percentage") => (subtotal as f64 * resolved_discount_value as f64 / 100.0) as i32,
        Some("fixed")      => resolved_discount_value.min(subtotal),
        _                  => 0,
    };
    let taxable      = subtotal - discount_amount;
    let tax_rate_f64: f64 = tax_rate.to_string().parse().unwrap_or(0.14);
    let tax_amount   = (taxable as f64 * tax_rate_f64) as i32;
    let total_amount = taxable + tax_amount;
    let change_given = body.amount_tendered.map(|t| (t - total_amount).max(0));
    let created_at   = body.created_at.unwrap_or_else(chrono::Utc::now);

    let mut tx = pool.get_ref().begin().await?;

    sqlx::query!(
        "SELECT pg_advisory_xact_lock(hashtext($1::text))",
        body.shift_id.to_string()
    )
    .execute(&mut *tx)
    .await?;

    let order_number: i32 = sqlx::query_scalar(
        "SELECT COALESCE(MAX(order_number), 0) + 1 FROM orders WHERE shift_id = $1"
    )
    .bind(body.shift_id)
    .fetch_one(&mut *tx)
    .await?;

    let order = sqlx::query_as::<_, Order>(
        r#"
        INSERT INTO orders
            (branch_id, shift_id, teller_id, order_number,
             payment_method, subtotal, discount_type, discount_value,
             discount_amount, tax_amount, total_amount,
             amount_tendered, change_given, tip_amount,
             discount_id, customer_name, notes, status,
             idempotency_key, created_at)
        VALUES ($1, $2, $3, $4, $5::payment_method, $6, $7::discount_type, $8,
                $9, $10, $11, $12, $13, $14, $15, $16, $17, 'completed', $18, $19)
        RETURNING
            id, branch_id, shift_id, teller_id,
            (SELECT name FROM users WHERE id = $3) AS teller_name,
            order_number, status::text, payment_method::text,
            subtotal, discount_type::text, discount_value,
            discount_amount, tax_amount, total_amount,
            amount_tendered, change_given, tip_amount, discount_id,
            customer_name, notes,
            voided_at, void_reason::text, voided_by,
            created_at
        "#,
    )
    .bind(body.branch_id)
    .bind(body.shift_id)
    .bind(claims.user_id())
    .bind(order_number)
    .bind(&body.payment_method)
    .bind(subtotal)
    .bind(&resolved_discount_type)
    .bind(resolved_discount_value)
    .bind(discount_amount)
    .bind(tax_amount)
    .bind(total_amount)
    .bind(body.amount_tendered)
    .bind(change_given)
    .bind(body.tip_amount.unwrap_or(0))
    .bind(body.discount_id)
    .bind(&body.customer_name)
    .bind(&body.notes)
    .bind(idempotency_key)
    .bind(created_at)
    .fetch_one(&mut *tx)
    .await?;

    // Write order_payments — use explicit splits or derive from payment_method
    if let Some(splits) = &body.payment_splits {
        for split in splits {
            validate_payment_method(&split.method)?;
            sqlx::query(
                "INSERT INTO order_payments (order_id, method, amount, reference) VALUES ($1, $2::payment_method, $3, $4)",
            )
            .bind(order.id)
            .bind(&split.method)
            .bind(split.amount)
            .bind(&split.reference)
            .execute(&mut *tx)
            .await?;
        }
    } else {
        sqlx::query(
            "INSERT INTO order_payments (order_id, method, amount) VALUES ($1, $2::payment_method, $3)",
        )
        .bind(order.id)
        .bind(&body.payment_method)
        .bind(total_amount)
        .execute(&mut *tx)
        .await?;
    }

    let mut order_items_full: Vec<OrderItemFull> = Vec::new();

    for resolved in resolved_items {
        let line_total = resolved.unit_price * resolved.quantity;

        let order_item = sqlx::query_as::<_, OrderItem>(
            r#"
            INSERT INTO order_items
                (order_id, menu_item_id, item_name, size_label, unit_price, quantity, line_total, notes)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING id, order_id, menu_item_id, item_name, size_label, unit_price, quantity, line_total, notes
            "#,
        )
        .bind(order.id)
        .bind(resolved.menu_item_id)
        .bind(&resolved.item_name)
        .bind(&resolved.size_label)
        .bind(resolved.unit_price)
        .bind(resolved.quantity)
        .bind(line_total)
        .bind(&resolved.notes)
        .fetch_one(&mut *tx)
        .await?;

        let mut addon_rows: Vec<OrderItemAddon> = Vec::new();

        for addon in &resolved.addons {
            let addon_line = addon.unit_price * addon.quantity * resolved.quantity;
            let row = sqlx::query_as::<_, OrderItemAddon>(
                r#"
                INSERT INTO order_item_addons
                    (order_item_id, addon_item_id, addon_name, unit_price, quantity, line_total)
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING id, order_item_id, addon_item_id, addon_name, unit_price, quantity, line_total
                "#,
            )
            .bind(order_item.id)
            .bind(addon.addon_item_id)
            .bind(&addon.addon_name)
            .bind(addon.unit_price)
            .bind(addon.quantity)
            .bind(addon_line)
            .fetch_one(&mut *tx)
            .await?;
            addon_rows.push(row);
        }

        for deduction in &resolved.deductions {
            sqlx::query(
                "UPDATE inventory_items SET current_stock = current_stock - $1 WHERE id = $2 AND branch_id = $3"
            )
            .bind(deduction.quantity)
            .bind(deduction.inventory_item_id)
            .bind(body.branch_id)
            .execute(&mut *tx)
            .await?;

            sqlx::query(
                r#"
                INSERT INTO inventory_deduction_logs
                    (branch_id, order_id, order_item_id, inventory_item_id, quantity_deducted, source)
                VALUES ($1, $2, $3, $4, $5, $6)
                "#,
            )
            .bind(body.branch_id)
            .bind(order.id)
            .bind(order_item.id)
            .bind(deduction.inventory_item_id)
            .bind(deduction.quantity)
            .bind(&deduction.source)
            .execute(&mut *tx)
            .await?;
        }

        order_items_full.push(OrderItemFull { item: order_item, addons: addon_rows });
    }

    tx.commit().await?;

    Ok(HttpResponse::Created().json(OrderFull { order, items: order_items_full }))
}

// ── GET /orders ───────────────────────────────────────────────

pub async fn list_orders(
    req:   HttpRequest,
    pool:  web::Data<PgPool>,
    query: web::Query<ListOrdersQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "read").await?;

    let orders = match (query.shift_id, query.branch_id) {
        (Some(shift_id), _) => {
            let branch_id: Option<Uuid> = sqlx::query_scalar("SELECT branch_id FROM shifts WHERE id = $1")
                .bind(shift_id)
                .fetch_optional(pool.get_ref())
                .await?
                .flatten();
            if let Some(bid) = branch_id { require_branch_access(pool.get_ref(), &claims, bid).await?; }

            match query.updated_after {
                Some(after) => sqlx::query_as::<_, Order>(ORDER_SELECT!("WHERE o.shift_id = $1 AND o.updated_at > $2 ORDER BY o.created_at DESC"))
                    .bind(shift_id).bind(after).fetch_all(pool.get_ref()).await?,
                None => sqlx::query_as::<_, Order>(ORDER_SELECT!("WHERE o.shift_id = $1 ORDER BY o.created_at DESC"))
                    .bind(shift_id).fetch_all(pool.get_ref()).await?,
            }
        }
        (None, Some(branch_id)) => {
            require_branch_access(pool.get_ref(), &claims, branch_id).await?;
            sqlx::query_as::<_, Order>(ORDER_SELECT!("WHERE o.branch_id = $1 ORDER BY o.created_at DESC LIMIT 500"))
                .bind(branch_id).fetch_all(pool.get_ref()).await?
        }
        _ => return Err(AppError::BadRequest("Provide either shift_id or branch_id".into())),
    };

    Ok(HttpResponse::Ok().json(orders))
}

// ── GET /orders/:id ───────────────────────────────────────────

pub async fn get_order(
    req: HttpRequest, pool: web::Data<PgPool>, order_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "read").await?;
    let order = fetch_order_or_404(pool.get_ref(), *order_id).await?;
    require_branch_access(pool.get_ref(), &claims, order.branch_id).await?;
    let items = fetch_order_items_full(pool.get_ref(), order.id).await?;
    Ok(HttpResponse::Ok().json(OrderFull { order, items }))
}

// ── POST /orders/:id/void ─────────────────────────────────────

pub async fn void_order(
    req: HttpRequest, pool: web::Data<PgPool>,
    order_id: web::Path<Uuid>, body: web::Json<VoidOrderRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "update").await?;
    let order = fetch_order_or_404(pool.get_ref(), *order_id).await?;
    require_branch_access(pool.get_ref(), &claims, order.branch_id).await?;
    if order.status == "voided" { return Ok(HttpResponse::Ok().json(order)); }
    validate_void_reason(&body.reason)?;
    let voided_at = body.voided_at.unwrap_or_else(chrono::Utc::now);

    let updated = sqlx::query_as::<_, Order>(
        r#"
        UPDATE orders SET status = 'voided', voided_at = $3, void_reason = $2::void_reason, voided_by = $4
        WHERE id = $1
        RETURNING
            id, branch_id, shift_id, teller_id,
            (SELECT name FROM users WHERE id = teller_id) AS teller_name,
            order_number, status::text, payment_method::text,
            subtotal, discount_type::text, discount_value,
            discount_amount, tax_amount, total_amount,
            amount_tendered, change_given, tip_amount, discount_id,
            customer_name, notes, voided_at, void_reason::text, voided_by, created_at
        "#,
    )
    .bind(*order_id).bind(&body.reason).bind(voided_at).bind(claims.user_id())
    .fetch_one(pool.get_ref()).await?;

    Ok(HttpResponse::Ok().json(updated))
}

// ── Shared SELECT macro ───────────────────────────────────────

macro_rules! ORDER_SELECT {
    ($where:expr) => {
        concat!(
            "SELECT o.id, o.branch_id, o.shift_id, o.teller_id, u.name AS teller_name,
             o.order_number, o.status::text, o.payment_method::text,
             o.subtotal, o.discount_type::text, o.discount_value,
             o.discount_amount, o.tax_amount, o.total_amount,
             o.amount_tendered, o.change_given, o.tip_amount, o.discount_id,
             o.customer_name, o.notes, o.voided_at, o.void_reason::text, o.voided_by, o.created_at
             FROM orders o JOIN users u ON u.id = o.teller_id ",
            $where
        )
    };
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions().get::<Claims>().cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_order_or_404(pool: &PgPool, order_id: Uuid) -> Result<Order, AppError> {
    sqlx::query_as::<_, Order>(ORDER_SELECT!("WHERE o.id = $1"))
        .bind(order_id).fetch_optional(pool).await?
        .ok_or_else(|| AppError::NotFound("Order not found".into()))
}

async fn fetch_order_by_idempotency_key(pool: &PgPool, key: Uuid) -> Result<Option<Order>, AppError> {
    Ok(sqlx::query_as::<_, Order>(ORDER_SELECT!("WHERE o.idempotency_key = $1"))
        .bind(key).fetch_optional(pool).await?)
}

async fn fetch_order_items_full(pool: &PgPool, order_id: Uuid) -> Result<Vec<OrderItemFull>, AppError> {
    let items = sqlx::query_as::<_, OrderItem>(
        "SELECT id, order_id, menu_item_id, item_name, size_label, unit_price, quantity, line_total, notes FROM order_items WHERE order_id = $1 ORDER BY id",
    ).bind(order_id).fetch_all(pool).await?;

    let mut result = Vec::new();
    for item in items {
        let addons = sqlx::query_as::<_, OrderItemAddon>(
            "SELECT id, order_item_id, addon_item_id, addon_name, unit_price, quantity, line_total FROM order_item_addons WHERE order_item_id = $1 ORDER BY id",
        ).bind(item.id).fetch_all(pool).await?;
        result.push(OrderItemFull { item, addons });
    }
    Ok(result)
}

async fn require_branch_access(pool: &PgPool, claims: &Claims, branch_id: Uuid) -> Result<(), AppError> {
    if claims.role == UserRole::SuperAdmin { return Ok(()); }
    let branch_org: Option<Uuid> = sqlx::query_scalar(
        "SELECT org_id FROM branches WHERE id = $1 AND deleted_at IS NULL"
    ).bind(branch_id).fetch_optional(pool).await?.flatten();
    let branch_org = branch_org.ok_or_else(|| AppError::NotFound("Branch not found".into()))?;
    if claims.org_id() != Some(branch_org) {
        return Err(AppError::Forbidden("Branch belongs to a different org".into()));
    }
    if claims.role == UserRole::OrgAdmin { return Ok(()); }
    let assigned: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM user_branch_assignments WHERE user_id = $1 AND branch_id = $2)"
    ).bind(claims.user_id()).bind(branch_id).fetch_one(pool).await?;
    if !assigned { return Err(AppError::Forbidden("Not assigned to this branch".into())); }
    Ok(())
}

fn validate_payment_method(method: &str) -> Result<(), AppError> {
    match method {
        "cash"|"card"|"digital_wallet"|"mixed"|"talabat_online"|"talabat_cash" => Ok(()),
        _ => Err(AppError::BadRequest("Invalid payment_method".into())),
    }
}
fn validate_discount_type(dt: &str) -> Result<(), AppError> {
    match dt { "percentage"|"fixed" => Ok(()), _ => Err(AppError::BadRequest("discount_type must be 'percentage' or 'fixed'".into())) }
}
fn validate_void_reason(reason: &str) -> Result<(), AppError> {
    match reason {
        "customer_request"|"wrong_order"|"quality_issue"|"other" => Ok(()),
        _ => Err(AppError::BadRequest("Invalid void_reason".into())),
    }
}
EOF

echo "✓ src/orders/handlers.rs"

# ── 3. Patch reports/handlers.rs — payment breakdowns from order_payments ─────
python3 - << 'PYEOF'
import pathlib, re, sys

path = pathlib.Path("src/reports/handlers.rs")
if not path.exists():
    print("ERROR: src/reports/handlers.rs not found", file=sys.stderr)
    sys.exit(1)

src = path.read_text()

# Helper: build a per-method correlated subquery
def op_subquery(method, alias, context_col, context_val):
    """context_col/val is either 'shift_id = s.id' or 'branch_id = $1 AND date filters'"""
    return (
        f"COALESCE((SELECT SUM(op.amount) FROM order_payments op "
        f"JOIN orders oo ON oo.id = op.order_id "
        f"WHERE oo.{context_col} AND oo.status != 'voided' AND op.method = '{method}'), 0)::bigint AS {alias}"
    )

# ── Patch shift_summary ───────────────────────────────────────────────────────
# Replace the 6 FILTER(payment_method=X) lines inside shift_summary
SHIFT_PAT = re.compile(
    r"COALESCE\(SUM\(o\.total_amount\) FILTER \(WHERE o\.status != 'voided' AND o\.payment_method = 'cash'\)[^\n]*\n"
    r"[^\n]*COALESCE\(SUM\(o\.total_amount\) FILTER \(WHERE o\.status != 'voided' AND o\.payment_method = 'card'\)[^\n]*\n"
    r"[^\n]*COALESCE\(SUM\(o\.total_amount\) FILTER \(WHERE o\.status != 'voided' AND o\.payment_method = 'digital_wallet'\)[^\n]*\n"
    r"[^\n]*COALESCE\(SUM\(o\.total_amount\) FILTER \(WHERE o\.status != 'voided' AND o\.payment_method = 'mixed'\)[^\n]*\n"
    r"[^\n]*COALESCE\(SUM\(o\.total_amount\) FILTER \(WHERE o\.status != 'voided' AND o\.payment_method = 'talabat_online'\)[^\n]*\n"
    r"[^\n]*COALESCE\(SUM\(o\.total_amount\) FILTER \(WHERE o\.status != 'voided' AND o\.payment_method = 'talabat_cash'\)[^\n]*",
    re.MULTILINE,
)

SHIFT_REPL = (
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'cash'), 0)::bigint           AS cash_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'card'), 0)::bigint           AS card_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'digital_wallet'), 0)::bigint AS digital_wallet_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'mixed'), 0)::bigint          AS mixed_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'talabat_online'), 0)::bigint  AS talabat_online_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'talabat_cash'), 0)::bigint   AS talabat_cash_revenue"
)

new_src, n = SHIFT_PAT.subn(SHIFT_REPL, src)
print(f"shift_summary replacements: {n}")

# ── Patch branch_sales — the 6 per-method FILTER lines inside branch_sales ───
BRANCH_PAT = re.compile(
    r"COALESCE\(SUM\(total_amount\)\s+FILTER \(WHERE status != 'voided' AND payment_method = 'cash'\)[^\n]*,\n"
    r"[^\n]*COALESCE\(SUM\(total_amount\)\s+FILTER \(WHERE status != 'voided' AND payment_method = 'card'\)[^\n]*,\n"
    r"[^\n]*COALESCE\(SUM\(total_amount\)\s+FILTER \(WHERE status != 'voided' AND payment_method = 'digital_wallet'\)[^\n]*,\n"
    r"[^\n]*COALESCE\(SUM\(total_amount\)\s+FILTER \(WHERE status != 'voided' AND payment_method = 'mixed'\)[^\n]*,\n"
    r"[^\n]*COALESCE\(SUM\(total_amount\)\s+FILTER \(WHERE status != 'voided' AND payment_method = 'talabat_online'\)[^\n]*,\n"
    r"[^\n]*COALESCE\(SUM\(total_amount\)\s+FILTER \(WHERE status != 'voided' AND payment_method = 'talabat_cash'\)[^\n]*",
    re.MULTILINE,
)

BRANCH_REPL = (
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'cash'), 0),\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'card'), 0),\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'digital_wallet'), 0),\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'mixed'), 0),\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'talabat_online'), 0),\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'talabat_cash'), 0)"
)

new_src, n2 = BRANCH_PAT.subn(BRANCH_REPL, new_src)
print(f"branch_sales replacements: {n2}")

if n == 0 and n2 == 0:
    print("WARNING: no replacements made — patterns may have changed")
else:
    path.write_text(new_src)
    print("reports/handlers.rs patched OK")
PYEOF

echo "✓ src/reports/handlers.rs"

# ── 4. Wire discounts into main.rs (pure Python, no sed) ─────────────────────
python3 - << 'PYEOF'
import pathlib

path = pathlib.Path("src/main.rs")
src  = path.read_text()

if "mod discounts;" not in src:
    src = src.replace("mod uploads;", "mod discounts;\nmod uploads;")
    print("added mod discounts")

if "discounts::routes::configure" not in src:
    src = src.replace(
        ".configure(orders::routes::configure)",
        ".configure(orders::routes::configure)\n            .configure(discounts::routes::configure)"
    )
    print("wired discounts routes")

path.write_text(src)
print("main.rs OK")
PYEOF

echo "✓ src/main.rs"

# ── 5. Build ──────────────────────────────────────────────────────────────────
echo ""
echo "Building..."
cargo sqlx prepare 2>&1 | tail -3
cargo build --release 2>&1 | grep -E "^error|Compiling rue|Finished" | tail -15

echo ""
echo "Restarting service..."
sudo systemctl restart rue-rust
sleep 2
sudo systemctl status rue-rust --no-pager | head -12

echo ""
echo "=== Rust patch complete ==="
echo "New: GET/POST /discounts  PATCH/DELETE /discounts/:id"
echo "Updated POST /orders: discount_id, amount_tendered, tip_amount, payment_splits"
echo "Reports now aggregate from order_payments table"