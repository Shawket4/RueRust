use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, discounts::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/discounts")
            .wrap(JwtMiddleware)
            .route("",      web::get().to(handlers::list_discounts))
            .route("",      web::post().to(handlers::create_discount))
            .route("/{id}", web::patch().to(handlers::update_discount))
            .route("/{id}", web::delete().to(handlers::delete_discount)),
    );
}
