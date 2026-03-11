use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, orders::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/orders")
            .wrap(JwtMiddleware)
            .route("",          web::post().to(handlers::create_order))
            .route("",          web::get().to(handlers::list_orders))
            .route("/{id}",     web::get().to(handlers::get_order))
            .route("/{id}/void", web::post().to(handlers::void_order)),
    );
}