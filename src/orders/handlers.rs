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
    pub id:             Uuid,
    pub branch_id:      Uuid,
    pub shift_id:       Uuid,
    pub teller_id:      Uuid,
    pub teller_name:    String,
    pub order_number:   i32,
    pub status:         String,
    pub payment_method: String,
    pub subtotal:       i32,
    pub discount_type:  Option<String>,
    pub discount_value: i32,
    pub discount_amount: i32,
    pub tax_amount:     i32,
    pub total_amount:   i32,
    pub customer_name:  Option<String>,
    pub notes:          Option<String>,
    pub voided_at:      Option<chrono::DateTime<chrono::Utc>>,
    pub void_reason:    Option<String>,
    pub voided_by:      Option<Uuid>,
    pub created_at:     chrono::DateTime<chrono::Utc>,
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
    pub id:           Uuid,
    pub order_item_id: Uuid,
    pub addon_item_id: Uuid,
    pub addon_name:   String,
    pub unit_price:   i32,
    pub quantity:     i32,
    pub line_total:   i32,
}

#[derive(Debug, Serialize)]
pub struct OrderFull {
    #[serde(flatten)]
    pub order:    Order,
    pub items:    Vec<OrderItemFull>,
}

#[derive(Debug, Serialize)]
pub struct OrderItemFull {
    #[serde(flatten)]
    pub item:   OrderItem,
    pub addons: Vec<OrderItemAddon>,
}

// ── Request types ─────────────────────────────────────────────

#[derive(Deserialize)]
pub struct AddonInput {
    pub addon_item_id:       Uuid,
    pub drink_option_item_id: Uuid, // needed to look up ingredient overrides
}

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
    pub branch_id:      Uuid,
    pub shift_id:       Uuid,
    pub payment_method: String,
    pub customer_name:  Option<String>,
    pub notes:          Option<String>,
    pub discount_type:  Option<String>,
    pub discount_value: Option<i32>,
    pub items:          Vec<OrderItemInput>,
}

#[derive(Deserialize)]
pub struct VoidOrderRequest {
    pub reason: String,

    pub restore_inventory: Option<bool>,}

#[derive(Deserialize)]
pub struct ListOrdersQuery {
    pub branch_id: Option<Uuid>,
    pub shift_id:  Option<Uuid>,
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

    if body.items.is_empty() {
        return Err(AppError::BadRequest("Order must have at least one item".into()));
    }

