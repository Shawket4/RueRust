use actix_web::{web, HttpRequest, HttpResponse};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;
use actix_web::HttpMessage;

use crate::{
    auth::{guards::require_same_org, jwt::Claims},
    errors::AppError,
    permissions::checker::check_permission,
};

// ── Models ────────────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Category {
    pub id:            Uuid,
    pub org_id:        Uuid,
    pub name:          String,
    pub image_url:     Option<String>,
    pub display_order: i32,
    pub is_active:     bool,
    pub created_at:    DateTime<Utc>,
    pub updated_at:    DateTime<Utc>,
    pub deleted_at:    Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct MenuItem {
    pub id:            Uuid,
    pub org_id:        Uuid,
    pub category_id:   Option<Uuid>,
    pub name:          String,
    pub description:   Option<String>,
    pub image_url:     Option<String>,
    pub base_price:    i32,
    pub is_active:     bool,
    pub display_order: i32,
    pub created_at:    DateTime<Utc>,
    pub updated_at:    DateTime<Utc>,
    pub deleted_at:    Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct ItemSize {
    pub id:             Uuid,
    pub menu_item_id:   Uuid,
    pub label:          String,
    pub price_override: i32,
    pub display_order:  i32,
    pub is_active:      bool,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct AddonItem {
    pub id:            Uuid,
    pub org_id:        Uuid,
    pub name:          String,
    pub addon_type:    String,
    pub default_price: i32,
    pub is_active:     bool,
    pub display_order: i32,
    pub created_at:    DateTime<Utc>,
    pub updated_at:    DateTime<Utc>,
}

// ── Addon Slot models ─────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct AddonSlot {
    pub id:             Uuid,
    pub menu_item_id:   Uuid,
    pub addon_type:     String,
    pub label:          Option<String>,
    pub is_required:    bool,
    pub min_selections: i32,
    pub max_selections: Option<i32>,
    pub display_order:  i32,
    pub created_at:     DateTime<Utc>,
}

// ── Addon Override models ─────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct AddonOverride {
    pub id:                         Uuid,
    pub menu_item_id:               Uuid,
    pub addon_item_id:              Uuid,
    pub addon_item_name:            String,
    pub size_label:                 Option<String>,
    pub ingredient_name:            String,
    pub org_ingredient_id:          Option<Uuid>,
    pub ingredient_unit:            String,
    pub quantity_used:              sqlx::types::BigDecimal,
    pub replaces_org_ingredient_id: Option<Uuid>,
    pub replaces_ingredient_name:   Option<String>,
    pub combo_addon_item_id:        Option<Uuid>,
    pub combo_addon_item_name:      Option<String>,
    pub created_at:                 DateTime<Utc>,
    pub updated_at:                 DateTime<Utc>,
}

// ── MenuItemFull — slots embedded instead of option_groups ────

#[derive(Debug, Serialize)]
pub struct MenuItemFull {
    #[serde(flatten)]
    pub item:        MenuItem,
    pub sizes:       Vec<ItemSize>,
    pub addon_slots: Vec<AddonSlot>,
}

// ── Request types ─────────────────────────────────────────────

#[derive(Deserialize)]
pub struct OrgQuery {
    pub org_id: Uuid,
}

#[derive(Deserialize)]
pub struct MenuItemQuery {
    pub org_id:      Uuid,
    pub category_id: Option<Uuid>,
    pub full:        Option<bool>,
}

#[derive(Deserialize)]
pub struct AddonItemQuery {
    pub org_id:     Uuid,
    pub addon_type: Option<String>,
}

#[derive(Deserialize)]
pub struct CreateCategoryRequest {
    pub org_id:        Uuid,
    pub name:          String,
    pub image_url:     Option<String>,
    pub display_order: Option<i32>,
}

#[derive(Deserialize)]
pub struct UpdateCategoryRequest {
    pub name:          Option<String>,
    pub image_url:     Option<String>,
    pub display_order: Option<i32>,
    pub is_active:     Option<bool>,
}

