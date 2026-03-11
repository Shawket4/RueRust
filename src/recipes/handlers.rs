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
pub struct DrinkRecipe {
    pub id:                Uuid,
    pub menu_item_id:      Uuid,
    pub size_label:        String,
    pub inventory_item_id: Uuid,
    pub inventory_item_name: String,
    pub unit:              String,
    pub quantity_used:     sqlx::types::BigDecimal,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct AddonIngredient {
    pub id:                Uuid,
    pub addon_item_id:     Uuid,
    pub inventory_item_id: Uuid,
    pub inventory_item_name: String,
    pub unit:              String,
    pub quantity_used:     sqlx::types::BigDecimal,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct DrinkOptionOverride {
    pub id:                   Uuid,
    pub drink_option_item_id: Uuid,
    pub size_label:           Option<String>,
    pub inventory_item_id:    Uuid,
    pub inventory_item_name:  String,
    pub unit:                 String,
    pub quantity_used:        sqlx::types::BigDecimal,
}

// ── Request types ─────────────────────────────────────────────

#[derive(Deserialize)]
pub struct UpsertDrinkRecipeRequest {
    pub size_label:        String,   // small | medium | large | extra_large | one_size
    pub inventory_item_id: Uuid,
    pub quantity_used:     f64,
}

#[derive(Deserialize)]
pub struct UpsertAddonIngredientRequest {
    pub inventory_item_id: Uuid,
    pub quantity_used:     f64,
}

#[derive(Deserialize)]
pub struct UpsertOverrideRequest {
    pub size_label:        Option<String>, // None = applies to all sizes
    pub inventory_item_id: Uuid,
    pub quantity_used:     f64,
}

#[derive(Deserialize)]
pub struct DeleteOverrideQuery {
    pub size: Option<String>, // None = delete the all-sizes override
}

// ── GET /recipes/drinks/:menu_item_id ─────────────────────────

pub async fn list_drink_recipes(
    req:          HttpRequest,
    pool:         web::Data<PgPool>,
    menu_item_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "recipes", "read").await?;

    // Verify menu item belongs to caller's org
    require_menu_item_org(pool.get_ref(), &claims, *menu_item_id).await?;

    let rows = sqlx::query_as::<_, DrinkRecipe>(
        r#"
        SELECT r.id, r.menu_item_id, r.size_label::text,
               r.inventory_item_id,
               i.name AS inventory_item_name,
               i.unit::text AS unit,
               r.quantity_used
        FROM menu_item_recipes r
        JOIN inventory_items i ON i.id = r.inventory_item_id
        WHERE r.menu_item_id = $1
        ORDER BY r.size_label, i.name
        "#,
    )
    .bind(*menu_item_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

// ── POST /recipes/drinks/:menu_item_id ────────────────────────

pub async fn upsert_drink_recipe(
    req:          HttpRequest,
    pool:         web::Data<PgPool>,
    menu_item_id: web::Path<Uuid>,
    body:         web::Json<UpsertDrinkRecipeRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "recipes", "create").await?;
    require_menu_item_org(pool.get_ref(), &claims, *menu_item_id).await?;

    if body.quantity_used <= 0.0 {
        return Err(AppError::BadRequest("quantity_used must be greater than 0".into()));
    }

    let row = sqlx::query_as::<_, DrinkRecipe>(
        r#"
        INSERT INTO menu_item_recipes
            (menu_item_id, size_label, inventory_item_id, quantity_used)
        VALUES ($1, $2::item_size, $3, $4)
        ON CONFLICT (menu_item_id, size_label, inventory_item_id)
        DO UPDATE SET quantity_used = EXCLUDED.quantity_used
        RETURNING id, menu_item_id, size_label::text,
                  inventory_item_id,
                  (SELECT name FROM inventory_items WHERE id = EXCLUDED.inventory_item_id) AS inventory_item_name,
                  (SELECT unit::text FROM inventory_items WHERE id = EXCLUDED.inventory_item_id) AS unit,
                  quantity_used
        "#,
    )
    .bind(*menu_item_id)
    .bind(&body.size_label)
    .bind(body.inventory_item_id)
    .bind(body.quantity_used)
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(row))
}

// ── DELETE /recipes/drinks/:menu_item_id/:size/:inventory_item_id

pub async fn delete_drink_recipe(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, String, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "recipes", "delete").await?;

    let (menu_item_id, size_label, inventory_item_id) = path.into_inner();
    require_menu_item_org(pool.get_ref(), &claims, menu_item_id).await?;

