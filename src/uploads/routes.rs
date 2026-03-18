use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, uploads::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/uploads")
            .service(
                web::scope("/menu-items")
                    .wrap(JwtMiddleware)
                    .route("/{menu_item_id}", web::post().to(handlers::upload_menu_item_image)),
            ),
    );
}
