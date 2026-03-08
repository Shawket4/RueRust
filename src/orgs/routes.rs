use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, orgs::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/orgs")
            .wrap(JwtMiddleware)
            .route("",        web::post().to(handlers::create_org))
            .route("",        web::get().to(handlers::list_orgs))
            .route("/{id}",   web::get().to(handlers::get_org)),
    );
}