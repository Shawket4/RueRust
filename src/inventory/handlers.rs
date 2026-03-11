use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    auth::jwt::Claims,
    errors::AppError,
    permissions::checker::check_permission,
};

// ── Models ────────────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct InventoryItem {
    pub id:                Uuid,
    pub branch_id:         Uuid,
    pub name:              String,
    pub unit:              String,
    pub current_stock:     sqlx::types::BigDecimal,
    pub reorder_threshold: sqlx::types::BigDecimal,
    pub cost_per_unit:     i32,
    pub is_active:         bool,
    pub created_at:        chrono::DateTime<chrono::Utc>,
    pub updated_at:        chrono::DateTime<chrono::Utc>,
}

// ── Request types ─────────────────────────────────────────────

#[derive(Deserialize)]
pub struct CreateItemRequest {
    pub name:              String,
    pub unit:              String,
    pub current_stock:     Option<f64>,   // ← add this
    pub reorder_threshold: Option<f64>,
    pub cost_per_unit:     Option<i32>,
}

#[derive(Deserialize)]
pub struct UpdateItemRequest {
    pub name:              Option<String>,
    pub unit:              Option<String>,
    pub current_stock:     Option<f64>,   // ← add this
    pub reorder_threshold: Option<f64>,
    pub cost_per_unit:     Option<i32>,
    pub is_active:         Option<bool>,
}

// ── POST /inventory/branches/:branch_id/items ─────────────────

pub async fn create_item(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
    body:      web::Json<CreateItemRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory", "create").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    validate_unit(&body.unit)?;

    let item = sqlx::query_as::<_, InventoryItem>(
        r#"
        INSERT INTO inventory_items
    (branch_id, name, unit, current_stock, reorder_threshold, cost_per_unit)
VALUES ($1, $2, $3::inventory_unit, $4, $5, $6)
        RETURNING id, branch_id, name, unit::text, current_stock,
                  reorder_threshold, cost_per_unit, is_active,
                  created_at, updated_at
        "#,
    )
    .bind(*branch_id)
    .bind(&body.name)
    .bind(&body.unit)
    .bind(body.current_stock.unwrap_or(0.0))
    .bind(body.reorder_threshold.unwrap_or(0.0))
    .bind(body.cost_per_unit.unwrap_or(0))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(item))
}

// ── GET /inventory/branches/:branch_id/items ──────────────────

pub async fn list_items(
    req:       HttpRequest,
    pool:      web::Data<PgPool>,
    branch_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory", "read").await?;
    require_branch_access(pool.get_ref(), &claims, *branch_id).await?;

    let items = sqlx::query_as::<_, InventoryItem>(
        r#"
        SELECT id, branch_id, name, unit::text, current_stock,
               reorder_threshold, cost_per_unit, is_active,
               created_at, updated_at
        FROM inventory_items
        WHERE branch_id = $1
          AND deleted_at IS NULL
        ORDER BY name
        "#,
    )
    .bind(*branch_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(items))
}

// ── GET /inventory/items/:item_id ─────────────────────────────

pub async fn get_item(
    req:     HttpRequest,
    pool:    web::Data<PgPool>,
    item_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory", "read").await?;

    let item = fetch_item_or_404(pool.get_ref(), *item_id).await?;
    require_branch_access(pool.get_ref(), &claims, item.branch_id).await?;

    Ok(HttpResponse::Ok().json(item))
}

// ── PATCH /inventory/items/:item_id ───────────────────────────

pub async fn update_item(
    req:     HttpRequest,
    pool:    web::Data<PgPool>,
    item_id: web::Path<Uuid>,
    body:    web::Json<UpdateItemRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory", "update").await?;

    let existing = fetch_item_or_404(pool.get_ref(), *item_id).await?;
    require_branch_access(pool.get_ref(), &claims, existing.branch_id).await?;

    if let Some(ref u) = body.unit {
        validate_unit(u)?;
    }

    let item = sqlx::query_as::<_, InventoryItem>(
        r#"
        UPDATE inventory_items SET
            name              = COALESCE($2, name),
            unit              = COALESCE($3::inventory_unit, unit),
            current_stock     = COALESCE($4, current_stock),
            reorder_threshold = COALESCE($5, reorder_threshold),
            cost_per_unit     = COALESCE($6, cost_per_unit),
            is_active         = COALESCE($7, is_active)
        WHERE id = $1 AND deleted_at IS NULL
        RETURNING id, branch_id, name, unit::text, current_stock,
                  reorder_threshold, cost_per_unit, is_active,
                  created_at, updated_at
        "#,
    )
    .bind(*item_id)
    .bind(&body.name)
    .bind(&body.unit)
    .bind(body.current_stock)
    .bind(body.reorder_threshold)
    .bind(body.cost_per_unit)
    .bind(body.is_active)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Inventory item not found".into()))?;

    Ok(HttpResponse::Ok().json(item))
}

// ── DELETE /inventory/items/:item_id (soft delete) ────────────

pub async fn delete_item(
    req:     HttpRequest,
    pool:    web::Data<PgPool>,
    item_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "inventory", "delete").await?;

    let existing = fetch_item_or_404(pool.get_ref(), *item_id).await?;
    require_branch_access(pool.get_ref(), &claims, existing.branch_id).await?;

    sqlx::query(
        "UPDATE inventory_items SET deleted_at = NOW() WHERE id = $1"
    )
    .bind(*item_id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_item_or_404(pool: &PgPool, item_id: Uuid) -> Result<InventoryItem, AppError> {
    sqlx::query_as::<_, InventoryItem>(
        r#"
        SELECT id, branch_id, name, unit::text, current_stock,
               reorder_threshold, cost_per_unit, is_active,
               created_at, updated_at
        FROM inventory_items
        WHERE id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(item_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Inventory item not found".into()))
}

/// Ensure the caller has access to the branch:
/// - super_admin → always allowed
/// - org_admin   → must belong to same org as branch
/// - branch_manager / teller → must be assigned to that branch
async fn require_branch_access(
    pool:      &PgPool,
    claims:    &Claims,
    branch_id: Uuid,
) -> Result<(), AppError> {
    use crate::models::UserRole;

    if claims.role == UserRole::SuperAdmin {
        return Ok(());
    }

    let caller_org: Option<Uuid> = claims.org_id();

    // Fetch branch org
    let branch_org: Option<Uuid> = sqlx::query_scalar(
        "SELECT org_id FROM branches WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(branch_id)
    .fetch_optional(pool)
    .await?
    .flatten();

    let branch_org = branch_org
        .ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

    if caller_org != Some(branch_org) {
        return Err(AppError::Forbidden("Branch belongs to a different org".into()));
    }

    if claims.role == UserRole::OrgAdmin {
        return Ok(());
    }

    // branch_manager / teller must be assigned
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

fn validate_unit(unit: &str) -> Result<(), AppError> {
    match unit {
        "g" | "kg" | "ml" | "l" | "pcs" => Ok(()),
        _ => Err(AppError::BadRequest(
            "Unit must be one of: g, kg, ml, l, pcs".into(),
        )),
    }
}