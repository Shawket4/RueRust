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
pub struct MenuItemAddonSlot {
    pub id:             Uuid,
    pub menu_item_id:   Uuid,
    pub addon_type:     String,
    pub is_required:    bool,
    pub min_selections: i32,
    pub max_selections: Option<i32>,
    pub display_order:  i32,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct MenuItemAddonOverride {
    pub id:             Uuid,
    pub menu_item_id:   Uuid,
    pub addon_item_id:  Uuid,
    pub size_label:     Option<String>,
    pub quantity_used:  sqlx::types::BigDecimal,
}

#[derive(Debug, Serialize)]
pub struct MenuItemFull {
    #[serde(flatten)]
    pub item:            MenuItem,
    pub sizes:           Vec<ItemSize>,
    pub addon_slots:     Vec<MenuItemAddonSlot>,
    pub addon_overrides: Vec<MenuItemAddonOverride>,
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

#[derive(Deserialize)]
pub struct UpsertSizeRequest {
    pub label:          String,
    pub price_override: i32,
    pub display_order:  Option<i32>,
}

#[derive(Deserialize)]
pub struct CreateAddonSlotRequest {
    pub addon_type:     String,
    pub is_required:    Option<bool>,
    pub min_selections: Option<i32>,
    pub max_selections: Option<i32>,
    pub display_order:  Option<i32>,
}

#[derive(Deserialize)]
pub struct UpdateAddonSlotRequest {
    pub is_required:    Option<bool>,
    pub min_selections: Option<i32>,
    pub max_selections: Option<i32>,
    pub display_order:  Option<i32>,
}

#[derive(Deserialize)]
pub struct UpsertAddonOverrideRequest {
    pub addon_item_id: Uuid,
    pub size_label:    Option<String>,
    pub quantity_used: f64,
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
        r#"
        SELECT id, org_id, name, image_url, display_order, is_active,
               created_at, updated_at, deleted_at
        FROM categories
        WHERE org_id = $1 AND deleted_at IS NULL
        ORDER BY display_order ASC, name ASC
        "#,
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
        r#"
        INSERT INTO categories (org_id, name, image_url, display_order)
        VALUES ($1, $2, $3, $4)
        RETURNING id, org_id, name, image_url, display_order, is_active,
                  created_at, updated_at, deleted_at
        "#,
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
        r#"
        UPDATE categories SET
            name          = COALESCE($2, name),
            image_url     = COALESCE($3, image_url),
            display_order = COALESCE($4, display_order),
            is_active     = COALESCE($5, is_active)
        WHERE id = $1 AND deleted_at IS NULL
        RETURNING id, org_id, name, image_url, display_order, is_active,
                  created_at, updated_at, deleted_at
        "#,
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
        "UPDATE categories SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL"
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
            r#"
            SELECT id, org_id, category_id, name, description, image_url,
                   base_price, is_active, display_order,
                   created_at, updated_at, deleted_at
            FROM menu_items
            WHERE org_id = $1 AND deleted_at IS NULL AND category_id = $2
            ORDER BY display_order ASC, name ASC
            "#,
        )
        .bind(query.org_id)
        .bind(cat_id)
        .fetch_all(pool.get_ref())
        .await?,

        None => sqlx::query_as::<_, MenuItem>(
            r#"
            SELECT id, org_id, category_id, name, description, image_url,
                   base_price, is_active, display_order,
                   created_at, updated_at, deleted_at
            FROM menu_items
            WHERE org_id = $1 AND deleted_at IS NULL
            ORDER BY display_order ASC, name ASC
            "#,
        )
        .bind(query.org_id)
        .fetch_all(pool.get_ref())
        .await?,
    };

