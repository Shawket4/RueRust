use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, inventory::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/inventory")
            .wrap(JwtMiddleware)
            // ── Inventory items ──────────────────────────────────────
            .route("/branches/{branch_id}/items",          web::post().to(handlers::create_item))
            .route("/branches/{branch_id}/items",          web::get().to(handlers::list_items))
            .route("/items/{item_id}",                     web::get().to(handlers::get_item))
            .route("/items/{item_id}",                     web::patch().to(handlers::update_item))
            .route("/items/{item_id}",                     web::delete().to(handlers::delete_item)),
    );
}