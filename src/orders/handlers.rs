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

// ── Shared SELECT fragment ────────────────────────────────────
const ORDER_SELECT: &str =
    "SELECT o.id, o.branch_id, o.shift_id, o.teller_id, u.name AS teller_name,
     o.order_number, o.status::text, o.payment_method::text,
     o.subtotal, o.discount_type::text, o.discount_value,
     o.discount_amount, o.tax_amount, o.total_amount,
     o.amount_tendered, o.change_given, o.tip_amount, o.tip_payment_method, o.discount_id,
     o.customer_name, o.notes, o.voided_at, o.void_reason::text, o.voided_by, o.created_at
     FROM orders o JOIN users u ON u.id = o.teller_id ";

// ── Models ────────────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Order {
    pub id:                 Uuid,
    pub branch_id:          Uuid,
    pub shift_id:           Uuid,
    pub teller_id:          Uuid,
    pub teller_name:        String,
    pub order_number:       i32,
    pub status:             String,
    pub payment_method:     String,
    pub subtotal:           i32,
    pub discount_type:      Option<String>,
    pub discount_value:     i32,
    pub discount_amount:    i32,
    pub tax_amount:         i32,
    pub total_amount:       i32,
    pub amount_tendered:    Option<i32>,
    pub change_given:       Option<i32>,
    pub tip_amount:         Option<i32>,
    pub tip_payment_method: Option<String>,
    pub discount_id:        Option<Uuid>,
    pub customer_name:      Option<String>,
    pub notes:              Option<String>,
    pub voided_at:          Option<chrono::DateTime<chrono::Utc>>,
    pub void_reason:        Option<String>,
    pub voided_by:          Option<Uuid>,
    pub created_at:         chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct OrderItem {
    pub id:                  Uuid,
    pub order_id:            Uuid,
    pub menu_item_id:        Uuid,
    pub item_name:           String,
    pub size_label:          Option<String>,
    pub unit_price:          i32,
    pub quantity:            i32,
    pub line_total:          i32,
    pub notes:               Option<String>,
    pub deductions_snapshot: serde_json::Value,
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
    pub addon_item_id: Uuid,
    #[serde(default = "default_addon_qty")]
    pub quantity:      i32,
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
    pub branch_id:          Uuid,
    pub shift_id:           Uuid,
    pub payment_method:     String,
    pub customer_name:      Option<String>,
    pub notes:              Option<String>,
    pub discount_type:      Option<String>,
    pub discount_value:     Option<i32>,
    pub discount_id:        Option<Uuid>,
    pub amount_tendered:    Option<i32>,
    pub tip_amount:         Option<i32>,
    pub tip_payment_method: Option<String>,
    pub payment_splits:     Option<Vec<PaymentSplitInput>>,
    pub items:              Vec<OrderItemInput>,
    pub created_at:         Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Deserialize)]
pub struct VoidOrderRequest {
    pub reason:            String,
    pub voided_at:         Option<chrono::DateTime<chrono::Utc>>,
    pub restore_inventory: Option<bool>,
}

#[derive(Deserialize)]
pub struct ListOrdersQuery {
    pub branch_id:      Option<Uuid>,
    pub shift_id:       Option<Uuid>,
    pub updated_after:  Option<chrono::DateTime<chrono::Utc>>,
    pub page:           Option<i64>,
    pub per_page:       Option<i64>,
    pub teller_name:    Option<String>,
    pub payment_method: Option<String>,
    pub status:         Option<String>,
    pub from:           Option<chrono::DateTime<chrono::Utc>>,
    pub to:             Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Serialize)]
pub struct PaginatedOrders {
    pub data:        Vec<Order>,
    pub total:       i64,
    pub page:        i64,
    pub per_page:    i64,
    pub total_pages: i64,
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
    if let Some(dt)  = &body.discount_type      { validate_discount_type(dt)?; }
    if let Some(tpm) = &body.tip_payment_method { validate_payment_method(tpm)?; }

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

