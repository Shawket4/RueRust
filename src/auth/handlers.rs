use actix_web::{web, HttpMessage, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    auth::jwt::{create_token, Claims, JwtSecret},
    errors::AppError,
    models::{User, UserPublic, UserRole},
};

// ── Request / Response types ─────────────────────────────────

#[derive(Deserialize)]
pub struct LoginRequest {
    pub org_id:    Uuid,
    pub email:     Option<String>,
    pub password:  Option<String>, // for managers/admins
    pub pin:       Option<String>, // for tellers
    pub branch_id: Option<Uuid>,
}

#[derive(Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub user:  UserPublic,
}

#[derive(Serialize)]
pub struct MeResponse {
    pub user: UserPublic,
}

// ── POST /auth/login ─────────────────────────────────────────

pub async fn login(
    pool:   web::Data<PgPool>,
    secret: web::Data<JwtSecret>,
    body:   web::Json<LoginRequest>,
) -> Result<HttpResponse, AppError> {

    let user: User = match (&body.email, &body.pin) {

        // Email + password login (org_admin, branch_manager, super_admin)
        (Some(email), None) => {
            let password = body.password.as_deref().ok_or_else(|| {
                AppError::BadRequest("password is required for email login".into())
            })?;

            let u = sqlx::query_as::<_, User>(
                r#"
                SELECT id, org_id, name, email, phone,
                       password_hash, pin_hash, role,
                       is_active, last_login_at,
                       created_at, updated_at, deleted_at
                FROM users
                WHERE org_id    = $1
                  AND email     = $2
                  AND deleted_at IS NULL
                "#,
            )
            .bind(body.org_id)
            .bind(email)
            .fetch_optional(pool.get_ref())
            .await?
            .ok_or_else(|| AppError::Unauthorized("Invalid credentials".into()))?;

            // Verify password
            let hash = u.password_hash.as_deref().ok_or_else(|| {
                AppError::Unauthorized("No password set for this account".into())
            })?;
            if !bcrypt::verify(password, hash).unwrap_or(false) {
                return Err(AppError::Unauthorized("Invalid credentials".into()));
            }
            u
        }

        // PIN login (tellers only)
        (None, Some(pin)) => {
            let branch_id = body.branch_id.ok_or_else(|| {
                AppError::BadRequest("branch_id is required for PIN login".into())
            })?;

            // Load all active tellers for this branch and find the matching PIN
            let tellers = sqlx::query_as::<_, User>(
                r#"
                SELECT u.id, u.org_id, u.name, u.email, u.phone,
                       u.password_hash, u.pin_hash, u.role,
                       u.is_active, u.last_login_at,
                       u.created_at, u.updated_at, u.deleted_at
                FROM users u
                JOIN user_branch_assignments uba ON uba.user_id = u.id
                WHERE u.org_id     = $1
                  AND uba.branch_id = $2
                  AND u.role        = 'teller'
                  AND u.pin_hash   IS NOT NULL
                  AND u.is_active  = TRUE
                  AND u.deleted_at IS NULL
                "#,
            )
            .bind(body.org_id)
            .bind(branch_id)
            .fetch_all(pool.get_ref())
            .await?;

            tellers
                .into_iter()
                .find(|u| {
                    u.pin_hash
                        .as_deref()
                        .map_or(false, |h| bcrypt::verify(pin, h).unwrap_or(false))
                })
                .ok_or_else(|| AppError::Unauthorized("Invalid PIN".into()))?
        }

        _ => return Err(AppError::BadRequest(
            "Provide either (email + password) or pin".into()
        )),
    };

    // Account must be active
    if !user.is_active {
        return Err(AppError::Unauthorized("Account is disabled".into()));
    }

    // Lock tellers to their branch in the token
    let token_branch_id = if user.role == UserRole::Teller {
        body.branch_id
    } else {
        None
    };

    let hours = if user.role == UserRole::Teller { 12 } else { 24 };

    let token = create_token(
        &secret,
        user.id,
        user.org_id,
        user.role.clone(),
        token_branch_id,
        hours,
    )
    .map_err(|_| AppError::Internal)?;

    // Update last_login_at
    sqlx::query("UPDATE users SET last_login_at = NOW() WHERE id = $1")
        .bind(user.id)
        .execute(pool.get_ref())
        .await?;

    Ok(HttpResponse::Ok().json(LoginResponse {
        token,
        user: user.into(),
    }))
}

// ── GET /auth/me ─────────────────────────────────────────────

pub async fn me(
    req:  HttpRequest,
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, AppError> {
    let claims = req
        .extensions()
        .get::<Claims>()
        .cloned()
        .ok_or_else(|| AppError::Unauthorized("Missing claims".into()))?;

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
    .bind(claims.user_id())
    .fetch_optional(pool.get_ref())
    .await?
    .ok_or_else(|| AppError::NotFound("User not found".into()))?;

    Ok(HttpResponse::Ok().json(MeResponse { user: user.into() }))
}