    sqlx::query(
        r#"
        DELETE FROM menu_item_recipes
        WHERE menu_item_id = $1
          AND size_label   = $2::item_size
          AND inventory_item_id = $3
        "#,
    )
    .bind(menu_item_id)
    .bind(&size_label)
    .bind(inventory_item_id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── GET /recipes/addons/:addon_item_id ────────────────────────

pub async fn list_addon_ingredients(
    req:          HttpRequest,
    pool:         web::Data<PgPool>,
    addon_item_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "recipes", "read").await?;
    require_addon_org(pool.get_ref(), &claims, *addon_item_id).await?;

    let rows = sqlx::query_as::<_, AddonIngredient>(
        r#"
        SELECT a.id, a.addon_item_id,
               a.inventory_item_id,
               i.name AS inventory_item_name,
               i.unit::text AS unit,
               a.quantity_used
        FROM addon_item_ingredients a
        JOIN inventory_items i ON i.id = a.inventory_item_id
        WHERE a.addon_item_id = $1
        ORDER BY i.name
        "#,
    )
    .bind(*addon_item_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

// ── POST /recipes/addons/:addon_item_id ───────────────────────

pub async fn upsert_addon_ingredient(
    req:           HttpRequest,
    pool:          web::Data<PgPool>,
    addon_item_id: web::Path<Uuid>,
    body:          web::Json<UpsertAddonIngredientRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "recipes", "create").await?;
    require_addon_org(pool.get_ref(), &claims, *addon_item_id).await?;

    if body.quantity_used <= 0.0 {
        return Err(AppError::BadRequest("quantity_used must be greater than 0".into()));
    }

    let row = sqlx::query_as::<_, AddonIngredient>(
        r#"
        INSERT INTO addon_item_ingredients
            (addon_item_id, inventory_item_id, quantity_used)
        VALUES ($1, $2, $3)
        ON CONFLICT (addon_item_id, inventory_item_id)
        DO UPDATE SET quantity_used = EXCLUDED.quantity_used
        RETURNING id, addon_item_id,
                  inventory_item_id,
                  (SELECT name FROM inventory_items WHERE id = EXCLUDED.inventory_item_id) AS inventory_item_name,
                  (SELECT unit::text FROM inventory_items WHERE id = EXCLUDED.inventory_item_id) AS unit,
                  quantity_used
        "#,
    )
    .bind(*addon_item_id)
    .bind(body.inventory_item_id)
    .bind(body.quantity_used)
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(row))
}

// ── DELETE /recipes/addons/:addon_item_id/:inventory_item_id ──

pub async fn delete_addon_ingredient(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "recipes", "delete").await?;

    let (addon_item_id, inventory_item_id) = path.into_inner();
    require_addon_org(pool.get_ref(), &claims, addon_item_id).await?;

    sqlx::query(
        "DELETE FROM addon_item_ingredients WHERE addon_item_id = $1 AND inventory_item_id = $2"
    )
    .bind(addon_item_id)
    .bind(inventory_item_id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── GET /recipes/overrides/:drink_option_item_id ──────────────

pub async fn list_overrides(
    req:                 HttpRequest,
    pool:                web::Data<PgPool>,
    drink_option_item_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "recipes", "read").await?;
    require_drink_option_org(pool.get_ref(), &claims, *drink_option_item_id).await?;

    let rows = sqlx::query_as::<_, DrinkOptionOverride>(
        r#"
        SELECT o.id, o.drink_option_item_id,
               o.size_label::text,
               o.inventory_item_id,
               i.name AS inventory_item_name,
               i.unit::text AS unit,
               o.quantity_used
        FROM drink_option_ingredient_overrides o
        JOIN inventory_items i ON i.id = o.inventory_item_id
        WHERE o.drink_option_item_id = $1
        ORDER BY o.size_label, i.name
        "#,
    )
    .bind(*drink_option_item_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

// ── POST /recipes/overrides/:drink_option_item_id ─────────────

pub async fn upsert_override(
    req:                  HttpRequest,
    pool:                 web::Data<PgPool>,
    drink_option_item_id: web::Path<Uuid>,
    body:                 web::Json<UpsertOverrideRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "recipes", "create").await?;
    require_drink_option_org(pool.get_ref(), &claims, *drink_option_item_id).await?;

    if body.quantity_used <= 0.0 {
        return Err(AppError::BadRequest("quantity_used must be greater than 0".into()));
    }

    let row = sqlx::query_as::<_, DrinkOptionOverride>(
        r#"
        INSERT INTO drink_option_ingredient_overrides
            (drink_option_item_id, size_label, inventory_item_id, quantity_used)
        VALUES ($1, $2::item_size, $3, $4)
        ON CONFLICT (drink_option_item_id, size_label, inventory_item_id)
        DO UPDATE SET quantity_used = EXCLUDED.quantity_used
        RETURNING id, drink_option_item_id,
                  size_label::text,
                  inventory_item_id,
                  (SELECT name FROM inventory_items WHERE id = EXCLUDED.inventory_item_id) AS inventory_item_name,
                  (SELECT unit::text FROM inventory_items WHERE id = EXCLUDED.inventory_item_id) AS unit,
                  quantity_used
        "#,
    )
    .bind(*drink_option_item_id)
    .bind(&body.size_label)
    .bind(body.inventory_item_id)
    .bind(body.quantity_used)
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(row))
}

// ── DELETE /recipes/overrides/:drink_option_item_id/:inventory_item_id

pub async fn delete_override(
    req:   HttpRequest,
    pool:  web::Data<PgPool>,
    path:  web::Path<(Uuid, Uuid)>,
    query: web::Query<DeleteOverrideQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "recipes", "delete").await?;

