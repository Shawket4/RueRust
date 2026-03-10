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

#[derive(Debug, Serialize)]
pub struct MenuItemFull {
    #[serde(flatten)]
    pub item:          MenuItem,
    pub sizes:         Vec<ItemSize>,
    pub option_groups: Vec<DrinkOptionGroupFull>,
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

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct DrinkOptionGroup {
    pub id:             Uuid,
    pub menu_item_id:   Uuid,
    pub group_type:     String,
    pub selection_type: String,
    pub is_required:    bool,
    pub min_selections: i32,
    pub display_order:  i32,
}

#[derive(Debug, Serialize)]
pub struct DrinkOptionGroupFull {
    #[serde(flatten)]
    pub group: DrinkOptionGroup,
    pub items: Vec<DrinkOptionItemFull>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct DrinkOptionItemFull {
    pub id:             Uuid,
    pub group_id:       Uuid,
    pub addon_item_id:  Uuid,
    pub price_override: Option<i32>,
    pub display_order:  i32,
    pub is_active:      bool,
    pub name:           String,
    pub default_price:  i32,
    pub addon_type:     String,
}

#[derive(Deserialize)]
pub struct UpsertSizeRequest {
    pub label:          String,
    pub price_override: i32,
    pub display_order:  Option<i32>,
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
pub struct CreateDrinkOptionGroupRequest {
    pub group_type:     String,
    pub selection_type: Option<String>,
    pub is_required:    Option<bool>,
    pub min_selections: Option<i32>,
    pub display_order:  Option<i32>,
}

#[derive(Deserialize)]
pub struct UpdateDrinkOptionGroupRequest {
    pub selection_type: Option<String>,
    pub is_required:    Option<bool>,
    pub min_selections: Option<i32>,
    pub display_order:  Option<i32>,
}

#[derive(Deserialize)]
pub struct AddDrinkOptionItemRequest {
    pub addon_item_id:  Uuid,
    pub price_override: Option<i32>,
    pub display_order:  Option<i32>,
}

#[derive(Deserialize)]
pub struct UpdateDrinkOptionItemRequest {
    pub price_override: Option<i32>,
    pub display_order:  Option<i32>,
    pub is_active:      Option<bool>,
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

    let rows = match query.category_id {
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

    Ok(HttpResponse::Ok().json(rows))
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

    let option_groups = fetch_option_groups_full(pool.get_ref(), *id).await?;

    Ok(HttpResponse::Ok().json(MenuItemFull { item, sizes, option_groups }))
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
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(MenuItemFull { item, sizes: vec![], option_groups: vec![] }))
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

// ── Drink Option Groups ───────────────────────────────────────

pub async fn list_option_groups(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "read").await?;

    let item = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let groups = fetch_option_groups_full(pool.get_ref(), *id).await?;
    Ok(HttpResponse::Ok().json(groups))
}

pub async fn create_option_group(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<CreateDrinkOptionGroupRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let row = sqlx::query_as::<_, DrinkOptionGroup>(
        r#"
        INSERT INTO drink_option_groups
            (menu_item_id, type, selection_type, is_required, min_selections, display_order)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, menu_item_id, type as group_type, selection_type::text,
                  is_required, min_selections, display_order
        "#,
    )
    .bind(*id)
    .bind(&body.group_type)
    .bind(body.selection_type.as_deref().unwrap_or("multi"))
    .bind(body.is_required.unwrap_or(false))
    .bind(body.min_selections.unwrap_or(0))
    .bind(body.display_order.unwrap_or(0))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(DrinkOptionGroupFull { group: row, items: vec![] }))
}

pub async fn update_option_group(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid)>,
    body: web::Json<UpdateDrinkOptionGroupRequest>,
) -> Result<HttpResponse, AppError> {
    let claims              = extract_claims(&req)?;
    let (item_id, group_id) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let row = sqlx::query_as::<_, DrinkOptionGroup>(
        r#"
        UPDATE drink_option_groups SET
            selection_type = COALESCE($3::addon_selection, selection_type),
            is_required    = COALESCE($4, is_required),
            min_selections = COALESCE($5, min_selections),
            display_order  = COALESCE($6, display_order)
        WHERE id = $1 AND menu_item_id = $2
        RETURNING id, menu_item_id, type as group_type, selection_type::text,
                  is_required, min_selections, display_order
        "#,
    )
    .bind(group_id)
    .bind(item_id)
    .bind(&body.selection_type)
    .bind(body.is_required)
    .bind(body.min_selections)
    .bind(body.display_order)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Option group not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

pub async fn delete_option_group(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims              = extract_claims(&req)?;
    let (item_id, group_id) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "delete").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    sqlx::query(
        "DELETE FROM drink_option_groups WHERE id = $1 AND menu_item_id = $2"
    )
    .bind(group_id)
    .bind(item_id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Drink Option Items ────────────────────────────────────────

pub async fn add_option_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid)>,
    body: web::Json<AddDrinkOptionItemRequest>,
) -> Result<HttpResponse, AppError> {
    let claims              = extract_claims(&req)?;
    let (item_id, group_id) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let row = sqlx::query_as::<_, DrinkOptionItemFull>(
        r#"
        INSERT INTO drink_option_items (group_id, addon_item_id, price_override, display_order)
        VALUES ($1, $2, $3, $4)
        RETURNING
            id, group_id, addon_item_id, price_override, display_order, is_active,
            (SELECT name         FROM addon_items WHERE id = $2) as name,
            (SELECT default_price FROM addon_items WHERE id = $2) as default_price,
            (SELECT type          FROM addon_items WHERE id = $2) as addon_type
        "#,
    )
    .bind(group_id)
    .bind(body.addon_item_id)
    .bind(body.price_override)
    .bind(body.display_order.unwrap_or(0))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(row))
}