#[derive(Deserialize)]
pub struct CreateMenuItemRequest {
    pub org_id:        Uuid,
    pub category_id:   Uuid,
    pub name:          String,
    pub description:   Option<String>,
    pub image_url:     Option<String>,
    pub base_price:    i32,
    pub display_order: Option<i32>,
}

#[derive(Deserialize)]
pub struct UpdateMenuItemRequest {
    pub category_id:   Option<Uuid>,
    pub name:          Option<String>,
    pub description:   Option<String>,
    pub image_url:     Option<String>,
    pub base_price:    Option<i32>,
    pub display_order: Option<i32>,
    pub is_active:     Option<bool>,
}

#[derive(Deserialize)]
pub struct CreateAddonItemRequest {
    pub org_id:        Uuid,
    pub name:          String,
    pub addon_type:    String,
    pub default_price: i32,
    pub display_order: Option<i32>,
}

#[derive(Deserialize)]
pub struct UpdateAddonItemRequest {
    pub name:          Option<String>,
    pub addon_type:    Option<String>,
    pub default_price: Option<i32>,
    pub display_order: Option<i32>,
    pub is_active:     Option<bool>,
}

#[derive(Deserialize)]
pub struct UpsertSizeRequest {
    pub label:          String,
    pub price_override: i32,
    pub display_order:  Option<i32>,
}

#[derive(Deserialize)]
pub struct CreateAddonSlotRequest {
    pub addon_type:     String,
    pub label:          Option<String>,
    pub is_required:    Option<bool>,
    pub min_selections: Option<i32>,
    pub max_selections: Option<i32>,
    pub display_order:  Option<i32>,
}

#[derive(Deserialize)]
pub struct UpdateAddonSlotRequest {
    pub label:          Option<String>,
    pub is_required:    Option<bool>,
    pub min_selections: Option<i32>,
    pub max_selections: Option<i32>,
    pub display_order:  Option<i32>,
}

#[derive(Deserialize)]
pub struct UpsertAddonOverrideRequest {
    pub addon_item_id:              Uuid,
    pub size_label:                 Option<String>,
    pub ingredient_name:            String,
    pub org_ingredient_id:          Option<Uuid>,
    pub ingredient_unit:            String,
    pub quantity_used:              f64,
    pub replaces_org_ingredient_id: Option<Uuid>,
    pub combo_addon_item_id:        Option<Uuid>,
}

// ── Categories ────────────────────────────────────────────────

pub async fn list_categories(
    req:   HttpRequest,
    pool:  web::Data<PgPool>,
    query: web::Query<OrgQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "categories", "read").await?;
    require_same_org(&claims, Some(query.org_id))?;

    let rows = sqlx::query_as::<_, Category>(
        "SELECT id, org_id, name, image_url, display_order, is_active,
                created_at, updated_at, deleted_at
         FROM categories
         WHERE org_id = $1 AND deleted_at IS NULL
         ORDER BY display_order ASC, name ASC",
    )
    .bind(query.org_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

pub async fn create_category(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateCategoryRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "categories", "create").await?;
    require_same_org(&claims, Some(body.org_id))?;

    let row = sqlx::query_as::<_, Category>(
        "INSERT INTO categories (org_id, name, image_url, display_order)
         VALUES ($1, $2, $3, $4)
         RETURNING id, org_id, name, image_url, display_order, is_active,
                   created_at, updated_at, deleted_at",
    )
    .bind(body.org_id)
    .bind(&body.name)
    .bind(&body.image_url)
    .bind(body.display_order.unwrap_or(0))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(row))
}

