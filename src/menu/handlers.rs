use actix_web::{delete, get, patch, post, web, HttpResponse};
use sqlx::PgPool;
use uuid::Uuid;

use crate::auth::jwt::Claims;
use crate::errors::AppError;
use super::models::*;

// ── Categories ────────────────────────────────────────────────

#[get("/categories")]
pub async fn list_categories(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;

    let rows = sqlx::query_as!(
        Category,
        r#"SELECT id, org_id, name, image_url, display_order, is_active,
                  created_at, updated_at, deleted_at
           FROM categories
           WHERE org_id = $1 AND deleted_at IS NULL
           ORDER BY display_order ASC, name ASC"#,
        org_id
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

#[post("/categories")]
pub async fn create_category(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    body:   web::Json<CreateCategoryRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let order  = body.display_order.unwrap_or(0);

    let row = sqlx::query_as!(
        Category,
        r#"INSERT INTO categories (org_id, name, image_url, display_order)
           VALUES ($1, $2, $3, $4)
           RETURNING id, org_id, name, image_url, display_order, is_active,
                     created_at, updated_at, deleted_at"#,
        org_id,
        body.name,
        body.image_url,
        order,
    )
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(row))
}

#[patch("/categories/{id}")]
pub async fn update_category(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<Uuid>,
    body:   web::Json<UpdateCategoryRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let id     = path.into_inner();

    let row = sqlx::query_as!(
        Category,
        r#"UPDATE categories
           SET name          = COALESCE($1, name),
               image_url     = COALESCE($2, image_url),
               display_order = COALESCE($3, display_order),
               is_active     = COALESCE($4, is_active)
           WHERE id = $5 AND org_id = $6 AND deleted_at IS NULL
           RETURNING id, org_id, name, image_url, display_order, is_active,
                     created_at, updated_at, deleted_at"#,
        body.name,
        body.image_url,
        body.display_order,
        body.is_active,
        id,
        org_id,
    )
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Category not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

#[delete("/categories/{id}")]
pub async fn delete_category(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let id     = path.into_inner();

    let affected = sqlx::query!(
        "UPDATE categories SET deleted_at = NOW()
         WHERE id = $1 AND org_id = $2 AND deleted_at IS NULL",
        id, org_id
    )
    .execute(pool.get_ref())
    .await?
    .rows_affected();

    if affected == 0 {
        return Err(AppError::NotFound("Category not found".into()));
    }

    Ok(HttpResponse::NoContent().finish())
}

// ── Menu Items ────────────────────────────────────────────────

#[get("/menu-items")]
pub async fn list_menu_items(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    query:  web::Query<MenuItemQuery>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;

    let rows = sqlx::query_as!(
        MenuItem,
        r#"SELECT id, org_id, category_id, name, description, image_url,
                  base_price, is_active, display_order,
                  created_at, updated_at, deleted_at
           FROM menu_items
           WHERE org_id = $1
             AND deleted_at IS NULL
             AND ($2::uuid IS NULL OR category_id = $2)
           ORDER BY display_order ASC, name ASC"#,
        org_id,
        query.category_id as Option<Uuid>,
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

#[get("/menu-items/{id}")]
pub async fn get_menu_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let id     = path.into_inner();

    let item = sqlx::query_as!(
        MenuItem,
        r#"SELECT id, org_id, category_id, name, description, image_url,
                  base_price, is_active, display_order,
                  created_at, updated_at, deleted_at
           FROM menu_items
           WHERE id = $1 AND org_id = $2 AND deleted_at IS NULL"#,
        id, org_id
    )
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Menu item not found".into()))?;

    let sizes = sqlx::query_as!(
        ItemSizeRow,
        r#"SELECT id, menu_item_id, label AS "label: ItemSize",
                  price_override, display_order, is_active
           FROM item_sizes
           WHERE menu_item_id = $1
           ORDER BY display_order ASC"#,
        id
    )
    .fetch_all(pool.get_ref())
    .await?;

    let groups = fetch_option_groups_full(pool.get_ref(), id).await?;

    Ok(HttpResponse::Ok().json(MenuItemFull { item, sizes, option_groups: groups }))
}

#[post("/menu-items")]
pub async fn create_menu_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    body:   web::Json<CreateMenuItemRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let order  = body.display_order.unwrap_or(0);

    let mut tx = pool.begin().await?;

    let item = sqlx::query_as!(
        MenuItem,
        r#"INSERT INTO menu_items (org_id, category_id, name, description, image_url, base_price, display_order)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING id, org_id, category_id, name, description, image_url,
                     base_price, is_active, display_order,
                     created_at, updated_at, deleted_at"#,
        org_id,
        body.category_id,
        body.name,
        body.description,
        body.image_url,
        body.base_price,
        order,
    )
    .fetch_one(&mut *tx)
    .await?;

    let mut sizes = vec![];
    if let Some(size_list) = &body.sizes {
        for s in size_list {
            let row = sqlx::query_as!(
                ItemSizeRow,
                r#"INSERT INTO item_sizes (menu_item_id, label, price_override, display_order)
                   VALUES ($1, $2, $3, $4)
                   RETURNING id, menu_item_id, label AS "label: ItemSize",
                             price_override, display_order, is_active"#,
                item.id,
                s.label as ItemSize,
                s.price_override,
                s.display_order.unwrap_or(0),
            )
            .fetch_one(&mut *tx)
            .await?;
            sizes.push(row);
        }
    }

    tx.commit().await?;

    Ok(HttpResponse::Created().json(MenuItemFull {
        item,
        sizes,
        option_groups: vec![],
    }))
}

#[patch("/menu-items/{id}")]
pub async fn update_menu_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<Uuid>,
    body:   web::Json<UpdateMenuItemRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let id     = path.into_inner();

    let item = sqlx::query_as!(
        MenuItem,
        r#"UPDATE menu_items
           SET category_id   = COALESCE($1, category_id),
               name          = COALESCE($2, name),
               description   = COALESCE($3, description),
               image_url     = COALESCE($4, image_url),
               base_price    = COALESCE($5, base_price),
               display_order = COALESCE($6, display_order),
               is_active     = COALESCE($7, is_active)
           WHERE id = $8 AND org_id = $9 AND deleted_at IS NULL
           RETURNING id, org_id, category_id, name, description, image_url,
                     base_price, is_active, display_order,
                     created_at, updated_at, deleted_at"#,
        body.category_id as Option<Uuid>,
        body.name,
        body.description,
        body.image_url,
        body.base_price,
        body.display_order,
        body.is_active,
        id,
        org_id,
    )
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Menu item not found".into()))?;

    Ok(HttpResponse::Ok().json(item))
}

#[delete("/menu-items/{id}")]
pub async fn delete_menu_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let id     = path.into_inner();

    let affected = sqlx::query!(
        "UPDATE menu_items SET deleted_at = NOW()
         WHERE id = $1 AND org_id = $2 AND deleted_at IS NULL",
        id, org_id
    )
    .execute(pool.get_ref())
    .await?
    .rows_affected();

    if affected == 0 {
        return Err(AppError::NotFound("Menu item not found".into()));
    }

    Ok(HttpResponse::NoContent().finish())
}

