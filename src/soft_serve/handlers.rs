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
pub struct ServePool {
    pub id:             Uuid,
    pub branch_id:      Uuid,
    pub menu_item_id:   Uuid,
    pub item_name:      String,
    pub total_units:    sqlx::types::BigDecimal,
    pub large_ratio:    sqlx::types::BigDecimal,
    pub low_stock_flag: bool,
    pub updated_at:     chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct SoftServeBatch {
    pub id:             Uuid,
    pub branch_id:      Uuid,
    pub menu_item_id:   Uuid,
    pub item_name:      String,
    pub small_serves:   i32,
    pub large_serves:   i32,
    pub large_ratio:    sqlx::types::BigDecimal,
    pub total_units:    sqlx::types::BigDecimal,
    pub logged_by:      Uuid,
    pub logged_by_name: String,
    pub notes:          Option<String>,
    pub created_at:     chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct BatchIngredient {
    pub id:                   Uuid,
    pub batch_id:             Uuid,
    pub inventory_item_id:    Uuid,
    pub inventory_item_name:  String,
    pub unit:                 String,
    pub quantity_used:        sqlx::types::BigDecimal,
}

#[derive(Debug, Serialize)]
pub struct BatchWithIngredients {
    #[serde(flatten)]
    pub batch:       SoftServeBatch,
    pub ingredients: Vec<BatchIngredient>,
}

// ── Request types ─────────────────────────────────────────────

#[derive(Deserialize)]
pub struct BatchIngredientInput {
    pub inventory_item_id: Uuid,
    pub quantity_used:     f64,
}

#[derive(Deserialize)]
pub struct LogBatchRequest {
    pub menu_item_id: Uuid,
    pub small_serves: Option<i32>,   // defaults to 15
    pub large_serves: Option<i32>,   // defaults to 10
    pub notes:        Option<String>,
    pub ingredients:  Option<Vec<BatchIngredientInput>>, // if None, use global defaults
}

// Global soft serve batch defaults
const DEFAULT_SMALL_SERVES: i32 = 15;
const DEFAULT_LARGE_SERVES: i32 = 10;

// Default ingredient IDs are not hardcoded — manager must have set up
// inventory items named "Powder" and "Milk" on their branch.
// The defaults only apply to quantities (0.5kg each).
const DEFAULT_POWDER_KG: f64 = 0.5;
const DEFAULT_MILK_KG:   f64 = 0.5;

// ── POST /soft-serve/branches/:branch_id/batches ──────────────

pub async fn log_batch(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
    body:      web::Json<LogBatchRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "soft_serve_batches", "create").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let small_serves = body.small_serves.unwrap_or(DEFAULT_SMALL_SERVES);
    let large_serves = body.large_serves.unwrap_or(DEFAULT_LARGE_SERVES);

    if small_serves < 0 || large_serves < 0 {
        return Err(AppError::BadRequest("Serves cannot be negative".into()));
    }

    // Verify menu item exists and belongs to this branch's org
    let item_name: Option<String> = sqlx::query_scalar(
        r#"
        SELECT m.name FROM menu_items m
        JOIN branches b ON b.org_id = m.org_id
        WHERE m.id = $1 AND b.id = $2 AND m.deleted_at IS NULL
        "#,
    )
    .bind(body.menu_item_id)
    .bind(*branch_id)
    .fetch_optional(pool.get_ref())
    .await?
    .flatten();

    item_name.ok_or_else(|| AppError::NotFound("Menu item not found for this branch".into()))?;

    // Resolve ingredients — use provided list or fall back to defaults
    let ingredients = match &body.ingredients {
        Some(list) if !list.is_empty() => {
            // Validate all items belong to this branch
            for ing in list {
                let belongs: bool = sqlx::query_scalar(
                    "SELECT EXISTS(SELECT 1 FROM inventory_items WHERE id = $1 AND branch_id = $2 AND deleted_at IS NULL)"
                )
                .bind(ing.inventory_item_id)
                .bind(*branch_id)
                .fetch_one(pool.get_ref())
                .await?;

                if !belongs {
                    return Err(AppError::BadRequest(format!(
                        "Inventory item {} does not belong to this branch",
                        ing.inventory_item_id
                    )));
                }

                if ing.quantity_used <= 0.0 {
                    return Err(AppError::BadRequest(
                        "quantity_used must be greater than 0".into(),
                    ));
                }
            }
            list.iter()
                .map(|i| (i.inventory_item_id, i.quantity_used))
                .collect::<Vec<_>>()
        }
        _ => {
            // Use defaults: find items named "Powder" and "Milk" on this branch
            let powder_id: Option<Uuid> = sqlx::query_scalar(
                "SELECT id FROM inventory_items WHERE branch_id = $1 AND LOWER(name) = 'powder' AND deleted_at IS NULL LIMIT 1"
            )
            .bind(*branch_id)
            .fetch_optional(pool.get_ref())
            .await?
            .flatten();

            let milk_id: Option<Uuid> = sqlx::query_scalar(
                "SELECT id FROM inventory_items WHERE branch_id = $1 AND LOWER(name) = 'milk' AND deleted_at IS NULL LIMIT 1"
            )
            .bind(*branch_id)
            .fetch_optional(pool.get_ref())
            .await?
            .flatten();

            let mut defaults = Vec::new();
            if let Some(id) = powder_id {
                defaults.push((id, DEFAULT_POWDER_KG));
            }
            if let Some(id) = milk_id {
                defaults.push((id, DEFAULT_MILK_KG));
            }

            if defaults.is_empty() {
                return Err(AppError::BadRequest(
                    "No ingredients provided and no default 'Powder'/'Milk' items found on this branch. \
                     Please provide ingredients explicitly or create inventory items named 'Powder' and 'Milk'.".into(),
                ));
            }

            defaults
        }
    };

    let mut tx = pool.get_ref().begin().await?;

    // Create batch record
    let large_ratio = if large_serves > 0 {
        small_serves as f64 / large_serves as f64
    } else {
        1.0
    };
    let total_units = small_serves as f64 + (large_serves as f64 * large_ratio);

    let batch = sqlx::query_as::<_, SoftServeBatch>(
        r#"
        INSERT INTO soft_serve_batches
            (branch_id, menu_item_id, small_serves, large_serves, large_ratio, total_units, logged_by, notes)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING
            id, branch_id, menu_item_id,
            (SELECT name FROM menu_items WHERE id = $2) AS item_name,
            small_serves, large_serves, large_ratio, total_units,
            logged_by,
            (SELECT name FROM users WHERE id = $7) AS logged_by_name,
            notes, created_at
        "#,
    )
    .bind(*branch_id)
    .bind(body.menu_item_id)
    .bind(small_serves)
    .bind(large_serves)
    .bind(large_ratio)
    .bind(total_units)
    .bind(claims.user_id())
    .bind(&body.notes)
    .fetch_one(&mut *tx)
    .await?;

    // Insert batch ingredients + deduct from inventory
    let mut batch_ingredients: Vec<BatchIngredient> = Vec::new();

    for (inv_item_id, qty) in &ingredients {
        // Deduct from branch inventory
        sqlx::query(
            "UPDATE inventory_items SET current_stock = current_stock - $1 WHERE id = $2"
        )
        .bind(qty)
        .bind(inv_item_id)
        .execute(&mut *tx)
        .await?;

        // Log the deduction as an inventory adjustment
        sqlx::query(
            r#"
            INSERT INTO inventory_adjustments
                (branch_id, inventory_item_id, type, quantity, note, adjusted_by)
            VALUES ($1, $2, 'remove'::inventory_adjustment_type, $3, $4, $5)
            "#,
        )
        .bind(*branch_id)
        .bind(inv_item_id)
        .bind(qty)
        .bind(format!("Soft serve batch — {:.1} units ({} small, {} large, ratio 1:{:.2})", total_units, small_serves, large_serves, large_ratio))
        .bind(claims.user_id())
        .execute(&mut *tx)
        .await?;

        // Record batch ingredient
        let ing = sqlx::query_as::<_, BatchIngredient>(
            r#"
            INSERT INTO soft_serve_batch_ingredients
                (batch_id, inventory_item_id, quantity_used)
            VALUES ($1, $2, $3)
            RETURNING
                id, batch_id, inventory_item_id,
                (SELECT name FROM inventory_items WHERE id = $2) AS inventory_item_name,
                (SELECT unit::text FROM inventory_items WHERE id = $2) AS unit,
                quantity_used
            "#,
        )
        .bind(batch.id)
        .bind(inv_item_id)
        .bind(qty)
        .fetch_one(&mut *tx)
        .await?;

        batch_ingredients.push(ing);
    }

    // Upsert serve pool — add serves, clear low_stock_flag
    sqlx::query(
        r#"
        INSERT INTO soft_serve_serve_pools
            (branch_id, menu_item_id, total_units, large_ratio, low_stock_flag)
        VALUES ($1, $2, $3, $4, false)
        ON CONFLICT (branch_id, menu_item_id)
        DO UPDATE SET
            total_units    = soft_serve_serve_pools.total_units + EXCLUDED.total_units,
            large_ratio    = EXCLUDED.large_ratio,
            low_stock_flag = false,
            updated_at     = NOW()
        "#,
    )
    .bind(*branch_id)
    .bind(body.menu_item_id)
    .bind(total_units)
    .bind(large_ratio)
    .execute(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(HttpResponse::Created().json(BatchWithIngredients {
        batch,
        ingredients: batch_ingredients,
    }))
}

// ── GET /soft-serve/branches/:branch_id/batches ───────────────

pub async fn list_batches(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "soft_serve_batches", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let batches = sqlx::query_as::<_, SoftServeBatch>(
        r#"
        SELECT
            b.id, b.branch_id, b.menu_item_id,
            m.name AS item_name,
            b.small_serves, b.large_serves,
            b.logged_by,
            u.name AS logged_by_name,
            b.notes, b.created_at
        FROM soft_serve_batches b
        JOIN menu_items m ON m.id = b.menu_item_id
        JOIN users u ON u.id = b.logged_by
        WHERE b.branch_id = $1
        ORDER BY b.created_at DESC
        "#,
    )
    .bind(*branch_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(batches))
}

// ── GET /soft-serve/branches/:branch_id/pools ─────────────────

pub async fn list_serve_pools(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "soft_serve_batches", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let pools = sqlx::query_as::<_, ServePool>(
        r#"
        SELECT
            p.id, p.branch_id, p.menu_item_id,
            m.name AS item_name,
           p.total_units, p.large_ratio,
            p.low_stock_flag, p.updated_at
        FROM soft_serve_serve_pools p
        JOIN menu_items m ON m.id = p.menu_item_id
        WHERE p.branch_id = $1
        ORDER BY m.name
        "#,
    )
    .bind(*branch_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(pools))
}

// ── GET /soft-serve/branches/:branch_id/pools/:menu_item_id ───

pub async fn get_serve_pool(
    req:          HttpRequest,
    pool:         web::Data<PgPool>,
    path:         web::Path<(Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "soft_serve_batches", "read").await?;

    let (branch_id, menu_item_id) = path.into_inner();
    require_branch_access(pool.get_ref(), &claims, branch_id).await?;

    let serve_pool = sqlx::query_as::<_, ServePool>(
        r#"
        SELECT
            p.id, p.branch_id, p.menu_item_id,
            m.name AS item_name,
           p.total_units, p.large_ratio,
            p.low_stock_flag, p.updated_at
        FROM soft_serve_serve_pools p
        JOIN menu_items m ON m.id = p.menu_item_id
        WHERE p.branch_id = $1 AND p.menu_item_id = $2
        "#,
    )
    .bind(branch_id)
    .bind(menu_item_id)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Serve pool not found".into()))?;

    Ok(HttpResponse::Ok().json(serve_pool))
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
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

    let branch_org = branch_org.ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

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