    let (drink_option_item_id, inventory_item_id) = path.into_inner();
    require_drink_option_org(pool.get_ref(), &claims, drink_option_item_id).await?;

    // If ?size= provided, delete that specific size override.
    // If not provided, delete the NULL (all-sizes) override.
    match &query.size {
        Some(size) => {
            sqlx::query(
                r#"
                DELETE FROM drink_option_ingredient_overrides
                WHERE drink_option_item_id = $1
                  AND inventory_item_id    = $2
                  AND size_label           = $3::item_size
                "#,
            )
            .bind(drink_option_item_id)
            .bind(inventory_item_id)
            .bind(size)
            .execute(pool.get_ref())
            .await?;
        }
        None => {
            sqlx::query(
                r#"
                DELETE FROM drink_option_ingredient_overrides
                WHERE drink_option_item_id = $1
                  AND inventory_item_id    = $2
                  AND size_label IS NULL
                "#,
            )
            .bind(drink_option_item_id)
            .bind(inventory_item_id)
            .execute(pool.get_ref())
            .await?;
        }
    }

    Ok(HttpResponse::NoContent().finish())
}

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

/// Verify menu item belongs to caller's org
async fn require_menu_item_org(
    pool:         &PgPool,
    claims:       &Claims,
    menu_item_id: Uuid,
) -> Result<(), AppError> {
    use crate::models::UserRole;
    if claims.role == UserRole::SuperAdmin { return Ok(()); }

    let item_org: Option<Uuid> = sqlx::query_scalar(
        "SELECT org_id FROM menu_items WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(menu_item_id)
    .fetch_optional(pool)
    .await?
    .flatten();

    let item_org = item_org.ok_or_else(|| AppError::NotFound("Menu item not found".into()))?;

    if claims.org_id() != Some(item_org) {
        return Err(AppError::Forbidden("Menu item belongs to a different org".into()));
    }
    Ok(())
}

/// Verify addon item belongs to caller's org
async fn require_addon_org(
    pool:          &PgPool,
    claims:        &Claims,
    addon_item_id: Uuid,
) -> Result<(), AppError> {
    use crate::models::UserRole;
    if claims.role == UserRole::SuperAdmin { return Ok(()); }

    let addon_org: Option<Uuid> = sqlx::query_scalar(
        "SELECT org_id FROM addon_items WHERE id = $1"
    )
    .bind(addon_item_id)
    .fetch_optional(pool)
    .await?
    .flatten();

    let addon_org = addon_org.ok_or_else(|| AppError::NotFound("Addon item not found".into()))?;

    if claims.org_id() != Some(addon_org) {
        return Err(AppError::Forbidden("Addon item belongs to a different org".into()));
    }
    Ok(())
}

/// Verify drink_option_item belongs to caller's org (via group → menu_item → org)
async fn require_drink_option_org(
    pool:                 &PgPool,
    claims:               &Claims,
    drink_option_item_id: Uuid,
) -> Result<(), AppError> {
    use crate::models::UserRole;
    if claims.role == UserRole::SuperAdmin { return Ok(()); }

    let item_org: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT m.org_id
        FROM drink_option_items doi
        JOIN drink_option_groups dog ON dog.id = doi.group_id
        JOIN menu_items m ON m.id = dog.menu_item_id
        WHERE doi.id = $1
        "#,
    )
    .bind(drink_option_item_id)
    .fetch_optional(pool)
    .await?
    .flatten();

    let item_org = item_org
        .ok_or_else(|| AppError::NotFound("Drink option item not found".into()))?;

    if claims.org_id() != Some(item_org) {
        return Err(AppError::Forbidden("Drink option belongs to a different org".into()));
    }
    Ok(())
}