pub async fn update_option_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid, Uuid)>,
    body: web::Json<UpdateDrinkOptionItemRequest>,
) -> Result<HttpResponse, AppError> {
    let claims                     = extract_claims(&req)?;
    let (item_id, group_id, oi_id) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "update").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    let row = sqlx::query_as::<_, DrinkOptionItemFull>(
        r#"
        UPDATE drink_option_items SET
            price_override = COALESCE($3, price_override),
            display_order  = COALESCE($4, display_order),
            is_active      = COALESCE($5, is_active)
        WHERE id = $1 AND group_id = $2
        RETURNING
            id, group_id, addon_item_id, price_override, display_order, is_active,
            (SELECT name          FROM addon_items WHERE id = addon_item_id) as name,
            (SELECT default_price FROM addon_items WHERE id = addon_item_id) as default_price,
            (SELECT type          FROM addon_items WHERE id = addon_item_id) as addon_type
        "#,
    )
    .bind(oi_id)
    .bind(group_id)
    .bind(body.price_override)
    .bind(body.display_order)
    .bind(body.is_active)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Option item not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

pub async fn delete_option_item(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<(Uuid, Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims                     = extract_claims(&req)?;
    let (item_id, group_id, oi_id) = path.into_inner();
    check_permission(pool.get_ref(), &claims, "menu_items", "delete").await?;

    let item = fetch_menu_item(pool.get_ref(), item_id).await?;
    require_same_org(&claims, Some(item.org_id))?;

    sqlx::query(
        "DELETE FROM drink_option_items WHERE id = $1 AND group_id = $2"
    )
    .bind(oi_id)
    .bind(group_id)
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
        "#,
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

async fn fetch_option_groups_full(
    pool:    &PgPool,
    item_id: Uuid,
) -> Result<Vec<DrinkOptionGroupFull>, AppError> {
    let groups = sqlx::query_as::<_, DrinkOptionGroup>(
        r#"
        SELECT id, menu_item_id, type as group_type, selection_type::text,
               is_required, min_selections, display_order
        FROM drink_option_groups
        WHERE menu_item_id = $1
        ORDER BY display_order ASC
        "#,
    )
    .bind(item_id)
    .fetch_all(pool)
    .await?;

    let mut result = vec![];
    for g in groups {
        let items = sqlx::query_as::<_, DrinkOptionItemFull>(
            r#"
            SELECT doi.id, doi.group_id, doi.addon_item_id,
                   doi.price_override, doi.display_order, doi.is_active,
                   ai.name, ai.default_price,
                   ai.type as addon_type
            FROM drink_option_items doi
            JOIN addon_items ai ON ai.id = doi.addon_item_id
            WHERE doi.group_id = $1
            ORDER BY doi.display_order ASC
            "#,
        )
        .bind(g.id)
        .fetch_all(pool)
        .await?;

        result.push(DrinkOptionGroupFull { group: g, items });
    }

    Ok(result)
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