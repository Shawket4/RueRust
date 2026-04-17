use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    auth::{guards::require_super_admin, jwt::Claims},
    errors::AppError,
};

// ── Models ────────────────────────────────────────────────────

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct Org {
    pub id:             Uuid,
    pub name:           String,
    pub slug:           String,
    pub logo_url:       Option<String>,
    pub currency_code:  String,
    pub tax_rate:       sqlx::types::BigDecimal,
    pub receipt_footer: Option<String>,
    pub is_active:      bool,
}

// ── Request types ─────────────────────────────────────────────

#[derive(Deserialize)]
pub struct CreateOrgRequest {
    pub name:           String,
    pub slug:           String,
    pub currency_code:  Option<String>,
    pub tax_rate:       Option<f64>,
    pub receipt_footer: Option<String>,
}

#[derive(Deserialize)]
pub struct UpdateOrgRequest {
    pub name:           Option<String>,
    pub slug:           Option<String>,
    pub currency_code:  Option<String>,
    pub tax_rate:       Option<f64>,
    pub receipt_footer: Option<String>,
    pub is_active:      Option<bool>,
}

// ── POST /orgs  (super_admin only) ───────────────────────────

pub async fn create_org(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateOrgRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_super_admin(&claims)?;

    // Check slug uniqueness
    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM organizations WHERE slug = $1)"
    )
    .bind(&body.slug)
    .fetch_one(pool.get_ref())
    .await?;

    if exists {
        return Err(AppError::Conflict(format!("Slug '{}' is already taken", body.slug)));
    }

    let currency = body.currency_code.as_deref().unwrap_or("EGP");
    let tax_rate = body.tax_rate.unwrap_or(0.14);

    let org = sqlx::query_as::<_, Org>(
        r#"
        INSERT INTO organizations (name, slug, currency_code, tax_rate, receipt_footer)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, name, slug, logo_url, currency_code, tax_rate, receipt_footer, is_active
        "#,
    )
    .bind(&body.name)
    .bind(&body.slug)
    .bind(currency)
    .bind(tax_rate)
    .bind(&body.receipt_footer)
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(org))
}

// ── GET /orgs  (super_admin only) ────────────────────────────

pub async fn list_orgs(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_super_admin(&claims)?;

    let orgs = sqlx::query_as::<_, Org>(
        r#"
        SELECT id, name, slug, logo_url, currency_code, tax_rate, receipt_footer, is_active
        FROM organizations
        WHERE deleted_at IS NULL
        ORDER BY name
        "#,
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(orgs))
}

// ── GET /orgs/:id  (super_admin only) ────────────────────────

pub async fn get_org(
    req:     HttpRequest,
    pool:    web::Data<PgPool>,
    org_id:  web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_super_admin(&claims)?;

    let org = sqlx::query_as::<_, Org>(
        r#"
        SELECT id, name, slug, logo_url, currency_code, tax_rate, receipt_footer, is_active
        FROM organizations
        WHERE id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(*org_id)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Org not found".into()))?;

    Ok(HttpResponse::Ok().json(org))
}

// ── PATCH /orgs/:id  (super_admin only) ──────────────────────

pub async fn update_org(
    req:    HttpRequest,
    pool:   web::Data<PgPool>,
    org_id: web::Path<Uuid>,
    body:   web::Json<UpdateOrgRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_super_admin(&claims)?;

    // If slug is provided, check uniqueness against OTHER orgs
    if let Some(slug) = &body.slug {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM organizations WHERE slug = $1 AND id != $2)"
        )
        .bind(slug)
        .bind(*org_id)
        .fetch_one(pool.get_ref())
        .await?;

        if exists {
            return Err(AppError::Conflict(format!("Slug '{}' is already taken", slug)));
        }
    }

    let org = sqlx::query_as::<_, Org>(
        r#"
        UPDATE organizations SET
            name           = COALESCE($2, name),
            slug           = COALESCE($3, slug),
            currency_code  = COALESCE($4, currency_code),
            tax_rate       = COALESCE($5, tax_rate),
            receipt_footer = COALESCE($6, receipt_footer),
            is_active      = COALESCE($7, is_active),
            updated_at     = NOW()
        WHERE id = $1 AND deleted_at IS NULL
        RETURNING id, name, slug, logo_url, currency_code, tax_rate, receipt_footer, is_active
        "#,
    )
    .bind(*org_id)
    .bind(&body.name)
    .bind(&body.slug)
    .bind(&body.currency_code)
    .bind(body.tax_rate)
    .bind(&body.receipt_footer)
    .bind(body.is_active)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Org not found".into()))?;

    Ok(HttpResponse::Ok().json(org))
}

// ── DELETE /orgs/:id  (super_admin only) ─────────────────────

pub async fn delete_org(
    req:    HttpRequest,
    pool:   web::Data<PgPool>,
    org_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_super_admin(&claims)?;

    // Soft delete the organization
    let rows_affected = sqlx::query(
        "UPDATE organizations SET deleted_at = NOW(), is_active = false WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(*org_id)
    .execute(pool.get_ref())
    .await?
    .rows_affected();

    if rows_affected == 0 {
        return Err(AppError::NotFound("Org not found".into()));
    }

    Ok(HttpResponse::NoContent().finish())
}

// ── Helper ────────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}