// ── Addon Items ───────────────────────────────────────────────

#[get("/addon-items")]
pub async fn list_addon_items(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    query:  web::Query<AddonItemQuery>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;

    let rows = sqlx::query_as!(
        AddonItem,
        r#"SELECT id, org_id, name, type AS addon_type, default_price,
                  is_active, display_order, created_at, updated_at
           FROM addon_items
           WHERE org_id = $1
             AND ($2::text IS NULL OR type = $2)
           ORDER BY type ASC, display_order ASC"#,
        org_id,
        query.addon_type,
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(rows))
}

#[post("/addon-items")]
pub async fn create_addon_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    body:   web::Json<CreateAddonItemRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let order  = body.display_order.unwrap_or(0);

    let row = sqlx::query_as!(
        AddonItem,
        r#"INSERT INTO addon_items (org_id, name, type, default_price, display_order)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING id, org_id, name, type AS addon_type, default_price,
                     is_active, display_order, created_at, updated_at"#,
        org_id,
        body.name,
        body.addon_type,
        body.default_price,
        order,
    )
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(row))
}

#[patch("/addon-items/{id}")]
pub async fn update_addon_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<Uuid>,
    body:   web::Json<UpdateAddonItemRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let id     = path.into_inner();

    let row = sqlx::query_as!(
        AddonItem,
        r#"UPDATE addon_items
           SET name          = COALESCE($1, name),
               type          = COALESCE($2, type),
               default_price = COALESCE($3, default_price),
               display_order = COALESCE($4, display_order),
               is_active     = COALESCE($5, is_active)
           WHERE id = $6 AND org_id = $7
           RETURNING id, org_id, name, type AS addon_type, default_price,
                     is_active, display_order, created_at, updated_at"#,
        body.name,
        body.addon_type,
        body.default_price,
        body.display_order,
        body.is_active,
        id,
        org_id,
    )
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Addon item not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