    // Validate shift belongs to this branch and is open
    let shift_ok: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM shifts WHERE id = $1 AND branch_id = $2 AND status = 'open')"
    )
    .bind(body.shift_id)
    .bind(body.branch_id)
    .fetch_one(pool.get_ref())
    .await?;

    if !shift_ok {
        return Err(AppError::BadRequest(
            "Shift not found, not open, or does not belong to this branch".into(),
        ));
    }

    validate_payment_method(&body.payment_method)?;
    if let Some(dt) = &body.discount_type {
        validate_discount_type(dt)?;
    }

    // ── Fetch org tax rate ────────────────────────────────────
    let tax_rate: sqlx::types::BigDecimal = sqlx::query_scalar(
        "SELECT o.tax_rate FROM organizations o JOIN branches b ON b.org_id = o.id WHERE b.id = $1"
    )
    .bind(body.branch_id)
    .fetch_one(pool.get_ref())
    .await?;

    // ── Build order items with pricing ───────────────────────
    struct ResolvedItem {
        menu_item_id: Uuid,
        item_name:    String,
        size_label:   Option<String>,
        unit_price:   i32,
        quantity:     i32,
        notes:        Option<String>,
        addons:       Vec<ResolvedAddon>,
        // inventory deductions to apply
        deductions:   Vec<InventoryDeduction>,
    }

    struct ResolvedAddon {
        addon_item_id: Uuid,
        addon_name:    String,
        unit_price:    i32,
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

        // Fetch menu item
        let (item_name, base_price, is_soft_serve): (String, i32, bool) = sqlx::query_as(
            r#"
            SELECT m.name, m.base_price,
                   (c.name ILIKE '%soft serve%' OR m.name ILIKE '%soft serve%') AS is_soft_serve
            FROM menu_items m
            LEFT JOIN categories c ON c.id = m.category_id
            WHERE m.id = $1 AND m.deleted_at IS NULL
            "#,
        )
        .bind(item_input.menu_item_id)
        .fetch_optional(pool.get_ref())
        .await?
        .ok_or_else(|| AppError::NotFound(format!("Menu item {} not found", item_input.menu_item_id)))?;

        // Resolve price: size override or base price
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

        // ── Deduct drink recipe ingredients ──────────────────
        if !is_soft_serve {
            if let Some(size) = &item_input.size_label {
                let recipe_rows: Vec<(Uuid, f64)> = sqlx::query_as(
                    r#"
                    SELECT inventory_item_id, quantity_used::float8
                    FROM menu_item_recipes
                    WHERE menu_item_id = $1 AND size_label = $2::item_size
                    "#,
                )
                .bind(item_input.menu_item_id)
                .bind(size)
                .fetch_all(pool.get_ref())
                .await?;

                for (inv_id, qty) in recipe_rows {
                    item_deductions.push(InventoryDeduction {
                        inventory_item_id: inv_id,
                        quantity:          qty * item_input.quantity as f64,
                        source:            "drink_recipe".into(),
                    });
                }
            } else {
                // No size — check one_size recipe
                let recipe_rows: Vec<(Uuid, f64)> = sqlx::query_as(
                    r#"
                    SELECT inventory_item_id, quantity_used::float8
                    FROM menu_item_recipes
                    WHERE menu_item_id = $1 AND size_label = 'one_size'
                    "#,
                )
                .bind(item_input.menu_item_id)
                .fetch_all(pool.get_ref())
                .await?;

                for (inv_id, qty) in recipe_rows {
                    item_deductions.push(InventoryDeduction {
                        inventory_item_id: inv_id,
                        quantity:          qty * item_input.quantity as f64,
                        source:            "drink_recipe".into(),
                    });
                }
            }
        } else {
            // ── Soft serve: deduct from serve pool ───────────
            let size = item_input.size_label.as_deref().unwrap_or("small");
            let is_large = size == "large" || size == "extra_large";

            // Check pool exists and has serves
            let pool_row: Option<(Uuid, sqlx::types::BigDecimal, sqlx::types::BigDecimal, bool)> = sqlx::query_as(
                "SELECT id, total_units, large_ratio, low_stock_flag FROM soft_serve_serve_pools WHERE branch_id = $1 AND menu_item_id = $2"
            )
            .bind(body.branch_id)
            .bind(item_input.menu_item_id)
            .fetch_optional(pool.get_ref())
            .await?;
            if pool_row.is_none() {
                return Err(AppError::BadRequest(format!(
                    "No serve pool found for soft serve item {}. Please log a batch first.",
                    item_input.menu_item_id
                )));
            }
            let (_, total_units, large_ratio, _) = pool_row.unwrap();
            let total_units_f: f64 = total_units.to_string().parse().unwrap_or(0.0);
            let large_ratio_f: f64 = large_ratio.to_string().parse().unwrap_or(1.5);
            let units_per_serve = if is_large { large_ratio_f } else { 1.0 };
            let units_needed = units_per_serve * item_input.quantity as f64;
            if total_units_f < units_needed {
                let available = if is_large {
                    (total_units_f / large_ratio_f).floor() as i32
                } else {
                    total_units_f.floor() as i32
                };
                return Err(AppError::BadRequest(format!(
                    "Insufficient serves in pool. Available: {}, Requested: {}",
                    available, item_input.quantity
                )));
            }
            // Mark for pool deduction (handled after order insert)
            item_deductions.push(InventoryDeduction {
                inventory_item_id: item_input.menu_item_id,
                quantity:          units_needed,
                source:            if is_large { "soft_serve_pool_large".into() } else { "soft_serve_pool_small".into() },
            });
        }
        // ── Resolve addons ────────────────────────────────────
        let mut resolved_addons: Vec<ResolvedAddon> = Vec::new();

        for addon_input in &item_input.addons {
            // Get addon name + price
            let (addon_name, default_price): (String, i32) = sqlx::query_as(
                "SELECT name, default_price FROM addon_items WHERE id = $1"
            )
            .bind(addon_input.addon_item_id)
            .fetch_optional(pool.get_ref())
            .await?
            .ok_or_else(|| AppError::NotFound(format!("Addon {} not found", addon_input.addon_item_id)))?;

            // Check for price override on the drink_option_item
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
            });

            // ── Addon ingredient deductions ───────────────────
            // Check for per-drink-per-size override first, then fall back to base
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
                    r#"
                    SELECT inventory_item_id, quantity_used::float8
                    FROM drink_option_ingredient_overrides
                    WHERE drink_option_item_id = $1 AND size_label IS NULL
                    "#,
                )
                .bind(addon_input.drink_option_item_id)
                .fetch_all(pool.get_ref())
                .await?
            };

            if !override_rows.is_empty() {
                // Use overrides — deduplicate by inventory_item_id (specific size wins over NULL)
                let mut seen: std::collections::HashSet<Uuid> = std::collections::HashSet::new();
                for (inv_id, qty) in override_rows {
                    if seen.insert(inv_id) {
                        item_deductions.push(InventoryDeduction {
                            inventory_item_id: inv_id,
                            quantity:          qty * item_input.quantity as f64,
                            source:            "addon_override".into(),
                        });
                    }
                }
            } else {
                // Fall back to addon base ingredients
                let base_rows: Vec<(Uuid, f64)> = sqlx::query_as(
                    r#"
                    SELECT inventory_item_id, quantity_used::float8
                    FROM addon_item_ingredients
                    WHERE addon_item_id = $1
                    "#,
                )
                .bind(addon_input.addon_item_id)
                .fetch_all(pool.get_ref())
                .await?;

                for (inv_id, qty) in base_rows {
                    item_deductions.push(InventoryDeduction {
                        inventory_item_id: inv_id,
                        quantity:          qty * item_input.quantity as f64,
                        source:            "addon_base".into(),
                    });
                }
            }
        }

        let item_line = unit_price * item_input.quantity;
        let addon_line: i32 = resolved_addons.iter().map(|a| a.unit_price).sum::<i32>() * item_input.quantity;
        subtotal += item_line + addon_line;

        resolved_items.push(ResolvedItem {
            menu_item_id: item_input.menu_item_id,
            item_name,
            size_label:   item_input.size_label.clone(),
            unit_price,
            quantity:     item_input.quantity,
            notes:        item_input.notes.clone(),
            addons:       resolved_addons,
            deductions:   item_deductions,
        });
    }

    // ── Calculate totals ──────────────────────────────────────
    let discount_value = body.discount_value.unwrap_or(0);
    let discount_amount = match body.discount_type.as_deref() {
        Some("percentage") => (subtotal as f64 * discount_value as f64 / 100.0) as i32,
        Some("fixed")      => discount_value.min(subtotal),
        _                  => 0,
    };

    let taxable = subtotal - discount_amount;
    let tax_rate_f64: f64 = tax_rate.to_string().parse().unwrap_or(0.14);
    let tax_amount = (taxable as f64 * tax_rate_f64) as i32;
    let total_amount = taxable + tax_amount;

    let mut tx = pool.get_ref().begin().await?;

    sqlx::query!("SELECT pg_advisory_xact_lock(hashtext($1::text))", body.shift_id.to_string())
        .execute(&mut *tx)
        .await?;
    
    let order_number: i32 = sqlx::query_scalar(
        "SELECT COALESCE(MAX(order_number), 0) + 1 FROM orders WHERE shift_id = $1"
    )
    .bind(body.shift_id)
    .fetch_one(&mut *tx)
    .await?;



    // ── Insert order ──────────────────────────────────────────
    let order = sqlx::query_as::<_, Order>(
        r#"
        INSERT INTO orders
            (branch_id, shift_id, teller_id, order_number,
             payment_method, subtotal, discount_type, discount_value,
             discount_amount, tax_amount, total_amount,
             customer_name, notes, status)
        VALUES ($1, $2, $3, $4, $5::payment_method, $6, $7::discount_type, $8, $9, $10, $11, $12, $13, 'completed')
        RETURNING
            id, branch_id, shift_id, teller_id,
            (SELECT name FROM users WHERE id = $3) AS teller_name,
            order_number, status::text, payment_method::text,
            subtotal, discount_type::text, discount_value,
            discount_amount, tax_amount, total_amount,
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
    .bind(&body.discount_type)
    .bind(discount_value)
    .bind(discount_amount)
    .bind(tax_amount)
    .bind(total_amount)
    .bind(&body.customer_name)
    .bind(&body.notes)
    .fetch_one(&mut *tx)
    .await?;

    // ── Insert order items + addons + deductions ──────────────
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
            let addon_line = addon.unit_price * resolved.quantity;
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
            .bind(resolved.quantity)
            .bind(addon_line)
            .fetch_one(&mut *tx)
            .await?;

            addon_rows.push(row);
        }

        // ── Apply inventory deductions ────────────────────────
        for deduction in &resolved.deductions {
            if deduction.source.starts_with("soft_serve_pool") {
                // Deduct from serve pool
                sqlx::query(
                    r#"
                    UPDATE soft_serve_serve_pools
                    SET total_units    = GREATEST(0, total_units - $1),
                        low_stock_flag = (GREATEST(0, total_units - $1) < large_ratio),
                        updated_at     = NOW()
                    WHERE branch_id = $2 AND menu_item_id = $3
                    "#,
                )
                .bind(deduction.quantity)
                .bind(body.branch_id)
                .bind(resolved.menu_item_id)
                .execute(&mut *tx)
                .await?;

                // Log to deduction log using order_item_id as reference
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
                .bind(resolved.menu_item_id) // soft serve uses menu_item_id as placeholder
                .bind(deduction.quantity)
                .bind(&deduction.source)
                .execute(&mut *tx)
                .await?;
            } else {
                // Regular inventory deduction
                sqlx::query(
                    "UPDATE inventory_items SET current_stock = current_stock - $1 WHERE id = $2 AND branch_id = $3"
                )
                .bind(deduction.quantity)
                .bind(deduction.inventory_item_id)
                .bind(body.branch_id)
                .execute(&mut *tx)
                .await?;

                // Check reorder threshold and flag if needed
                sqlx::query(
                    r#"
                    UPDATE inventory_items
                    SET is_active = is_active  -- no-op, just to trigger check
                    WHERE id = $1
                      AND current_stock <= reorder_threshold
                    "#,
                )
                .bind(deduction.inventory_item_id)
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
        }

        order_items_full.push(OrderItemFull {
            item:   order_item,
            addons: addon_rows,
        });
    }

    tx.commit().await?;

    Ok(HttpResponse::Created().json(OrderFull {
        order,
        items: order_items_full,
    }))
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
            // Verify shift's branch is accessible
            let branch_id: Option<Uuid> = sqlx::query_scalar(
                "SELECT branch_id FROM shifts WHERE id = $1"
            )
            .bind(shift_id)
            .fetch_optional(pool.get_ref())
            .await?
            .flatten();

            if let Some(bid) = branch_id {
                require_branch_access(pool.get_ref(), &claims, bid).await?;
            }

            sqlx::query_as::<_, Order>(
                r#"
                SELECT o.id, o.branch_id, o.shift_id, o.teller_id,
                       u.name AS teller_name,
                       o.order_number, o.status::text, o.payment_method::text,
                       o.subtotal, o.discount_type::text, o.discount_value,
                       o.discount_amount, o.tax_amount, o.total_amount,
                       o.customer_name, o.notes,
                       o.voided_at, o.void_reason::text, o.voided_by,
                       o.created_at
                FROM orders o
                JOIN users u ON u.id = o.teller_id
                WHERE o.shift_id = $1
                ORDER BY o.created_at DESC
                "#,
            )
            .bind(shift_id)
            .fetch_all(pool.get_ref())
            .await?
        }

        (None, Some(branch_id)) => {
            require_branch_access(pool.get_ref(), &claims, branch_id).await?;

            sqlx::query_as::<_, Order>(
                r#"
                SELECT o.id, o.branch_id, o.shift_id, o.teller_id,
                       u.name AS teller_name,
                       o.order_number, o.status::text, o.payment_method::text,
                       o.subtotal, o.discount_type::text, o.discount_value,
                       o.discount_amount, o.tax_amount, o.total_amount,
                       o.customer_name, o.notes,
                       o.voided_at, o.void_reason::text, o.voided_by,
                       o.created_at
                FROM orders o
                JOIN users u ON u.id = o.teller_id
                WHERE o.branch_id = $1
                ORDER BY o.created_at DESC
                LIMIT 200
                "#,
            )
            .bind(branch_id)
            .fetch_all(pool.get_ref())
            .await?
        }

        _ => return Err(AppError::BadRequest(
            "Provide either shift_id or branch_id as query parameter".into(),
        )),
    };

    Ok(HttpResponse::Ok().json(orders))
}

