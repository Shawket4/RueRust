use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, branches::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/branches")
            .wrap(JwtMiddleware)
            .route("",      web::get().to(handlers::list_branches))
            .route("",      web::post().to(handlers::create_branch))
            .route("/{id}", web::get().to(handlers::get_branch))
            .route("/{id}", web::put().to(handlers::update_branch))
            .route("/{id}", web::delete().to(handlers::delete_branch)),
    );
}