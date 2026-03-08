use actix_web::HttpResponse;
use serde::Serialize;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    #[error("Forbidden: {0}")]
    Forbidden(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Bad request: {0}")]
    BadRequest(String),

    #[error("Conflict: {0}")]
    Conflict(String),

    #[error("Database error: {0}")]
    Db(#[from] sqlx::Error),

    #[error("Internal error")]
    Internal,
}

#[derive(Serialize)]
struct ErrorBody {
    error: String,
}

impl actix_web::ResponseError for AppError {
    fn error_response(&self) -> HttpResponse {
        let body = ErrorBody { error: self.to_string() };
        match self {
            AppError::Unauthorized(_) => HttpResponse::Unauthorized().json(body),
            AppError::Forbidden(_)    => HttpResponse::Forbidden().json(body),
            AppError::NotFound(_)     => HttpResponse::NotFound().json(body),
            AppError::BadRequest(_)   => HttpResponse::BadRequest().json(body),
            AppError::Conflict(_)     => HttpResponse::Conflict().json(body),
            AppError::Db(_)           => HttpResponse::InternalServerError().json(body),
            AppError::Internal        => HttpResponse::InternalServerError().json(body),
        }
    }
}