pub async fn update_category(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<UpdateCategoryRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "categories", "update").await?;

    let existing = fetch_category(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    let row = sqlx::query_as::<_, Category>(
        "UPDATE categories SET
             name          = COALESCE($2, name),
             image_url     = COALESCE($3, image_url),
             display_order = COALESCE($4, display_order),
             is_active     = COALESCE($5, is_active)
         WHERE id = $1 AND deleted_at IS NULL
         RETURNING id, org_id, name, image_url, display_order, is_active,
                   created_at, updated_at, deleted_at",
    )
    .bind(*id)
    .bind(&body.name)
    .bind(&body.image_url)
    .bind(body.display_order)
    .bind(body.is_active)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Category not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

pub async fn delete_category(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "categories", "delete").await?;

    let existing = fetch_category(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    sqlx::query(
        "UPDATE categories SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(*id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Menu Items ────────────────────────────────────────────────

pub async fn list_menu_items(
    req:   HttpRequest,
    pool:  web::Data<PgPool>,
    query: web::Query<MenuItemQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "read").await?;
    require_same_org(&claims, Some(query.org_id))?;

    let items = match query.category_id {
        Some(cat_id) => sqlx::query_as::<_, MenuItem>(
            "SELECT id, org_id, category_id, name, description, image_url,
                    base_price, is_active, display_order,
                    created_at, updated_at, deleted_at
             FROM menu_items
             WHERE org_id = $1 AND deleted_at IS NULL AND category_id = $2
             ORDER BY display_order ASC, name ASC",
        )
        .bind(query.org_id)
        .bind(cat_id)
        .fetch_all(pool.get_ref())
        .await?,

        None => sqlx::query_as::<_, MenuItem>(
            "SELECT id, org_id, category_id, name, description, image_url,
                    base_price, is_active, display_order,
                    created_at, updated_at, deleted_at
             FROM menu_items
             WHERE org_id = $1 AND deleted_at IS NULL
             ORDER BY display_order ASC, name ASC",
        )
        .bind(query.org_id)
        .fetch_all(pool.get_ref())
        .await?,
    };

    // ?full=true embeds sizes + addon_slots for each item
    if query.full.unwrap_or(false) {
        let mut result: Vec<MenuItemFull> = vec![];
        for item in items {
            let sizes = fetch_sizes(pool.get_ref(), item.id).await?;
            let addon_slots = fetch_addon_slots(pool.get_ref(), item.id).await?;
            result.push(MenuItemFull { item, sizes, addon_slots });
        }
        return Ok(HttpResponse::Ok().json(result));
    }

    Ok(HttpResponse::Ok().json(items))
}

pub async fn get_menu_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "read").await?;

    let item = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let sizes       = fetch_sizes(pool.get_ref(), *id).await?;
    let addon_slots = fetch_addon_slots(pool.get_ref(), *id).await?;

    Ok(HttpResponse::Ok().json(MenuItemFull { item, sizes, addon_slots }))
}

pub async fn create_menu_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateMenuItemRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "create").await?;
    require_same_org(&claims, Some(body.org_id))?;

    let item = sqlx::query_as::<_, MenuItem>(
        "INSERT INTO menu_items
             (org_id, category_id, name, description, image_url, base_price, display_order)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id, org_id, category_id, name, description, image_url,
                   base_price, is_active, display_order,
                   created_at, updated_at, deleted_at",
    )
    .bind(body.org_id)
    .bind(body.category_id)
    .bind(&body.name)
    .bind(&body.description)
    .bind(&body.image_url)
    .bind(body.base_price)
    .bind(body.display_order.unwrap_or(0))
    .fetch_one(pool.get_ref())
    .await?;

    // No auto-attach of option groups — global addon types (milk_type,
    // coffee_type, extra) are shown on every drink by the POS without
    // per-item linking. Custom slots are added by the admin via the
    // /addon-slots endpoints.

    Ok(HttpResponse::Created().json(MenuItemFull {
        item,
        sizes:       vec![],
        addon_slots: vec![],
    }))
}

