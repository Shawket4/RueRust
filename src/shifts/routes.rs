use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, shifts::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/shifts")
            .wrap(JwtMiddleware)

            // ── Shift lifecycle ───────────────────────────────────────
            // GET  /shifts/branches/:branch_id/current       → get open shift (or pre-fill data)
            // POST /shifts/branches/:branch_id/open          → open a shift
            // GET  /shifts/branches/:branch_id               → list shifts for branch
            // GET  /shifts/:shift_id                         → get single shift
            // POST /shifts/:shift_id/cash-movements          → cash in / cash out
            // GET  /shifts/:shift_id/cash-movements          → list cash movements
            // POST /shifts/:shift_id/close                   → close shift (cash + inventory counts)
            // POST /shifts/:shift_id/force-close             → manager force close
            .route("/branches/{branch_id}/current",
                web::get().to(handlers::get_current_shift))
            .route("/branches/{branch_id}/open",
                web::post().to(handlers::open_shift))
            .route("/branches/{branch_id}",
                web::get().to(handlers::list_shifts))
            .route("/{shift_id}",
                web::get().to(handlers::get_shift))
            .route("/{shift_id}/cash-movements",
                web::post().to(handlers::add_cash_movement))
            .route("/{shift_id}/cash-movements",
                web::get().to(handlers::list_cash_movements))
            .route("/{shift_id}/close",
                web::post().to(handlers::close_shift))
            .route("/{shift_id}/force-close",
                web::post().to(handlers::force_close_shift)),
    );
}