    // If ?full=true, hydrate each item with sizes + option groups
    if query.full.unwrap_or(false) {
        let mut result: Vec<MenuItemFull> = vec![];
        for item in items {
            let sizes = sqlx::query_as::<_, ItemSize>(
                r#"
                SELECT id, menu_item_id, label::text, price_override,
                       display_order, is_active
                FROM item_sizes
                WHERE menu_item_id = $1
                ORDER BY display_order ASC
                "#,
            )
            .bind(item.id)
            .fetch_all(pool.get_ref())
            .await?;

            let addon_slots = sqlx::query_as::<_, MenuItemAddonSlot>(
                r#"
                SELECT id, menu_item_id, addon_type, is_required,
                       min_selections, max_selections, display_order
                FROM menu_item_addon_slots
                WHERE menu_item_id = $1
                ORDER BY display_order ASC
                "#,
            )
            .bind(item.id)
            .fetch_all(pool.get_ref())
            .await?;

            let addon_overrides = sqlx::query_as::<_, MenuItemAddonOverride>(
                r#"
                SELECT id, menu_item_id, addon_item_id, size_label::text, quantity_used
                FROM menu_item_addon_overrides
                WHERE menu_item_id = $1
                "#,
            )
            .bind(item.id)
            .fetch_all(pool.get_ref())
            .await?;

            result.push(MenuItemFull { item, sizes, addon_slots, addon_overrides });
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

    let sizes = sqlx::query_as::<_, ItemSize>(
        r#"
        SELECT id, menu_item_id, label::text, price_override, display_order, is_active
        FROM item_sizes
        WHERE menu_item_id = $1
        ORDER BY display_order ASC
        "#,
    )
    .bind(*id)
    .fetch_all(pool.get_ref())
    .await?;

    let addon_slots = sqlx::query_as::<_, MenuItemAddonSlot>(
        r#"
        SELECT id, menu_item_id, addon_type, is_required,
               min_selections, max_selections, display_order
        FROM menu_item_addon_slots
        WHERE menu_item_id = $1
        ORDER BY display_order ASC
        "#,
    )
    .bind(*id)
    .fetch_all(pool.get_ref())
    .await?;

    let addon_overrides = sqlx::query_as::<_, MenuItemAddonOverride>(
        r#"
        SELECT id, menu_item_id, addon_item_id, size_label::text, quantity_used
        FROM menu_item_addon_overrides
        WHERE menu_item_id = $1
        "#,
    )
    .bind(*id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(MenuItemFull { item, sizes, addon_slots, addon_overrides }))
}

pub async fn create_menu_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateMenuItemRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "create").await?;
    require_same_org(&claims, Some(body.org_id))?;

    let mut tx = pool.begin().await?;

    let item = sqlx::query_as::<_, MenuItem>(
        r#"
        INSERT INTO menu_items (org_id, category_id, name, description, image_url, base_price, display_order)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING id, org_id, category_id, name, description, image_url,
                  base_price, is_active, display_order,
                  created_at, updated_at, deleted_at
        "#,
    )
    .bind(body.org_id)
    .bind(body.category_id)
    .bind(&body.name)
    .bind(&body.description)
    .bind(&body.image_url)
    .bind(body.base_price)
    .bind(body.display_order.unwrap_or(0))
    .fetch_one(&mut *tx)
    .await?;

    tx.commit().await?;

