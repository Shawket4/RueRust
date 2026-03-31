use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, inventory::handlers, adjustments::handlers as adj};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/inventory")
            .wrap(JwtMiddleware)
            // ── Inventory items ───────────────────────────────────────
            .route("/branches/{branch_id}/items",           web::post().to(handlers::create_item))
            .route("/branches/{branch_id}/items",           web::get().to(handlers::list_items))
            .route("/items/{item_id}",                      web::get().to(handlers::get_item))
            .route("/items/{item_id}",                      web::patch().to(handlers::update_item))
            .route("/items/{item_id}",                      web::delete().to(handlers::delete_item))
            // ── Adjustments ───────────────────────────────────────────
            .route("/branches/{branch_id}/adjustments",     web::post().to(adj::create_adjustment))
            .route("/branches/{branch_id}/adjustments",     web::get().to(adj::list_adjustments))
            // ── Transfers ─────────────────────────────────────────────
            .route("/transfers",                            web::post().to(adj::initiate_transfer))
            .route("/branches/{branch_id}/transfers",       web::get().to(adj::list_transfers))
            .route("/transfers/{transfer_id}",              web::get().to(adj::get_transfer))
            .route("/transfers/{transfer_id}/confirm",      web::patch().to(adj::confirm_transfer))
            .route("/transfers/{transfer_id}/reject",       web::patch().to(adj::reject_transfer))
            .route("/orgs/{org_id}/items", web::get().to(handlers::list_items_by_org))
    );
}