pub async fn update_menu_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<UpdateMenuItemRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let existing = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    let item = sqlx::query_as::<_, MenuItem>(
        "UPDATE menu_items SET
             category_id   = COALESCE($2, category_id),
             name          = COALESCE($3, name),
             description   = COALESCE($4, description),
             image_url     = COALESCE($5, image_url),
             base_price    = COALESCE($6, base_price),
             display_order = COALESCE($7, display_order),
             is_active     = COALESCE($8, is_active)
         WHERE id = $1 AND deleted_at IS NULL
         RETURNING id, org_id, category_id, name, description, image_url,
                   base_price, is_active, display_order,
                   created_at, updated_at, deleted_at",
    )
    .bind(*id)
    .bind(body.category_id)
    .bind(&body.name)
    .bind(&body.description)
    .bind(&body.image_url)
    .bind(body.base_price)
    .bind(body.display_order)
    .bind(body.is_active)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Menu item not found".into()))?;

    Ok(HttpResponse::Ok().json(item))
}

pub async fn delete_menu_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "delete").await?;

    let existing = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    sqlx::query(
        "UPDATE menu_items SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(*id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Sizes ─────────────────────────────────────────────────────

pub async fn upsert_size(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<UpsertSizeRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let row = sqlx::query_as::<_, ItemSize>(
        "INSERT INTO item_sizes (menu_item_id, label, price_override, display_order)
         VALUES ($1, $2::item_size, $3, $4)
         ON CONFLICT (menu_item_id, label) DO UPDATE SET
             price_override = EXCLUDED.price_override,
             display_order  = EXCLUDED.display_order,
             is_active      = TRUE
         RETURNING id, menu_item_id, label::text, price_override, display_order, is_active",
    )
    .bind(*id)
    .bind(&body.label)
    .bind(body.price_override)
    .bind(body.display_order.unwrap_or(0))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(row))
}

pub async fn delete_size(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims         = extract_claims(&req)?;
    let (item_id, sid) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    sqlx::query("DELETE FROM item_sizes WHERE id = $1 AND menu_item_id = $2")
        .bind(sid)
        .bind(item_id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Addon Items ───────────────────────────────────────────────

pub async fn list_addon_items(
    req:   HttpRequest,
    pool:  web::Data<PgPool>,
    query: web::Query<AddonItemQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "read").await?;
    require_same_org(&claims, Some(query.org_id))?;

    let rows = match &query.addon_type {
        Some(t) => sqlx::query_as::<_, AddonItem>(
            "SELECT id, org_id, name, type as addon_type, default_price,
                    is_active, display_order, created_at, updated_at
             FROM addon_items
             WHERE org_id = $1 AND type = $2
             ORDER BY type ASC, display_order ASC",
        )
        .bind(query.org_id)
        .bind(t)
        .fetch_all(pool.get_ref())
        .await?,

        None => sqlx::query_as::<_, AddonItem>(
            "SELECT id, org_id, name, type as addon_type, default_price,
                    is_active, display_order, created_at, updated_at
             FROM addon_items
             WHERE org_id = $1
             ORDER BY type ASC, display_order ASC",
        )
        .bind(query.org_id)
        .fetch_all(pool.get_ref())
        .await?,
    };

    Ok(HttpResponse::Ok().json(rows))
}

pub async fn create_addon_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateAddonItemRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "create").await?;
    require_same_org(&claims, Some(body.org_id))?;

    let row = sqlx::query_as::<_, AddonItem>(
        "INSERT INTO addon_items (org_id, name, type, default_price, display_order)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, org_id, name, type as addon_type, default_price,
                   is_active, display_order, created_at, updated_at",
    )
    .bind(body.org_id)
    .bind(&body.name)
    .bind(&body.addon_type)
    .bind(body.default_price)
    .bind(body.display_order.unwrap_or(0))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(row))
}

pub async fn update_addon_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<UpdateAddonItemRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let existing = fetch_addon_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    let row = sqlx::query_as::<_, AddonItem>(
        "UPDATE addon_items SET
             name          = COALESCE($2, name),
             type          = COALESCE($3, type),
             default_price = COALESCE($4, default_price),
             display_order = COALESCE($5, display_order),
             is_active     = COALESCE($6, is_active)
         WHERE id = $1
         RETURNING id, org_id, name, type as addon_type, default_price,
                   is_active, display_order, created_at, updated_at",
    )
    .bind(*id)
    .bind(&body.name)
    .bind(&body.addon_type)
    .bind(body.default_price)
    .bind(body.display_order)
    .bind(body.is_active)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Addon item not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

