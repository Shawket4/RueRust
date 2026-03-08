use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    auth::{
        guards::{require_manager, require_org_admin, require_same_org, require_super_admin},
        jwt::Claims,
    },
    errors::AppError,
    models::{User, UserPublic, UserRole},
};

// ── Request types ─────────────────────────────────────────────

#[derive(Deserialize)]
pub struct CreateUserRequest {
    pub org_id:     Uuid,
    pub name:       String,
    pub email:      Option<String>,
    pub phone:      Option<String>,
    pub role:       UserRole,
    pub password:   Option<String>,  // for admins/managers
    pub pin:        Option<String>,  // for tellers (4–6 digits)
    pub branch_ids: Option<Vec<Uuid>>, // branches to assign immediately
}

#[derive(Deserialize)]
pub struct AssignBranchRequest {
    pub branch_id: Uuid,
}

#[derive(Serialize)]
pub struct CreateUserResponse {
    pub user: UserPublic,
}

// ── POST /users  ──────────────────────────────────────────────
// super_admin  → can create any role in any org
// org_admin    → can create managers/tellers in their own org
// branch_manager → can only create tellers in their org

pub async fn create_user(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
    body: web::Json<CreateUserRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;

    // Permission checks
    require_manager(&claims)?;
    require_same_org(&claims, Some(body.org_id))?;

    // branch_managers can only create tellers
    if claims.role == UserRole::BranchManager && body.role != UserRole::Teller {
        return Err(AppError::Forbidden(
            "Branch managers can only create teller accounts".into(),
        ));
    }

    // org_admins cannot create super_admins
    if claims.role == UserRole::OrgAdmin && body.role == UserRole::SuperAdmin {
        return Err(AppError::Forbidden(
            "Only super admins can create super admin accounts".into(),
        ));
    }

    // Validate login method
    match body.role {
        UserRole::Teller => {
            if body.pin.is_none() {
                return Err(AppError::BadRequest("Tellers require a PIN".into()));
            }
            let pin = body.pin.as_deref().unwrap();
            if pin.len() < 4 || pin.len() > 6 || !pin.chars().all(|c| c.is_ascii_digit()) {
                return Err(AppError::BadRequest("PIN must be 4–6 digits".into()));
            }
        }
        _ => {
            if body.password.is_none() {
                return Err(AppError::BadRequest(
                    "Admins and managers require a password".into(),
                ));
            }
            if body.email.is_none() {
                return Err(AppError::BadRequest(
                    "Admins and managers require an email".into(),
                ));
            }
        }
    }

    // Check email uniqueness
    if let Some(email) = &body.email {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1 AND deleted_at IS NULL)"
        )
        .bind(email)
        .fetch_one(pool.get_ref())
        .await?;

        if exists {
            return Err(AppError::Conflict("Email already in use".into()));
        }
    }

    // Hash credentials
    let password_hash = body
        .password
        .as_deref()
        .map(|p| bcrypt::hash(p, bcrypt::DEFAULT_COST))
        .transpose()
        .map_err(|_| AppError::Internal)?;

    let pin_hash = body
        .pin
        .as_deref()
        .map(|p| bcrypt::hash(p, bcrypt::DEFAULT_COST))
        .transpose()
        .map_err(|_| AppError::Internal)?;

    // Insert user
    let user = sqlx::query_as::<_, User>(
        r#"
        INSERT INTO users (org_id, name, email, phone, role, password_hash, pin_hash)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING id, org_id, name, email, phone,
                  password_hash, pin_hash, role,
                  is_active, last_login_at,
                  created_at, updated_at, deleted_at
        "#,
    )
    .bind(body.org_id)
    .bind(&body.name)
    .bind(&body.email)
    .bind(&body.phone)
    .bind(&body.role)
    .bind(password_hash)
    .bind(pin_hash)
    .fetch_one(pool.get_ref())
    .await?;

    // Assign branches if provided
    if let Some(branch_ids) = &body.branch_ids {
        for bid in branch_ids {
            sqlx::query(
                r#"
                INSERT INTO user_branch_assignments (user_id, branch_id, assigned_by)
                VALUES ($1, $2, $3)
                ON CONFLICT DO NOTHING
                "#,
            )
            .bind(user.id)
            .bind(bid)
            .bind(claims.user_id())
            .execute(pool.get_ref())
            .await?;
        }
    }

    Ok(HttpResponse::Created().json(CreateUserResponse { user: user.into() }))
}

