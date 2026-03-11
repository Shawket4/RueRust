use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, reports::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/reports")
            .wrap(JwtMiddleware)
            // Shift reports
            .route("/shifts/{shift_id}/summary",     web::get().to(handlers::shift_summary))
            .route("/shifts/{shift_id}/inventory",   web::get().to(handlers::shift_inventory_discrepancies))
            .route("/shifts/{shift_id}/deductions",  web::get().to(handlers::shift_deductions))
            // Sales reports
            .route("/branches/{branch_id}/sales",    web::get().to(handlers::branch_sales))
            // Inventory reports
            .route("/branches/{branch_id}/stock",    web::get().to(handlers::branch_stock)),
    );
}