pub async fn delete_addon_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "delete").await?;

    let existing = fetch_addon_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    sqlx::query("DELETE FROM addon_items WHERE id = $1")
        .bind(*id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Addon Slots ───────────────────────────────────────────────

pub async fn list_addon_slots(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "read").await?;

    let item = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let slots = fetch_addon_slots(pool.get_ref(), *id).await?;
    Ok(HttpResponse::Ok().json(slots))
}

pub async fn create_addon_slot(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<CreateAddonSlotRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let row = sqlx::query_as::<_, AddonSlot>(
        "INSERT INTO menu_item_addon_slots
             (menu_item_id, addon_type, label, is_required,
              min_selections, max_selections, display_order)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (menu_item_id, addon_type) DO UPDATE SET
             label          = COALESCE(EXCLUDED.label, menu_item_addon_slots.label),
             is_required    = EXCLUDED.is_required,
             min_selections = EXCLUDED.min_selections,
             max_selections = EXCLUDED.max_selections,
             display_order  = EXCLUDED.display_order
         RETURNING id, menu_item_id, addon_type, label, is_required,
                   min_selections, max_selections, display_order, created_at",
    )
    .bind(*id)
    .bind(&body.addon_type)
    .bind(&body.label)
    .bind(body.is_required.unwrap_or(false))
    .bind(body.min_selections.unwrap_or(0))
    .bind(body.max_selections)
    .bind(body.display_order.unwrap_or(0))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(row))
}

