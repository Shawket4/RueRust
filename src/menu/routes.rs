use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, menu::handlers::*};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg
        // Categories
        .service(
            web::scope("/categories")
                .wrap(JwtMiddleware)
                .route("",      web::get().to(list_categories))
                .route("",      web::post().to(create_category))
                .route("/{id}", web::patch().to(update_category))
                .route("/{id}", web::delete().to(delete_category)),
        )
        // Menu items + option groups/items nested under them
        .service(
            web::scope("/menu-items")
                .wrap(JwtMiddleware)
                .route("",      web::get().to(list_menu_items))
                .route("",      web::post().to(create_menu_item))
                .route("/{id}", web::get().to(get_menu_item))
                .route("/{id}", web::patch().to(update_menu_item))
                .route("/{id}", web::delete().to(delete_menu_item))
                .route("/{id}/addon-slots",          web::post().to(create_addon_slot))
                .route("/{id}/addon-slots/{slot_id}", web::patch().to(update_addon_slot))
                .route("/{id}/addon-slots/{slot_id}", web::delete().to(delete_addon_slot))

                .route("/{id}/addon-overrides",               web::post().to(upsert_addon_override))
                .route("/{id}/addon-overrides/{override_id}", web::delete().to(delete_addon_override))

                .route("/{id}/sizes",          web::post().to(upsert_size))
                .route("/{id}/sizes/{sid}",    web::delete().to(delete_size))
        )
        // Addon items
        .service(
            web::scope("/addon-items")
                .wrap(JwtMiddleware)
                .route("",      web::get().to(list_addon_items))
                .route("",      web::post().to(create_addon_item))
                .route("/{id}", web::patch().to(update_addon_item))
                .route("/{id}", web::delete().to(delete_addon_item)),
        );
}