#[delete("/addon-items/{id}")]
pub async fn delete_addon_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let org_id = claims.org_id;
    let id     = path.into_inner();

    let affected = sqlx::query!(
        "DELETE FROM addon_items WHERE id = $1 AND org_id = $2",
        id, org_id
    )
    .execute(pool.get_ref())
    .await?
    .rows_affected();

    if affected == 0 {
        return Err(AppError::NotFound("Addon item not found".into()));
    }

    Ok(HttpResponse::NoContent().finish())
}

// ── Drink Option Groups ───────────────────────────────────────

#[get("/menu-items/{id}/option-groups")]
pub async fn list_option_groups(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let org_id  = claims.org_id;
    let item_id = path.into_inner();

    // verify item belongs to this org
    let exists = sqlx::query_scalar!(
        "SELECT EXISTS(SELECT 1 FROM menu_items WHERE id = $1 AND org_id = $2 AND deleted_at IS NULL)",
        item_id, org_id
    )
    .fetch_one(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !exists {
        return Err(AppError::NotFound("Menu item not found".into()));
    }

    let groups = fetch_option_groups_full(pool.get_ref(), item_id).await?;
    Ok(HttpResponse::Ok().json(groups))
}

#[post("/menu-items/{id}/option-groups")]
pub async fn create_option_group(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<Uuid>,
    body:   web::Json<CreateDrinkOptionGroupRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id  = claims.org_id;
    let item_id = path.into_inner();

    let exists = sqlx::query_scalar!(
        "SELECT EXISTS(SELECT 1 FROM menu_items WHERE id = $1 AND org_id = $2 AND deleted_at IS NULL)",
        item_id, org_id
    )
    .fetch_one(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !exists {
        return Err(AppError::NotFound("Menu item not found".into()));
    }

    let row = sqlx::query_as!(
        DrinkOptionGroup,
        r#"INSERT INTO drink_option_groups
               (menu_item_id, type, selection_type, is_required, min_selections, display_order)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id, menu_item_id,
                     type AS group_type,
                     selection_type AS "selection_type: AddonSelection",
                     is_required, min_selections, display_order"#,
        item_id,
        body.group_type,
        body.selection_type as AddonSelection,
        body.is_required.unwrap_or(false),
        body.min_selections.unwrap_or(0),
        body.display_order.unwrap_or(0),
    )
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(DrinkOptionGroupFull { group: row, items: vec![] }))
}

#[patch("/menu-items/{item_id}/option-groups/{group_id}")]
pub async fn update_option_group(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<(Uuid, Uuid)>,
    body:   web::Json<UpdateDrinkOptionGroupRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id           = claims.org_id;
    let (item_id, group_id) = path.into_inner();

    // verify ownership via menu_item
    let exists = sqlx::query_scalar!(
        "SELECT EXISTS(SELECT 1 FROM menu_items WHERE id = $1 AND org_id = $2 AND deleted_at IS NULL)",
        item_id, org_id
    )
    .fetch_one(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !exists {
        return Err(AppError::NotFound("Menu item not found".into()));
    }

    let row = sqlx::query_as!(
        DrinkOptionGroup,
        r#"UPDATE drink_option_groups
           SET selection_type = COALESCE($1, selection_type),
               is_required    = COALESCE($2, is_required),
               min_selections = COALESCE($3, min_selections),
               display_order  = COALESCE($4, display_order)
           WHERE id = $5 AND menu_item_id = $6
           RETURNING id, menu_item_id,
                     type AS group_type,
                     selection_type AS "selection_type: AddonSelection",
                     is_required, min_selections, display_order"#,
        body.selection_type as Option<AddonSelection>,
        body.is_required,
        body.min_selections,
        body.display_order,
        group_id,
        item_id,
    )
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Option group not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

#[delete("/menu-items/{item_id}/option-groups/{group_id}")]
pub async fn delete_option_group(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<(Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let org_id              = claims.org_id;
    let (item_id, group_id) = path.into_inner();

    let exists = sqlx::query_scalar!(
        "SELECT EXISTS(SELECT 1 FROM menu_items WHERE id = $1 AND org_id = $2 AND deleted_at IS NULL)",
        item_id, org_id
    )
    .fetch_one(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !exists {
        return Err(AppError::NotFound("Menu item not found".into()));
    }

    sqlx::query!(
        "DELETE FROM drink_option_groups WHERE id = $1 AND menu_item_id = $2",
        group_id, item_id
    )
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Drink Option Items ────────────────────────────────────────

#[post("/menu-items/{item_id}/option-groups/{group_id}/items")]
pub async fn add_option_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<(Uuid, Uuid)>,
    body:   web::Json<AddDrinkOptionItemRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id              = claims.org_id;
    let (item_id, group_id) = path.into_inner();

    // verify ownership
    let exists = sqlx::query_scalar!(
        "SELECT EXISTS(
            SELECT 1 FROM drink_option_groups g
            JOIN menu_items m ON m.id = g.menu_item_id
            WHERE g.id = $1 AND g.menu_item_id = $2 AND m.org_id = $3
        )",
        group_id, item_id, org_id
    )
    .fetch_one(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !exists {
        return Err(AppError::NotFound("Option group not found".into()));
    }

    let row = sqlx::query_as!(
        DrinkOptionItem,
        r#"INSERT INTO drink_option_items (group_id, addon_item_id, price_override, display_order)
           VALUES ($1, $2, $3, $4)
           RETURNING id, group_id, addon_item_id, price_override, display_order, is_active"#,
        group_id,
        body.addon_item_id,
        body.price_override,
        body.display_order.unwrap_or(0),
    )
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(row))
}

#[patch("/menu-items/{item_id}/option-groups/{group_id}/items/{oi_id}")]
pub async fn update_option_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<(Uuid, Uuid, Uuid)>,
    body:   web::Json<UpdateDrinkOptionItemRequest>,
) -> Result<HttpResponse, AppError> {
    let org_id                    = claims.org_id;
    let (item_id, group_id, oi_id) = path.into_inner();

    let exists = sqlx::query_scalar!(
        "SELECT EXISTS(
            SELECT 1 FROM drink_option_groups g
            JOIN menu_items m ON m.id = g.menu_item_id
            WHERE g.id = $1 AND g.menu_item_id = $2 AND m.org_id = $3
        )",
        group_id, item_id, org_id
    )
    .fetch_one(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !exists {
        return Err(AppError::NotFound("Option group not found".into()));
    }

    let row = sqlx::query_as!(
        DrinkOptionItem,
        r#"UPDATE drink_option_items
           SET price_override = COALESCE($1, price_override),
               display_order  = COALESCE($2, display_order),
               is_active      = COALESCE($3, is_active)
           WHERE id = $4 AND group_id = $5
           RETURNING id, group_id, addon_item_id, price_override, display_order, is_active"#,
        body.price_override,
        body.display_order,
        body.is_active,
        oi_id,
        group_id,
    )
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Option item not found".into()))?;

    Ok(HttpResponse::Ok().json(row))
}

#[delete("/menu-items/{item_id}/option-groups/{group_id}/items/{oi_id}")]
pub async fn delete_option_item(
    claims: web::ReqData<Claims>,
    pool:   web::Data<PgPool>,
    path:   web::Path<(Uuid, Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let _org_id                    = claims.org_id;
    let (_item_id, group_id, oi_id) = path.into_inner();

    sqlx::query!(
        "DELETE FROM drink_option_items WHERE id = $1 AND group_id = $2",
        oi_id, group_id
    )
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Helper ────────────────────────────────────────────────────

async fn fetch_option_groups_full(
    pool:    &PgPool,
    item_id: Uuid,
) -> Result<Vec<DrinkOptionGroupFull>, AppError> {
    let groups = sqlx::query_as!(
        DrinkOptionGroup,
        r#"SELECT id, menu_item_id,
                  type AS group_type,
                  selection_type AS "selection_type: AddonSelection",
                  is_required, min_selections, display_order
           FROM drink_option_groups
           WHERE menu_item_id = $1
           ORDER BY display_order ASC"#,
        item_id
    )
    .fetch_all(pool)
    .await?;

    let mut result = vec![];
    for g in groups {
        let items = sqlx::query_as!(
            DrinkOptionItemFull,
            r#"SELECT doi.id, doi.group_id, doi.addon_item_id,
                      doi.price_override, doi.display_order, doi.is_active,
                      ai.name, ai.default_price,
                      ai.type AS addon_type
               FROM drink_option_items doi
               JOIN addon_items ai ON ai.id = doi.addon_item_id
               WHERE doi.group_id = $1
               ORDER BY doi.display_order ASC"#,
            g.id
        )
        .fetch_all(pool)
        .await?;

        result.push(DrinkOptionGroupFull { group: g, items });
    }

    Ok(result)
}