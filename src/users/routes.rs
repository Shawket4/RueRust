use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, users::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/users")
            .wrap(JwtMiddleware)
            .route("",                                  web::post().to(handlers::create_user))
            .route("",                                  web::get().to(handlers::list_users))
            .route("/{id}",                             web::get().to(handlers::get_user))
            .route("/{id}",                             web::delete().to(handlers::delete_user))
            .route("/{id}/branches",                    web::post().to(handlers::assign_branch))
            .route("/{id}/branches/{branch_id}",        web::delete().to(handlers::unassign_branch)),
    );
}