    // ── Local types ───────────────────────────────────────────
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

    // addon_qty tracks the addon's own multiplier separately from the item
    // quantity so the substitution pass can scale inherited volumes correctly.
    // serde(skip) keeps it out of the deductions_snapshot JSON.
    #[derive(Serialize, Clone)]
    struct InventoryDeduction {
        org_ingredient_id:          Option<Uuid>,
        ingredient_name:            String,
        unit:                       String,
        quantity:                   f64,
        source:                     String,
        replaces_org_ingredient_id: Option<Uuid>,
        #[serde(skip)]
        addon_qty:                  f64,
    }

    let mut resolved_items: Vec<ResolvedItem> = Vec::new();
    let mut subtotal: i32 = 0;

    for item_input in &body.items {
        if item_input.quantity <= 0 {
            return Err(AppError::BadRequest("Item quantity must be greater than 0".into()));
        }

        let (item_name, base_price): (String, i32) = sqlx::query_as(
            "SELECT m.name, m.base_price FROM menu_items m \
             WHERE m.id = $1 AND m.deleted_at IS NULL",
        )
        .bind(item_input.menu_item_id)
        .fetch_optional(pool.get_ref())
        .await?
        .ok_or_else(|| AppError::NotFound(
            format!("Menu item {} not found", item_input.menu_item_id)
        ))?;

        let unit_price: i32 = match &item_input.size_label {
            Some(size) => {
                let size_price: Option<i32> = sqlx::query_scalar(
                    "SELECT price_override FROM item_sizes \
                     WHERE menu_item_id = $1 AND label = $2::item_size AND is_active = true"
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

        // ── Base recipe ───────────────────────────────────────
        let recipe_rows: Vec<(Option<Uuid>, f64, String, String)> =
            if let Some(size) = &item_input.size_label {
                sqlx::query_as(
                    "SELECT org_ingredient_id, quantity_used::float8, \
                            ingredient_name, ingredient_unit \
                     FROM menu_item_recipes \
                     WHERE menu_item_id = $1 AND size_label = $2::item_size",
                )
                .bind(item_input.menu_item_id)
                .bind(size)
                .fetch_all(pool.get_ref())
                .await?
            } else {
                sqlx::query_as(
                    r#"SELECT org_ingredient_id, quantity_used::float8,
                              ingredient_name, ingredient_unit
                       FROM menu_item_recipes
                       WHERE menu_item_id = $1
                         AND size_label = (
                             SELECT size_label FROM menu_item_recipes
                             WHERE menu_item_id = $1 LIMIT 1
                         )"#,
                )
                .bind(item_input.menu_item_id)
                .fetch_all(pool.get_ref())
                .await?
            };

        for (ing_id, qty, name, unit) in recipe_rows {
            item_deductions.push(InventoryDeduction {
                org_ingredient_id:          ing_id,
                ingredient_name:            name,
                unit,
                // Base recipe: scaled by item quantity only.
                quantity:                   qty * item_input.quantity as f64,
                source:                     "drink_recipe".into(),
                replaces_org_ingredient_id: None,
                addon_qty:                  1.0, // not an addon row
            });
        }

        // ── Addons ────────────────────────────────────────────
        let mut resolved_addons: Vec<ResolvedAddon> = Vec::new();

        for addon_input in &item_input.addons {
            let addon_qty = addon_input.quantity.max(1) as f64;

            let (addon_name, default_price): (String, i32) = sqlx::query_as(
                "SELECT name, default_price FROM addon_items WHERE id = $1"
            )
            .bind(addon_input.addon_item_id)
            .fetch_optional(pool.get_ref())
            .await?
            .ok_or_else(|| AppError::NotFound(
                format!("Addon {} not found", addon_input.addon_item_id)
            ))?;

            resolved_addons.push(ResolvedAddon {
                addon_item_id: addon_input.addon_item_id,
                addon_name:    addon_name.clone(),
                unit_price:    default_price, // Use global addon default price
                quantity:      addon_input.quantity.max(1),
            });

            let size_label = item_input.size_label.as_deref();

            let override_qty: Option<f64> = if let Some(size) = size_label {
                sqlx::query_scalar(
                    r#"SELECT quantity_used::float8
                       FROM menu_item_addon_overrides
                       WHERE menu_item_id = $1 AND addon_item_id = $2
                         AND (size_label = $3::item_size OR size_label IS NULL)
                       ORDER BY size_label DESC NULLS LAST LIMIT 1"#
                )
                .bind(item_input.menu_item_id)
                .bind(addon_input.addon_item_id)
                .bind(size)
                .fetch_optional(pool.get_ref())
                .await?
            } else {
                sqlx::query_scalar(
                    "SELECT quantity_used::float8 \
                     FROM menu_item_addon_overrides \
                     WHERE menu_item_id = $1 AND addon_item_id = $2 AND size_label IS NULL"
                )
                .bind(item_input.menu_item_id)
                .bind(addon_input.addon_item_id)
                .fetch_optional(pool.get_ref())
                .await?
            };

            let base_rows: Vec<(Option<Uuid>, f64, Option<Uuid>, String, String)> =
                sqlx::query_as(
                    "SELECT org_ingredient_id, quantity_used::float8, \
                            replaces_org_ingredient_id, ingredient_name, ingredient_unit \
                     FROM addon_item_ingredients WHERE addon_item_id = $1",
                )
                .bind(addon_input.addon_item_id)
                .fetch_all(pool.get_ref())
                .await?;

            for (ing_id, mut qty, replaces, name, unit) in base_rows {
                if let Some(target_override) = override_qty {
                    qty = target_override;
                }
                
                item_deductions.push(InventoryDeduction {
                    org_ingredient_id:          ing_id,
                    ingredient_name:            name,
                    unit,
                    quantity:                   qty
                        * item_input.quantity as f64
                        * addon_qty,
                    source:                     if override_qty.is_some() { "addon_override".into() } else { "addon_base".into() },
                    replaces_org_ingredient_id: replaces,
                    addon_qty,
                });
            }
        }

        // ── Substitution pass ─────────────────────────────────
        // Collect the set of base-recipe ingredient IDs being replaced.
        let mut substitutions = std::collections::HashSet::new();
        for d in &item_deductions {
            if let Some(replaced) = d.replaces_org_ingredient_id {
                substitutions.insert(replaced);
            }
        }

        if !substitutions.is_empty() {
            // First pass: capture the per-unit base quantity for each replaced
            // ingredient (i.e. already scaled by item_quantity from above).
            // We store it per-unit so the substitution addon can scale by its
            // own addon_qty independently.
            let mut replaced_qty_per_item: std::collections::HashMap<Uuid, f64> =
                std::collections::HashMap::new();
            for d in &item_deductions {
                if d.source == "drink_recipe" {
                    if let Some(id) = d.org_ingredient_id {
                        if substitutions.contains(&id) {
                            // d.quantity = recipe_qty * item_input.quantity
                            // Divide back out so we have the per-item-unit value.
                            let per_unit = d.quantity / item_input.quantity as f64;
                            *replaced_qty_per_item.entry(id).or_insert(0.0) += per_unit;
                        }
                    }
                }
            }

            // Second pass: rebuild, dropping replaced base rows and fixing up
            // substituting addon rows.
            let mut new_deductions: Vec<InventoryDeduction> = Vec::new();
            for mut d in item_deductions {
                // Drop the base-recipe row that is being substituted.
                if d.source == "drink_recipe" {
                    if let Some(id) = d.org_ingredient_id {
                        if substitutions.contains(&id) {
                            continue;
                        }
                    }
                }

                // FIX: the substituting addon inherits the base volume
                // scaled by BOTH item_quantity AND the addon's own quantity.
                if let Some(replaced_id) = d.replaces_org_ingredient_id {
                    if let Some(&per_unit) = replaced_qty_per_item.get(&replaced_id) {
                        d.quantity = per_unit * item_input.quantity as f64 * d.addon_qty;
                    }
                }

                new_deductions.push(d);
            }
            item_deductions = new_deductions;
        }

        let item_line  = unit_price * item_input.quantity;
        let addon_line: i32 = resolved_addons
            .iter()
            .map(|a| a.unit_price * a.quantity)
            .sum::<i32>()
            * item_input.quantity;
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

    let discount_amount = match resolved_discount_type.as_deref() {
        Some("percentage") => {
            (subtotal as f64 * resolved_discount_value as f64 / 100.0) as i32
        }
        Some("fixed") => resolved_discount_value.min(subtotal),
        _             => 0,
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
             amount_tendered, change_given, tip_amount, tip_payment_method,
             discount_id, customer_name, notes, status,
             idempotency_key, created_at)
        VALUES ($1, $2, $3, $4, $5::payment_method, $6, $7::discount_type, $8,
                $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, 'completed', $19, $20)
        RETURNING
            id, branch_id, shift_id, teller_id,
            (SELECT name FROM users WHERE id = $3) AS teller_name,
            order_number, status::text, payment_method::text,
            subtotal, discount_type::text, discount_value,
            discount_amount, tax_amount, total_amount,
            amount_tendered, change_given, tip_amount, tip_payment_method, discount_id,
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
    .bind(body.tip_payment_method.as_deref())
    .bind(body.discount_id)
    .bind(&body.customer_name)
    .bind(&body.notes)
    .bind(idempotency_key)
    .bind(created_at)
    .fetch_one(&mut *tx)
    .await?;

    if let Some(splits) = &body.payment_splits {
        for split in splits {
            validate_payment_method(&split.method)?;
            sqlx::query(
                "INSERT INTO order_payments \
                 (order_id, method, amount, reference) \
                 VALUES ($1, $2::payment_method, $3, $4)",
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
            "INSERT INTO order_payments (order_id, method, amount) \
             VALUES ($1, $2::payment_method, $3)",
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

        let snapshot = serde_json::to_value(&resolved.deductions)
            .unwrap_or_else(|_| serde_json::Value::Array(Vec::new()));

        let order_item = sqlx::query_as::<_, OrderItem>(
            r#"INSERT INTO order_items
                (order_id, menu_item_id, item_name, size_label,
                 unit_price, quantity, line_total, notes, deductions_snapshot)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
               RETURNING id, order_id, menu_item_id, item_name, size_label,
                         unit_price, quantity, line_total, notes, deductions_snapshot"#,
        )
        .bind(order.id)
        .bind(resolved.menu_item_id)
        .bind(&resolved.item_name)
        .bind(&resolved.size_label)
        .bind(resolved.unit_price)
        .bind(resolved.quantity)
        .bind(line_total)
        .bind(&resolved.notes)
        .bind(snapshot)
        .fetch_one(&mut *tx)
        .await?;

        let mut addon_rows: Vec<OrderItemAddon> = Vec::new();

        for addon in &resolved.addons {
            let addon_line = addon.unit_price * addon.quantity * resolved.quantity;
            let row = sqlx::query_as::<_, OrderItemAddon>(
                r#"INSERT INTO order_item_addons
                    (order_item_id, addon_item_id, addon_name,
                     unit_price, quantity, line_total)
                   VALUES ($1, $2, $3, $4, $5, $6)
                   RETURNING id, order_item_id, addon_item_id, addon_name,
                             unit_price, quantity, line_total"#,
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
            let Some(ing_id) = deduction.org_ingredient_id else {
                tracing::warn!(
                    branch_id = %body.branch_id,
                    source    = %deduction.source,
                    "Deduction skipped — recipe has no org_ingredient_id linked"
                );
                continue;
            };

            let rows_affected = sqlx::query(
                "UPDATE branch_inventory \
                 SET current_stock = current_stock - $1 \
                 WHERE branch_id = $2 AND org_ingredient_id = $3"
            )
            .bind(deduction.quantity)
            .bind(body.branch_id)
            .bind(ing_id)
            .execute(&mut *tx)
            .await?
            .rows_affected();

            if rows_affected == 0 {
                tracing::warn!(
                    branch_id         = %body.branch_id,
                    org_ingredient_id = %ing_id,
                    source            = %deduction.source,
                    "Ingredient not tracked in branch inventory — skipping deduction"
                );
            }
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

    let page     = query.page.unwrap_or(1).max(1);
    let per_page = query.per_page.unwrap_or(30).clamp(1, 999999);
    let offset   = (page - 1) * per_page;

    if let Some(pm) = &query.payment_method { validate_payment_method(pm)?; }

    let branch_id = match (query.shift_id, query.branch_id) {
        (Some(shift_id), _) => {
            let bid: Option<Uuid> = sqlx::query_scalar(
                "SELECT branch_id FROM shifts WHERE id = $1"
            )
            .bind(shift_id)
            .fetch_optional(pool.get_ref())
            .await?
            .flatten();
            bid.ok_or_else(|| AppError::NotFound("Shift not found".into()))?
        }
        (None, Some(bid)) => bid,
        _ => return Err(AppError::BadRequest(
            "Provide either shift_id or branch_id".into()
        )),
    };

    require_branch_access(pool.get_ref(), &claims, branch_id).await?;

    let scope_condition = if query.shift_id.is_some() {
        "o.shift_id = $1"
    } else {
        "o.branch_id = $1"
    };
    let scope_id = query.shift_id.unwrap_or(branch_id);

    let mut data_filter_sql  = String::new();
    let mut count_filter_sql = String::new();
    #[allow(unused_assignments)]
    let mut data_idx  = 4i32;
    #[allow(unused_assignments)]
    let mut count_idx = 2i32;

    macro_rules! push_filter {
        ($col:expr, $opt:expr) => {
            if $opt.is_some() {
                data_filter_sql.push_str( &format!(" AND {} ${}", $col, data_idx));
                count_filter_sql.push_str(&format!(" AND {} ${}", $col, count_idx));
                data_idx  += 1;
                count_idx += 1;
            }
        };
    }

    push_filter!("u.name ILIKE",             query.teller_name);
    push_filter!("o.payment_method::text =", query.payment_method);
    push_filter!("o.status::text =",         query.status);
    push_filter!("o.created_at >=",          query.from);
    push_filter!("o.created_at <=",          query.to);
    push_filter!("o.updated_at >",           query.updated_after);

    let data_sql = format!(
        "{} WHERE {} {} ORDER BY o.created_at DESC LIMIT $2 OFFSET $3",
        ORDER_SELECT, scope_condition, data_filter_sql
    );
    let count_sql = format!(
        "SELECT COUNT(*) FROM orders o JOIN users u ON u.id = o.teller_id \
         WHERE {} {}",
        scope_condition, count_filter_sql
    );

    macro_rules! bind_filters {
        ($q:expr) => {{
            let mut q = $q;
            if let Some(ref v) = query.teller_name    { q = q.bind(format!("%{}%", v)); }
            if let Some(ref v) = query.payment_method { q = q.bind(v.clone()); }
            if let Some(ref v) = query.status         { q = q.bind(v.clone()); }
            if let Some(v)     = query.from            { q = q.bind(v); }
            if let Some(v)     = query.to              { q = q.bind(v); }
            if let Some(v)     = query.updated_after   { q = q.bind(v); }
            q
        }};
    }

    let total: i64 = bind_filters!(
        sqlx::query_scalar(&count_sql).bind(scope_id)
    )
    .fetch_one(pool.get_ref())
    .await?;

    let data: Vec<Order> = bind_filters!(
        sqlx::query_as::<_, Order>(&data_sql)
            .bind(scope_id)
            .bind(per_page)
            .bind(offset)
    )
    .fetch_all(pool.get_ref())
    .await?;

    let total_pages = (total as f64 / per_page as f64).ceil() as i64;

    Ok(HttpResponse::Ok().json(PaginatedOrders {
        data,
        total,
        page,
        per_page,
        total_pages,
    }))
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
    if order.status == "voided" { return Ok(HttpResponse::Ok().json(order)); }
    validate_void_reason(&body.reason)?;
    let voided_at = body.voided_at.unwrap_or_else(chrono::Utc::now);

    let mut tx = pool.begin().await?;

    let updated = sqlx::query_as::<_, Order>(
        r#"UPDATE orders
           SET status     = 'voided',
               voided_at  = $3,
               void_reason = $2::void_reason,
               voided_by  = $4
           WHERE id = $1
           RETURNING
               id, branch_id, shift_id, teller_id,
               (SELECT name FROM users WHERE id = teller_id) AS teller_name,
               order_number, status::text, payment_method::text,
               subtotal, discount_type::text, discount_value,
               discount_amount, tax_amount, total_amount,
               amount_tendered, change_given, tip_amount, tip_payment_method,
               discount_id, customer_name, notes,
               voided_at, void_reason::text, voided_by, created_at"#,
    )
    .bind(*order_id)
    .bind(&body.reason)
    .bind(voided_at)
    .bind(claims.user_id())
    .fetch_one(&mut *tx)
    .await?;

    if body.restore_inventory.unwrap_or(false) {
        let items = fetch_order_items_full(pool.get_ref(), *order_id).await?;
        for item in items {
            if let Some(deductions) = item.item.deductions_snapshot.as_array() {
                for d in deductions {
                    if let (Some(qty), Some(ing_id_str)) = (
                        d.get("quantity").and_then(|v| v.as_f64()),
                        d.get("org_ingredient_id").and_then(|v| v.as_str()),
                    ) {
                        if let Ok(ing_id) = Uuid::parse_str(ing_id_str) {
                            sqlx::query(
                                "UPDATE branch_inventory \
                                 SET current_stock = current_stock + $1 \
                                 WHERE branch_id = $2 AND org_ingredient_id = $3"
                            )
                            .bind(qty)
                            .bind(order.branch_id)
                            .bind(ing_id)
                            .execute(&mut *tx)
                            .await?;
                        }
                    }
                }
            }
        }
    }

    tx.commit().await?;
    Ok(HttpResponse::Ok().json(updated))
}

// ── POST /orders/preview-recipe ───────────────────────────────

#[derive(Deserialize)]
pub struct PreviewRecipeAddonInput {
    pub addon_item_id: Uuid,
    // Mirrors AddonInput.quantity so preview quantities match what
    // create_order would actually deduct.
    #[serde(default = "default_addon_qty")]
    pub quantity:      i32,
}

#[derive(Deserialize)]
pub struct PreviewRecipeRequest {
    pub menu_item_id: Uuid,
    pub size_label:   Option<String>,
    pub addons:       Vec<PreviewRecipeAddonInput>,
}

#[derive(Serialize, Clone)]
pub struct PreviewIngredient {
    pub ingredient_name: String,
    pub unit:            String,
    pub quantity:        f64,
    pub source:          String,
}

pub async fn preview_recipe(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<PreviewRecipeRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "orders", "create").await?;

    // Internal deduction type — mirrors create_order's local struct exactly,
    // including the addon_qty field needed for the substitution fix.
    #[derive(Clone)]
    struct Deduction {
        org_ingredient_id:          Option<Uuid>,
        ingredient_name:            String,
        unit:                       String,
        quantity:                   f64,
        source:                     String,
        replaces_org_ingredient_id: Option<Uuid>,
        addon_qty:                  f64,
    }

    let mut deductions: Vec<Deduction> = Vec::new();

    // ── Base recipe (item_quantity = 1 for preview) ───────────
    let recipe_rows: Vec<(Option<Uuid>, f64, String, String)> =
        if let Some(size) = &body.size_label {
            sqlx::query_as(
                "SELECT org_ingredient_id, quantity_used::float8, \
                        ingredient_name, ingredient_unit \
                 FROM menu_item_recipes \
                 WHERE menu_item_id = $1 AND size_label = $2::item_size",
            )
            .bind(body.menu_item_id)
            .bind(size)
            .fetch_all(pool.get_ref())
            .await?
        } else {
            sqlx::query_as(
                r#"SELECT org_ingredient_id, quantity_used::float8,
                          ingredient_name, ingredient_unit
                   FROM menu_item_recipes
                   WHERE menu_item_id = $1
                     AND size_label = (
                         SELECT size_label FROM menu_item_recipes
                         WHERE menu_item_id = $1 LIMIT 1
                     )"#,
            )
            .bind(body.menu_item_id)
            .fetch_all(pool.get_ref())
            .await?
        };

    for (ing_id, qty, name, unit) in recipe_rows {
        deductions.push(Deduction {
            org_ingredient_id:          ing_id,
            ingredient_name:            name,
            unit,
            quantity:                   qty, // item_qty = 1
            source:                     "drink_recipe".into(),
            replaces_org_ingredient_id: None,
            addon_qty:                  1.0,
        });
    }

    // ── Addon contributions ───────────────────────────────────
    for addon in &body.addons {
        let addon_qty = addon.quantity.max(1) as f64;
        let size_label = body.size_label.as_deref();

        let override_qty: Option<f64> = if let Some(size) = size_label {
            sqlx::query_scalar(
                r#"SELECT quantity_used::float8
                   FROM menu_item_addon_overrides
                   WHERE menu_item_id = $1 AND addon_item_id = $2
                     AND (size_label = $3::item_size OR size_label IS NULL)
                   ORDER BY size_label DESC NULLS LAST LIMIT 1"#
            )
            .bind(body.menu_item_id)
            .bind(addon.addon_item_id)
            .bind(size)
            .fetch_optional(pool.get_ref())
            .await?
        } else {
            sqlx::query_scalar(
                "SELECT quantity_used::float8 \
                 FROM menu_item_addon_overrides \
                 WHERE menu_item_id = $1 AND addon_item_id = $2 AND size_label IS NULL"
            )
            .bind(body.menu_item_id)
            .bind(addon.addon_item_id)
            .fetch_optional(pool.get_ref())
            .await?
        };

        let base_rows: Vec<(Option<Uuid>, f64, Option<Uuid>, String, String)> =
            sqlx::query_as(
                "SELECT org_ingredient_id, quantity_used::float8, \
                        replaces_org_ingredient_id, ingredient_name, ingredient_unit \
                 FROM addon_item_ingredients WHERE addon_item_id = $1",
            )
            .bind(addon.addon_item_id)
            .fetch_all(pool.get_ref())
            .await?;

        for (ing_id, mut qty, replaces, name, unit) in base_rows {
            if let Some(target_override) = override_qty {
                qty = target_override;
            }

            deductions.push(Deduction {
                org_ingredient_id:          ing_id,
                ingredient_name:            name,
                unit,
                // FIX: scale by addon_qty (item_qty = 1 for preview)
                quantity:                   qty * addon_qty,
                source:                     if override_qty.is_some() { "addon_override".into() } else { "addon_base".into() },
                replaces_org_ingredient_id: replaces,
                addon_qty,
            });
        }
    }

    // ── Substitution pass ─────────────────────────────────────
    let mut substitutions = std::collections::HashSet::new();
    for d in &deductions {
        if let Some(replaced) = d.replaces_org_ingredient_id {
            substitutions.insert(replaced);
        }
    }

    let result: Vec<PreviewIngredient> = if substitutions.is_empty() {
        deductions
            .into_iter()
            .map(|d| PreviewIngredient {
                ingredient_name: d.ingredient_name,
                unit:            d.unit,
                quantity:        d.quantity,
                source:          d.source,
            })
            .collect()
    } else {
        // Capture per-unit base quantities (item_qty = 1 in preview,
        // so d.quantity is already the per-unit value).
        let mut replaced_qty_per_item: std::collections::HashMap<Uuid, f64> =
            std::collections::HashMap::new();
        for d in &deductions {
            if d.source == "drink_recipe" {
                if let Some(id) = d.org_ingredient_id {
                    if substitutions.contains(&id) {
                        *replaced_qty_per_item.entry(id).or_insert(0.0) += d.quantity;
                    }
                }
            }
        }

        let mut out: Vec<PreviewIngredient> = Vec::new();
        for mut d in deductions {
            if d.source == "drink_recipe" {
                if let Some(id) = d.org_ingredient_id {
                    if substitutions.contains(&id) {
                        continue;
                    }
                }
            }
            // FIX: inherited base qty × addon's own multiplier
            // (item_qty = 1, so no extra factor needed here)
            if let Some(replaced_id) = d.replaces_org_ingredient_id {
                if let Some(&per_unit) = replaced_qty_per_item.get(&replaced_id) {
                    d.quantity = per_unit * d.addon_qty;
                }
            }
            out.push(PreviewIngredient {
                ingredient_name: d.ingredient_name,
                unit:            d.unit,
                quantity:        d.quantity,
                source:          d.source,
            });
        }
        out
    };

    Ok(HttpResponse::Ok().json(result))
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_order_or_404(pool: &PgPool, order_id: Uuid) -> Result<Order, AppError> {
    let sql = format!("{} WHERE o.id = $1", ORDER_SELECT);
    sqlx::query_as::<_, Order>(&sql)
        .bind(order_id)
        .fetch_optional(pool)
        .await?
        .ok_or_else(|| AppError::NotFound("Order not found".into()))
}

async fn fetch_order_by_idempotency_key(
    pool: &PgPool,
    key:  Uuid,
) -> Result<Option<Order>, AppError> {
    let sql = format!("{} WHERE o.idempotency_key = $1", ORDER_SELECT);
    Ok(sqlx::query_as::<_, Order>(&sql)
        .bind(key)
        .fetch_optional(pool)
        .await?)
}

async fn fetch_order_items_full(
    pool:     &PgPool,
    order_id: Uuid,
) -> Result<Vec<OrderItemFull>, AppError> {
    let items = sqlx::query_as::<_, OrderItem>(
        "SELECT id, order_id, menu_item_id, item_name, size_label, \
                unit_price, quantity, line_total, notes, deductions_snapshot \
         FROM order_items WHERE order_id = $1 ORDER BY id",
    )
    .bind(order_id)
    .fetch_all(pool)
    .await?;

    let mut result = Vec::new();
    for item in items {
        let addons = sqlx::query_as::<_, OrderItemAddon>(
            "SELECT id, order_item_id, addon_item_id, addon_name, \
                    unit_price, quantity, line_total \
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
        "SELECT EXISTS(SELECT 1 FROM user_branch_assignments \
         WHERE user_id = $1 AND branch_id = $2)"
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
        "cash" | "card" | "digital_wallet" | "mixed"
        | "talabat_online" | "talabat_cash" => Ok(()),
        _ => Err(AppError::BadRequest("Invalid payment_method".into())),
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
        _ => Err(AppError::BadRequest("Invalid void_reason".into())),
    }
}