use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, adjustments::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/inventory")
            .wrap(JwtMiddleware)

            // ── Manual adjustments ────────────────────────────────────
            // POST /inventory/branches/:branch_id/adjustments   → add or remove stock
            // GET  /inventory/branches/:branch_id/adjustments   → list adjustment history
            .route("/branches/{branch_id}/adjustments",
                web::post().to(handlers::create_adjustment))
            .route("/branches/{branch_id}/adjustments",
                web::get().to(handlers::list_adjustments))

            // ── Transfers ─────────────────────────────────────────────
            // POST   /inventory/transfers                        → initiate transfer
            // GET    /inventory/branches/:branch_id/transfers    → list transfers for branch
            // GET    /inventory/transfers/:transfer_id           → get single transfer
            // PATCH  /inventory/transfers/:transfer_id/confirm   → confirm full or partial
            // PATCH  /inventory/transfers/:transfer_id/reject    → reject
            .route("/transfers",
                web::post().to(handlers::initiate_transfer))
            .route("/branches/{branch_id}/transfers",
                web::get().to(handlers::list_transfers))
            .route("/transfers/{transfer_id}",
                web::get().to(handlers::get_transfer))
            .route("/transfers/{transfer_id}/confirm",
                web::patch().to(handlers::confirm_transfer))
            .route("/transfers/{transfer_id}/reject",
                web::patch().to(handlers::reject_transfer)),
    );
}