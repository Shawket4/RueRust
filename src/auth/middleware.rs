use actix_web::{
    dev::{forward_ready, Service, ServiceRequest, ServiceResponse, Transform},
    web, Error, HttpMessage,
};
use futures::future::{ready, LocalBoxFuture, Ready};
use std::rc::Rc;

use crate::{auth::jwt::{verify_token, JwtSecret}, errors::AppError};

// ── JwtMiddleware factory ─────────────────────────────────────

pub struct JwtMiddleware;

impl<S, B> Transform<S, ServiceRequest> for JwtMiddleware
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    B: 'static,
{
    type Response  = ServiceResponse<B>;
    type Error     = Error;
    type Transform = JwtMiddlewareService<S>;
    type InitError = ();
    type Future    = Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        ready(Ok(JwtMiddlewareService { service: Rc::new(service) }))
    }
}

pub struct JwtMiddlewareService<S> {
    service: Rc<S>,
}

impl<S, B> Service<ServiceRequest> for JwtMiddlewareService<S>
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error    = Error;
    type Future   = LocalBoxFuture<'static, Result<Self::Response, Self::Error>>;

    forward_ready!(service);

    fn call(&self, req: ServiceRequest) -> Self::Future {
        let svc = self.service.clone();

        Box::pin(async move {
            // Extract Bearer token from Authorization header
            let token = req
                .headers()
                .get("Authorization")
                .and_then(|v| v.to_str().ok())
                .and_then(|v| v.strip_prefix("Bearer "))
                .map(|s| s.to_string());

            let token = match token {
                Some(t) => t,
                None => {
                    return Err(actix_web::error::ErrorUnauthorized(
                        AppError::Unauthorized("Missing Authorization header".into()).to_string(),
                    ))
                }
            };

            // Verify token using JwtSecret from app data
            let secret = req
                .app_data::<web::Data<JwtSecret>>()
                .expect("JwtSecret not registered");

            let claims = match verify_token(secret, &token) {
                Ok(c)  => c,
                Err(_) => {
                    return Err(actix_web::error::ErrorUnauthorized(
                        AppError::Unauthorized("Invalid or expired token".into()).to_string(),
                    ))
                }
            };

            // Attach claims to request extensions so handlers can read them
            req.extensions_mut().insert(claims);

            svc.call(req).await
        })
    }
}