// ── GET /orders/:id ───────────────────────────────────────────

pub async fn get_order(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    order_id: web::Path<Uuid>,
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
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    order_id: web::Path<Uuid>,
    body:     web::Json<VoidOrderRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "update").await?;

    let order = fetch_order_or_404(pool.get_ref(), *order_id).await?;
    require_branch_access(pool.get_ref(), &claims, order.branch_id).await?;

    if order.status == "voided" {
        return Err(AppError::BadRequest("Order is already voided".into()));
    }

    validate_void_reason(&body.reason)?;

    let updated = sqlx::query_as::<_, Order>(
        r#"
        UPDATE orders SET
            status     = 'voided',
            voided_at  = NOW(),
            void_reason = $2::void_reason,
            voided_by  = $3
        WHERE id = $1
        RETURNING
            id, branch_id, shift_id, teller_id,
            (SELECT name FROM users WHERE id = teller_id) AS teller_name,
            order_number, status::text, payment_method::text,
            subtotal, discount_type::text, discount_value,
            discount_amount, tax_amount, total_amount,
            customer_name, notes,
            voided_at, void_reason::text, voided_by,
            created_at
        "#,
    )
    .bind(*order_id)
    .bind(&body.reason)
    .bind(claims.user_id())
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(updated))
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_order_or_404(pool: &PgPool, order_id: Uuid) -> Result<Order, AppError> {
    sqlx::query_as::<_, Order>(
        r#"
        SELECT o.id, o.branch_id, o.shift_id, o.teller_id,
               u.name AS teller_name,
               o.order_number, o.status::text, o.payment_method::text,
               o.subtotal, o.discount_type::text, o.discount_value,
               o.discount_amount, o.tax_amount, o.total_amount,
               o.customer_name, o.notes,
               o.voided_at, o.void_reason::text, o.voided_by,
               o.created_at
        FROM orders o
        JOIN users u ON u.id = o.teller_id
        WHERE o.id = $1
        "#,
    )
    .bind(order_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Order not found".into()))
}

async fn fetch_order_items_full(pool: &PgPool, order_id: Uuid) -> Result<Vec<OrderItemFull>, AppError> {
    let items = sqlx::query_as::<_, OrderItem>(
        "SELECT id, order_id, menu_item_id, item_name, size_label, unit_price, quantity, line_total, notes
         FROM order_items WHERE order_id = $1 ORDER BY id",
    )
    .bind(order_id)
    .fetch_all(pool)
    .await?;

    let mut result = Vec::new();
    for item in items {
        let addons = sqlx::query_as::<_, OrderItemAddon>(
            "SELECT id, order_item_id, addon_item_id, addon_name, unit_price, quantity, line_total
             FROM order_item_addons WHERE order_item_id = $1 ORDER BY id",
        )
        .bind(item.id)
        .fetch_all(pool)
        .await?;

        result.push(OrderItemFull { item, addons });
    }

    Ok(result)
}

async fn require_branch_access(
    pool:      &PgPool,
    claims:    &Claims,
    branch_id: Uuid,
) -> Result<(), AppError> {
    if claims.role == UserRole::SuperAdmin { return Ok(()); }

    let branch_org: Option<Uuid> = sqlx::query_scalar(
        "SELECT org_id FROM branches WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(branch_id)
    .fetch_optional(pool)
    .await?
    .flatten();

    let branch_org = branch_org
        .ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

    if claims.org_id() != Some(branch_org) {
        return Err(AppError::Forbidden("Branch belongs to a different org".into()));
    }

    if claims.role == UserRole::OrgAdmin { return Ok(()); }

    let assigned: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM user_branch_assignments WHERE user_id = $1 AND branch_id = $2)"
    )
    .bind(claims.user_id())
    .bind(branch_id)
    .fetch_one(pool)
    .await?;

    if !assigned {
        return Err(AppError::Forbidden("Not assigned to this branch".into()));
    }

    Ok(())
}

fn validate_payment_method(method: &str) -> Result<(), AppError> {
    match method {
        "cash" | "card" | "digital_wallet" | "mixed" => Ok(()),
        _ => Err(AppError::BadRequest(
            "payment_method must be one of: cash, card, digital_wallet, mixed".into(),
        )),
    }
}

fn validate_discount_type(dt: &str) -> Result<(), AppError> {
    match dt {
        "percentage" | "fixed" => Ok(()),
        _ => Err(AppError::BadRequest(
            "discount_type must be 'percentage' or 'fixed'".into(),
        )),
    }
}

fn validate_void_reason(reason: &str) -> Result<(), AppError> {
    match reason {
        "customer_request" | "wrong_order" | "quality_issue" | "other" => Ok(()),
        _ => Err(AppError::BadRequest(
            "void_reason must be one of: customer_request, wrong_order, quality_issue, other".into(),
        )),
    }
}