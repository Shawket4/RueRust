use actix_web::web;
use super::handlers::*;

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg
        // Categories
        .route("/categories",     web::get().to(list_categories))
        .route("/categories",     web::post().to(create_category))
        .route("/categories/{id}", web::patch().to(update_category))
        .route("/categories/{id}", web::delete().to(delete_category))

        // Menu items
        .route("/menu-items",      web::get().to(list_menu_items))
        .route("/menu-items",      web::post().to(create_menu_item))
        .route("/menu-items/{id}", web::get().to(get_menu_item))
        .route("/menu-items/{id}", web::patch().to(update_menu_item))
        .route("/menu-items/{id}", web::delete().to(delete_menu_item))

        // Addon items
        .route("/addon-items",      web::get().to(list_addon_items))
        .route("/addon-items",      web::post().to(create_addon_item))
        .route("/addon-items/{id}", web::patch().to(update_addon_item))
        .route("/addon-items/{id}", web::delete().to(delete_addon_item))

        // Drink option groups
        .route("/menu-items/{id}/option-groups",                         web::get().to(list_option_groups))
        .route("/menu-items/{id}/option-groups",                         web::post().to(create_option_group))
        .route("/menu-items/{item_id}/option-groups/{group_id}",         web::patch().to(update_option_group))
        .route("/menu-items/{item_id}/option-groups/{group_id}",         web::delete().to(delete_option_group))

        // Drink option items
        .route("/menu-items/{item_id}/option-groups/{group_id}/items",            web::post().to(add_option_item))
        .route("/menu-items/{item_id}/option-groups/{group_id}/items/{oi_id}",    web::patch().to(update_option_item))
        .route("/menu-items/{item_id}/option-groups/{group_id}/items/{oi_id}",    web::delete().to(delete_option_item));
}