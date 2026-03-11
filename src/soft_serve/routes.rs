use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, soft_serve::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/soft-serve")
            .wrap(JwtMiddleware)

            // ── Serve pool ────────────────────────────────────────────
            // GET  /soft-serve/branches/:branch_id/pools
            // GET  /soft-serve/branches/:branch_id/pools/:menu_item_id
            .route("/branches/{branch_id}/pools",
                web::get().to(handlers::list_serve_pools))
            .route("/branches/{branch_id}/pools/{menu_item_id}",
                web::get().to(handlers::get_serve_pool))

            // ── Batches ───────────────────────────────────────────────
            // POST /soft-serve/branches/:branch_id/batches
            // GET  /soft-serve/branches/:branch_id/batches
            .route("/branches/{branch_id}/batches",
                web::post().to(handlers::log_batch))
            .route("/branches/{branch_id}/batches",
                web::get().to(handlers::list_batches)),
    );
}