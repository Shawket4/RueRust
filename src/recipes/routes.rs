use actix_web::web;
use crate::{auth::middleware::JwtMiddleware, recipes::handlers};

pub fn configure(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/recipes")
            .wrap(JwtMiddleware)

            // ── Drink recipes (per item + size) ───────────────────────
            // GET    /recipes/drinks/:menu_item_id          → list all size recipes for a drink
            // POST   /recipes/drinks/:menu_item_id          → upsert a size recipe ingredient
            // DELETE /recipes/drinks/:menu_item_id/:size/:inventory_item_id
            .route("/drinks/{menu_item_id}",
                web::get().to(handlers::list_drink_recipes))
            .route("/drinks/{menu_item_id}",
                web::post().to(handlers::upsert_drink_recipe))
            .route("/drinks/{menu_item_id}/{size}/{inventory_item_id}",
                web::delete().to(handlers::delete_drink_recipe))

            // ── Addon base ingredients ────────────────────────────────
            // GET    /recipes/addons/:addon_item_id          → list base ingredients
            // POST   /recipes/addons/:addon_item_id          → upsert base ingredient
            // DELETE /recipes/addons/:addon_item_id/:inventory_item_id
            .route("/addons/{addon_item_id}",
                web::get().to(handlers::list_addon_ingredients))
            .route("/addons/{addon_item_id}",
                web::post().to(handlers::upsert_addon_ingredient))
            .route("/addons/{addon_item_id}/{inventory_item_id}",
                web::delete().to(handlers::delete_addon_ingredient))

            // ── Per-drink-per-size addon overrides ────────────────────
            // GET    /recipes/overrides/:drink_option_item_id
            // POST   /recipes/overrides/:drink_option_item_id
            // DELETE /recipes/overrides/:drink_option_item_id/:inventory_item_id?size=...
            .route("/overrides/{drink_option_item_id}",
                web::get().to(handlers::list_overrides))
            .route("/overrides/{drink_option_item_id}",
                web::post().to(handlers::upsert_override))
            .route("/overrides/{drink_option_item_id}/{inventory_item_id}",
                web::delete().to(handlers::delete_override)),
    );
}