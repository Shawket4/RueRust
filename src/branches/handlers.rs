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

#[derive(Debug, Serialize, Deserialize, sqlx::Type, Clone, PartialEq)]
#[sqlx(type_name = "printer_brand", rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum PrinterBrand {
    Star,
    Epson,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Branch {
    pub id:            Uuid,
    pub org_id:        Uuid,
    pub name:          String,
    pub address:       Option<String>,
    pub phone:         Option<String>,
    pub timezone:      String,
    pub printer_brand: Option<PrinterBrand>,
    pub printer_ip:    Option<String>,
    pub printer_port:  Option<i32>,
    pub is_active:     bool,
    pub created_at:    DateTime<Utc>,
    pub updated_at:    DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct ListBranchesQuery {
    pub org_id: Uuid,
}

#[derive(Deserialize)]
pub struct CreateBranchRequest {
    pub org_id:        Uuid,
    pub name:          String,
    pub address:       Option<String>,
    pub phone:         Option<String>,
    pub timezone:      Option<String>,
    pub printer_brand: Option<PrinterBrand>,
    pub printer_ip:    Option<String>,
    pub printer_port:  Option<i32>,
}

#[derive(Deserialize)]
pub struct UpdateBranchRequest {
    pub name:          Option<String>,
    pub address:       Option<String>,
    pub phone:         Option<String>,
    pub timezone:      Option<String>,
    pub printer_brand: Option<PrinterBrand>,
    pub printer_ip:    Option<String>,
    pub printer_port:  Option<i32>,
    pub is_active:     Option<bool>,
}

pub async fn list_branches(
    req:   HttpRequest,
    pool:  web::Data<PgPool>,
    query: web::Query<ListBranchesQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "read").await?;
    require_same_org(&claims, Some(query.org_id))?;

    let branches = sqlx::query_as::<_, Branch>(
        r#"
        SELECT id, org_id, name, address, phone, timezone,
               printer_brand, printer_ip::text, printer_port,
               is_active, created_at, updated_at
        FROM branches
        WHERE org_id = $1 AND deleted_at IS NULL
        ORDER BY name
        "#,
    )
    .bind(query.org_id)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(branches))
}

pub async fn get_branch(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "read").await?;

    let branch = fetch_branch(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(branch.org_id))?;

    Ok(HttpResponse::Ok().json(branch))
}

pub async fn create_branch(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateBranchRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "create").await?;
    require_same_org(&claims, Some(body.org_id))?;

    let branch = sqlx::query_as::<_, Branch>(
        r#"
        INSERT INTO branches (org_id, name, address, phone, timezone, printer_brand, printer_ip, printer_port)
        VALUES ($1, $2, $3, $4, $5, $6, $7::inet, $8)
        RETURNING id, org_id, name, address, phone, timezone,
                  printer_brand, printer_ip::text, printer_port,
                  is_active, created_at, updated_at
        "#,
    )
    .bind(body.org_id)
    .bind(&body.name)
    .bind(&body.address)
    .bind(&body.phone)
    .bind(body.timezone.as_deref().unwrap_or("Africa/Cairo"))
    .bind(&body.printer_brand)
    .bind(&body.printer_ip)
    .bind(body.printer_port.unwrap_or(9100))
    .fetch_one(pool.get_ref())
    .await?;

    Ok(HttpResponse::Created().json(branch))
}

pub async fn update_branch(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
    body: web::Json<UpdateBranchRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "update").await?;

    let existing = fetch_branch(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    let branch = sqlx::query_as::<_, Branch>(
        r#"
        UPDATE branches SET
            name          = COALESCE($2, name),
            address       = COALESCE($3, address),
            phone         = COALESCE($4, phone),
            timezone      = COALESCE($5, timezone),
            printer_brand = COALESCE($6, printer_brand),
            printer_ip    = COALESCE($7::inet, printer_ip),
            printer_port  = COALESCE($8, printer_port),
            is_active     = COALESCE($9, is_active)
        WHERE id = $1 AND deleted_at IS NULL
        RETURNING id, org_id, name, address, phone, timezone,
                  printer_brand, printer_ip::text, printer_port,
                  is_active, created_at, updated_at
        "#,
    )
    .bind(*id)
    .bind(&body.name)
    .bind(&body.address)
    .bind(&body.phone)
    .bind(&body.timezone)
    .bind(&body.printer_brand)
    .bind(&body.printer_ip)
    .bind(body.printer_port)
    .bind(body.is_active)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("Branch not found".into()))?;

    Ok(HttpResponse::Ok().json(branch))
}

pub async fn delete_branch(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    id:   web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    check_permission(pool.get_ref(), &claims, "branches", "delete").await?;

    let existing = fetch_branch(pool.get_ref(), *id).await?;
    require_same_org(&claims, Some(existing.org_id))?;

    sqlx::query(
        "UPDATE branches SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(*id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}

async fn fetch_branch(pool: &PgPool, id: Uuid) -> Result<Branch, AppError> {
    sqlx::query_as::<_, Branch>(
        r#"
        SELECT id, org_id, name, address, phone, timezone,
               printer_brand, printer_ip::text, printer_port,
               is_active, created_at, updated_at
        FROM branches
        WHERE id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Branch not found".into()))
}