// ── GET /users?org_id=  ───────────────────────────────────────

pub async fn list_users(
    req:    HttpRequest,
    pool:   web::Data<PgPool>,
    query:  web::Query<ListUsersQuery>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_org_admin(&claims)?;
    require_same_org(&claims, Some(query.org_id))?;

    let users = sqlx::query_as::<_, User>(
        r#"
        SELECT id, org_id, name, email, phone,
               password_hash, pin_hash, role,
               is_active, last_login_at,
               created_at, updated_at, deleted_at
        FROM users
        WHERE org_id = $1 AND deleted_at IS NULL
        ORDER BY name
        "#,
    )
    .bind(query.org_id)
    .fetch_all(pool.get_ref())
    .await?;

    let public: Vec<UserPublic> = users.into_iter().map(Into::into).collect();
    Ok(HttpResponse::Ok().json(public))
}

#[derive(Deserialize)]
pub struct ListUsersQuery {
    pub org_id: Uuid,
}

// ── GET /users/:id  ───────────────────────────────────────────

pub async fn get_user(
    req:     HttpRequest,
    pool:    web::Data<PgPool>,
    user_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_manager(&claims)?;

    let user = sqlx::query_as::<_, User>(
        r#"
        SELECT id, org_id, name, email, phone,
               password_hash, pin_hash, role,
               is_active, last_login_at,
               created_at, updated_at, deleted_at
        FROM users
        WHERE id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(*user_id)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".into()))?;

    // Non-super-admins can only see users within their own org
    require_same_org(&claims, user.org_id)?;

    Ok(HttpResponse::Ok().json(UserPublic::from(user)))
}

// ── DELETE /users/:id  (soft delete) ─────────────────────────

pub async fn delete_user(
    req:     HttpRequest,
    pool:    web::Data<PgPool>,
    user_id: web::Path<Uuid>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_org_admin(&claims)?;

    // Fetch target user to check org
    let user = sqlx::query_as::<_, User>(
        "SELECT id, org_id, name, email, phone, password_hash, pin_hash, role,
                is_active, last_login_at, created_at, updated_at, deleted_at
         FROM users WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(*user_id)
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".into()))?;

    require_same_org(&claims, user.org_id)?;

    // Cannot delete a super_admin unless you are one
    if user.role == UserRole::SuperAdmin {
        require_super_admin(&claims)?;
    }

    sqlx::query("UPDATE users SET deleted_at = NOW() WHERE id = $1")
        .bind(*user_id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── POST /users/:id/branches  (assign branch) ────────────────

pub async fn assign_branch(
    req:     HttpRequest,
    pool:    web::Data<PgPool>,
    user_id: web::Path<Uuid>,
    body:    web::Json<AssignBranchRequest>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_manager(&claims)?;

    sqlx::query(
        r#"
        INSERT INTO user_branch_assignments (user_id, branch_id, assigned_by)
        VALUES ($1, $2, $3)
        ON CONFLICT DO NOTHING
        "#,
    )
    .bind(*user_id)
    .bind(body.branch_id)
    .bind(claims.user_id())
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── DELETE /users/:id/branches/:branch_id  ───────────────────

pub async fn unassign_branch(
    req:      HttpRequest,
    pool:     web::Data<PgPool>,
    path:     web::Path<(Uuid, Uuid)>,
) -> Result<HttpResponse, AppError> {
    let claims = extract_claims(&req)?;
    require_manager(&claims)?;

    let (user_id, branch_id) = path.into_inner();

    sqlx::query(
        "DELETE FROM user_branch_assignments WHERE user_id = $1 AND branch_id = $2"
    )
    .bind(user_id)
    .bind(branch_id)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::NoContent().finish())
}

// ── Helper ────────────────────────────────────────────────────

fn extract_claims(req: &HttpRequest) -> Result<Claims, AppError> {
    req.extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))
}