    Ok(HttpResponse::Created().json(MenuItemFull { item, sizes: vec![], addon_slots: vec![], addon_overrides: vec![] }))
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
        r#"
        UPDATE menu_items SET
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
                  created_at, updated_at, deleted_at
        "#,
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
        "UPDATE menu_items SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(*id)
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
            r#"
            SELECT id, org_id, name, type as addon_type, default_price,
                   is_active, display_order, created_at, updated_at
            FROM addon_items
            WHERE org_id = $1 AND type = $2
            ORDER BY type ASC, display_order ASC
            "#,
        )
        .bind(query.org_id)
        .bind(t)
        .fetch_all(pool.get_ref())
        .await?,

        None => sqlx::query_as::<_, AddonItem>(
            r#"
            SELECT id, org_id, name, type as addon_type, default_price,
                   is_active, display_order, created_at, updated_at
            FROM addon_items
            WHERE org_id = $1
            ORDER BY type ASC, display_order ASC
            "#,
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
        r#"
        INSERT INTO addon_items (org_id, name, type, default_price, display_order)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, org_id, name, type as addon_type, default_price,
                  is_active, display_order, created_at, updated_at
        "#,
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
        r#"
        UPDATE addon_items SET
            name          = COALESCE($2, name),
            type          = COALESCE($3, type),
            default_price = COALESCE($4, default_price),
            display_order = COALESCE($5, display_order),
            is_active     = COALESCE($6, is_active)
        WHERE id = $1
        RETURNING id, org_id, name, type as addon_type, default_price,
                  is_active, display_order, created_at, updated_at
        "#,
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

    let row = sqlx::query_as::<_, MenuItemAddonSlot>(
        r#"
        INSERT INTO menu_item_addon_slots (menu_item_id, addon_type, is_required, min_selections, max_selections, display_order)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (menu_item_id, addon_type) DO UPDATE SET
            is_required    = EXCLUDED.is_required,
            min_selections = EXCLUDED.min_selections,
            max_selections = EXCLUDED.max_selections,
            display_order  = EXCLUDED.display_order
        RETURNING id, menu_item_id, addon_type, is_required, min_selections, max_selections, display_order
        "#,
    )
    .bind(*id)
    .bind(&body.addon_type)
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
    let claims = extract_claims(&req)?;
    let (item_id, slot_id) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let row = sqlx::query_as::<_, MenuItemAddonSlot>(
        r#"
        UPDATE menu_item_addon_slots SET
            is_required    = COALESCE($3, is_required),
            min_selections = COALESCE($4, min_selections),
            max_selections = COALESCE($5, max_selections),
            display_order  = COALESCE($6, display_order)
        WHERE id = $1 AND menu_item_id = $2
        RETURNING id, menu_item_id, addon_type, is_required, min_selections, max_selections, display_order
        "#,
    )
    .bind(slot_id)
    .bind(item_id)
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
    let claims = extract_claims(&req)?;
    let (item_id, slot_id) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    sqlx::query("DELETE FROM menu_item_addon_slots WHERE id = $1 AND menu_item_id = $2")
        .bind(slot_id)
        .bind(item_id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Addon Overrides ───────────────────────────────────────────

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

    let qty = sqlx::types::BigDecimal::try_from(body.quantity_used)
        .map_err(|_| AppError::BadRequest("Invalid quantity".into()))?;

    // If size_label is missing (NULL), handled by unique constraints.
    // PostgreSQL treats multiple NULLs as unique if not careful, but the override relies on size.
    let row = sqlx::query_as::<_, MenuItemAddonOverride>(
        r#"
        INSERT INTO menu_item_addon_overrides (menu_item_id, addon_item_id, size_label, quantity_used)
        VALUES ($1, $2, $3::item_size, $4)
        ON CONFLICT (menu_item_id, addon_item_id, size_label) DO UPDATE SET
            quantity_used = EXCLUDED.quantity_used
        RETURNING id, menu_item_id, addon_item_id, size_label::text, quantity_used
        "#,
    )
    .bind(*id)
    .bind(body.addon_item_id)
    .bind(&body.size_label)
    .bind(qty)
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(row))
}

pub async fn delete_addon_override(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    let (item_id, override_id) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    sqlx::query("DELETE FROM menu_item_addon_overrides WHERE id = $1 AND menu_item_id = $2")
        .bind(override_id)
        .bind(item_id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::NoContent().finish())
}

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
        r#"
        INSERT INTO item_sizes (menu_item_id, label, price_override, display_order)
        VALUES ($1, $2::item_size, $3, $4)
        ON CONFLICT (menu_item_id, label) DO UPDATE SET
            price_override = EXCLUDED.price_override,
            display_order  = EXCLUDED.display_order,
            is_active      = TRUE
        RETURNING id, menu_item_id, label::text, price_override, display_order, is_active
        "#,
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

// ── Helpers ───────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_category(pool: &PgPool, id: Uuid) -> Result<Category, AppError> {
    sqlx::query_as::<_, Category>(
        r#"
        SELECT id, org_id, name, image_url, display_order, is_active,
               created_at, updated_at, deleted_at
        FROM categories
        WHERE id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Category not found".into()))
}

async fn fetch_menu_item(pool: &PgPool, id: Uuid) -> Result<MenuItem, AppError> {
    sqlx::query_as::<_, MenuItem>(
        r#"
        SELECT id, org_id, category_id, name, description, image_url,
               base_price, is_active, display_order,
               created_at, updated_at, deleted_at
        FROM menu_items
        WHERE id = $1 AND deleted_at IS NULL
        "#
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Menu item not found".into()))
}

async fn fetch_addon_item(pool: &PgPool, id: Uuid) -> Result<AddonItem, AppError> {
    sqlx::query_as::<_, AddonItem>(
        r#"
        SELECT id, org_id, name, type as addon_type, default_price,
               is_active, display_order, created_at, updated_at
        FROM addon_items
        WHERE id = $1
        "#,
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Addon item not found".into()))
}