pub async fn update_addon_slot(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid)>,
    body: web::Json<UpdateAddonSlotRequest>,
) -> Result<HttpResponse, AppError> {
    let claims              = extract_claims(&req)?;
    let (item_id, slot_id)  = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let row = sqlx::query_as::<_, AddonSlot>(
        "UPDATE menu_item_addon_slots SET
             label          = COALESCE($3, label),
             is_required    = COALESCE($4, is_required),
             min_selections = COALESCE($5, min_selections),
             max_selections = COALESCE($6, max_selections),
             display_order  = COALESCE($7, display_order)
         WHERE id = $1 AND menu_item_id = $2
         RETURNING id, menu_item_id, addon_type, label, is_required,
                   min_selections, max_selections, display_order, created_at",
    )
    .bind(slot_id)
    .bind(item_id)
    .bind(&body.label)
    .bind(body.is_required)
    .bind(body.min_selections)
    .bind(body.max_selections)
    .bind(body.display_order)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Addon slot not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

pub async fn delete_addon_slot(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims             = extract_claims(&req)?;
    let (item_id, slot_id) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "delete").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    sqlx::query(
        "DELETE FROM menu_item_addon_slots WHERE id = $1 AND menu_item_id = $2",
    )
    .bind(slot_id)
    .bind(item_id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Addon Overrides ───────────────────────────────────────────

pub async fn list_addon_overrides(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "read").await?;

    let item = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let rows = sqlx::query_as::<_, AddonOverride>(
        r#"
        SELECT
            o.id,
            o.menu_item_id,
            o.addon_item_id,
            ai.name                                      AS addon_item_name,
            o.size_label::text                           AS size_label,
            o.ingredient_name,
            o.org_ingredient_id,
            o.ingredient_unit,
            o.quantity_used,
            o.replaces_org_ingredient_id,
            ri.name                                      AS replaces_ingredient_name,
            o.combo_addon_item_id,
            ci.name                                      AS combo_addon_item_name,
            o.created_at,
            o.updated_at
        FROM  menu_item_addon_overrides o
        JOIN  addon_items ai ON ai.id = o.addon_item_id
        LEFT JOIN org_ingredients ri ON ri.id = o.replaces_org_ingredient_id
        LEFT JOIN addon_items      ci ON ci.id = o.combo_addon_item_id
        WHERE o.menu_item_id = $1
        ORDER BY ai.name ASC, o.size_label ASC NULLS FIRST,
                 o.ingredient_name ASC, o.combo_addon_item_id ASC NULLS FIRST
        "#,
    )
    .bind(*id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

pub async fn upsert_addon_override(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<UpsertAddonOverrideRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    // Verify the addon_item belongs to the same org
    let addon = fetch_addon_item(pool.get_ref(), body.addon_item_id).await?;
    require_same_org(&claims, Some(addon.org_id))?;

    // Upsert using the appropriate partial unique index path.
    // Because size_label and combo_addon_item_id are nullable we can't use
    // a single ON CONFLICT clause — instead we do a manual upsert:
    // try UPDATE first, INSERT if no row matched.
    let existing_id: Option<Uuid> = match (body.size_label.as_deref(), body.combo_addon_item_id) {
        (Some(size), Some(combo)) => sqlx::query_scalar(
            "SELECT id FROM menu_item_addon_overrides
             WHERE menu_item_id = $1 AND addon_item_id = $2
               AND ingredient_name = $3
               AND size_label = $4::item_size
               AND combo_addon_item_id = $5",
        )
        .bind(*id).bind(body.addon_item_id).bind(&body.ingredient_name)
        .bind(size).bind(combo)
        .fetch_optional(pool.get_ref()).await?,

        (Some(size), None) => sqlx::query_scalar(
            "SELECT id FROM menu_item_addon_overrides
             WHERE menu_item_id = $1 AND addon_item_id = $2
               AND ingredient_name = $3
               AND size_label = $4::item_size
               AND combo_addon_item_id IS NULL",
        )
        .bind(*id).bind(body.addon_item_id).bind(&body.ingredient_name)
        .bind(size)
        .fetch_optional(pool.get_ref()).await?,

        (None, Some(combo)) => sqlx::query_scalar(
            "SELECT id FROM menu_item_addon_overrides
             WHERE menu_item_id = $1 AND addon_item_id = $2
               AND ingredient_name = $3
               AND size_label IS NULL
               AND combo_addon_item_id = $4",
        )
        .bind(*id).bind(body.addon_item_id).bind(&body.ingredient_name)
        .bind(combo)
        .fetch_optional(pool.get_ref()).await?,

        (None, None) => sqlx::query_scalar(
            "SELECT id FROM menu_item_addon_overrides
             WHERE menu_item_id = $1 AND addon_item_id = $2
               AND ingredient_name = $3
               AND size_label IS NULL
               AND combo_addon_item_id IS NULL",
        )
        .bind(*id).bind(body.addon_item_id).bind(&body.ingredient_name)
        .fetch_optional(pool.get_ref()).await?,
    }
    .flatten();

    let row = if let Some(eid) = existing_id {
        sqlx::query_as::<_, AddonOverride>(
            r#"
            UPDATE menu_item_addon_overrides SET
                org_ingredient_id          = $2,
                ingredient_unit            = $3,
                quantity_used              = $4,
                replaces_org_ingredient_id = $5,
                updated_at                 = NOW()
            WHERE id = $1
            RETURNING
                id, menu_item_id, addon_item_id,
                (SELECT name FROM addon_items WHERE id = addon_item_id) AS addon_item_name,
                size_label::text,
                ingredient_name, org_ingredient_id, ingredient_unit, quantity_used,
                replaces_org_ingredient_id,
                (SELECT name FROM org_ingredients WHERE id = replaces_org_ingredient_id)
                    AS replaces_ingredient_name,
                combo_addon_item_id,
                (SELECT name FROM addon_items WHERE id = combo_addon_item_id)
                    AS combo_addon_item_name,
                created_at, updated_at
            "#,
        )
        .bind(eid)
        .bind(body.org_ingredient_id)
        .bind(&body.ingredient_unit)
        .bind(body.quantity_used)
        .bind(body.replaces_org_ingredient_id)
        .fetch_one(pool.get_ref())
        .await?
    } else {
        sqlx::query_as::<_, AddonOverride>(
            r#"
            INSERT INTO menu_item_addon_overrides
                (menu_item_id, addon_item_id, size_label, ingredient_name,
                 org_ingredient_id, ingredient_unit, quantity_used,
                 replaces_org_ingredient_id, combo_addon_item_id)
            VALUES ($1, $2, $3::item_size, $4, $5, $6, $7, $8, $9)
            RETURNING
                id, menu_item_id, addon_item_id,
                (SELECT name FROM addon_items WHERE id = $2) AS addon_item_name,
                size_label::text,
                ingredient_name, org_ingredient_id, ingredient_unit, quantity_used,
                replaces_org_ingredient_id,
                (SELECT name FROM org_ingredients WHERE id = $8)
                    AS replaces_ingredient_name,
                combo_addon_item_id,
                (SELECT name FROM addon_items WHERE id = $9)
                    AS combo_addon_item_name,
                created_at, updated_at
            "#,
        )
        .bind(*id)
        .bind(body.addon_item_id)
        .bind(&body.size_label)
        .bind(&body.ingredient_name)
        .bind(body.org_ingredient_id)
        .bind(&body.ingredient_unit)
        .bind(body.quantity_used)
        .bind(body.replaces_org_ingredient_id)
        .bind(body.combo_addon_item_id)
        .fetch_one(pool.get_ref())
        .await?
    };

    Ok(HttpResponse::Ok().json(row))
}

pub async fn delete_addon_override(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims                  = extract_claims(&req)?;
    let (item_id, override_id)  = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "delete").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    sqlx::query(
        "DELETE FROM menu_item_addon_overrides WHERE id = $1 AND menu_item_id = $2",
    )
    .bind(override_id)
    .bind(item_id)
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

async fn fetch_category(pool: &PgPool, id: Uuid) -> Result<Category, AppError> {
    sqlx::query_as::<_, Category>(
        "SELECT id, org_id, name, image_url, display_order, is_active,
                created_at, updated_at, deleted_at
         FROM categories
         WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Category not found".into()))
}

async fn fetch_menu_item(pool: &PgPool, id: Uuid) -> Result<MenuItem, AppError> {
    sqlx::query_as::<_, MenuItem>(
        "SELECT id, org_id, category_id, name, description, image_url,
                base_price, is_active, display_order,
                created_at, updated_at, deleted_at
         FROM menu_items
         WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Menu item not found".into()))
}

async fn fetch_addon_item(pool: &PgPool, id: Uuid) -> Result<AddonItem, AppError> {
    sqlx::query_as::<_, AddonItem>(
        "SELECT id, org_id, name, type as addon_type, default_price,
                is_active, display_order, created_at, updated_at
         FROM addon_items
         WHERE id = $1",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Addon item not found".into()))
}

async fn fetch_sizes(pool: &PgPool, item_id: Uuid) -> Result<Vec<ItemSize>, AppError> {
    Ok(sqlx::query_as::<_, ItemSize>(
        "SELECT id, menu_item_id, label::text, price_override, display_order, is_active
         FROM item_sizes
         WHERE menu_item_id = $1
         ORDER BY display_order ASC",
    )
    .bind(item_id)
    .fetch_all(pool)
    .await?)
}

async fn fetch_addon_slots(
    pool:    &PgPool,
    item_id: Uuid,
) -> Result<Vec<AddonSlot>, AppError> {
    Ok(sqlx::query_as::<_, AddonSlot>(
        "SELECT id, menu_item_id, addon_type, label, is_required,
                min_selections, max_selections, display_order, created_at
         FROM menu_item_addon_slots
         WHERE menu_item_id = $1
         ORDER BY display_order ASC",
    )
    .bind(item_id)
    .fetch_all(pool)
    .await?)
}