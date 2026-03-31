use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, recipes::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/recipes")
            .wrap(JwtMiddleware)

            // ── Drink recipes (per item + size) ───────────────────────
            // GET    /recipes/drinks/:menu_item_id
            // POST   /recipes/drinks/:menu_item_id
            // DELETE /recipes/drinks/:menu_item_id/:size?ingredient_name=Milk
            .route("/drinks/{menu_item_id}",
                web::get().to(handlers::list_drink_recipes))
            .route("/drinks/{menu_item_id}",
                web::post().to(handlers::upsert_drink_recipe))
            .route("/drinks/{menu_item_id}/{size}",
                web::delete().to(handlers::delete_drink_recipe))

            // ── Addon base ingredients ────────────────────────────────
            // GET    /recipes/addons/:addon_item_id
            // POST   /recipes/addons/:addon_item_id
            // DELETE /recipes/addons/:addon_item_id?ingredient_name=Milk
            .route("/addons/{addon_item_id}",
                web::get().to(handlers::list_addon_ingredients))
            .route("/addons/{addon_item_id}",
                web::post().to(handlers::upsert_addon_ingredient))
            .route("/addons/{addon_item_id}",
                web::delete().to(handlers::delete_addon_ingredient))

            // ── Per-drink-per-size addon overrides ────────────────────
            // GET    /recipes/overrides/:drink_option_item_id
            // POST   /recipes/overrides/:drink_option_item_id
            // DELETE /recipes/overrides/:drink_option_item_id?ingredient_name=Milk&size=medium
            .route("/overrides/{drink_option_item_id}",
                web::get().to(handlers::list_overrides))
            .route("/overrides/{drink_option_item_id}",
                web::post().to(handlers::upsert_override))
            .route("/overrides/{drink_option_item_id}",
                web::delete().to(handlers::delete_override)),
    );
}