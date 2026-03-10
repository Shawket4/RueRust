use actix_web::web;
use super::handlers::*;

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg
        // Categories
        .service(list_categories)
        .service(create_category)
        .service(update_category)
        .service(delete_category)
        // Menu items
        .service(list_menu_items)
        .service(get_menu_item)
        .service(create_menu_item)
        .service(update_menu_item)
        .service(delete_menu_item)
        // Addon items
        .service(list_addon_items)
        .service(create_addon_item)
        .service(update_addon_item)
        .service(delete_addon_item)
        // Drink option groups
        .service(list_option_groups)
        .service(create_option_group)
        .service(update_option_group)
        .service(delete_option_group)
        // Drink option items
        .service(add_option_item)
        .service(update_option_item)
        .service(delete_option_item);
}