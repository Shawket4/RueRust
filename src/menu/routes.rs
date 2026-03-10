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
                .route("/{id}/option-groups",                               web::get().to(list_option_groups))
                .route("/{id}/option-groups",                               web::post().to(create_option_group))
                .route("/{item_id}/option-groups/{group_id}",               web::patch().to(update_option_group))
                .route("/{item_id}/option-groups/{group_id}",               web::delete().to(delete_option_group))
                .route("/{item_id}/option-groups/{group_id}/items",         web::post().to(add_option_item))
                .route("/{item_id}/option-groups/{group_id}/items/{oi_id}", web::patch().to(update_option_item))
                .route("/{item_id}/option-groups/{group_id}/items/{oi_id}", web::delete().to(delete_option_item)),
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