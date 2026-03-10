use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::Type;
use uuid::Uuid;

// ── Enums ────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, Type, PartialEq)]
#[sqlx(type_name = "item_size", rename_all = "snake_case")]
#[serde(rename_all = "snake_case")]
pub enum ItemSize {
    Small,
    Medium,
    Large,
    ExtraLarge,
    OneSize,
}

#[derive(Debug, Clone, Serialize, Deserialize, Type)]
#[sqlx(type_name = "addon_selection", rename_all = "snake_case")]
#[serde(rename_all = "snake_case")]
pub enum AddonSelection {
    Single,
    Multi,
}

// ── Category ─────────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Category {
    pub id:            Uuid,
    pub org_id:        Uuid,
    pub name:          String,
    pub image_url:     Option<String>,
    pub display_order: i32,
    pub is_active:     bool,
    pub created_at:    DateTime<Utc>,
    pub updated_at:    DateTime<Utc>,
    pub deleted_at:    Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct CreateCategoryRequest {
    pub name:          String,
    pub image_url:     Option<String>,
    pub display_order: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateCategoryRequest {
    pub name:          Option<String>,
    pub image_url:     Option<String>,
    pub display_order: Option<i32>,
    pub is_active:     Option<bool>,
}

// ── Menu Item (drinks only) ───────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct MenuItem {
    pub id:            Uuid,
    pub org_id:        Uuid,
    pub category_id:   Option<Uuid>,
    pub name:          String,
    pub description:   Option<String>,
    pub image_url:     Option<String>,
    pub base_price:    i32,
    pub is_active:     bool,
    pub display_order: i32,
    pub created_at:    DateTime<Utc>,
    pub updated_at:    DateTime<Utc>,
    pub deleted_at:    Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize)]
pub struct MenuItemFull {
    #[serde(flatten)]
    pub item:          MenuItem,
    pub sizes:         Vec<ItemSizeRow>,
    pub option_groups: Vec<DrinkOptionGroupFull>,
}

#[derive(Debug, Deserialize)]
pub struct CreateMenuItemRequest {
    pub category_id:   Uuid,
    pub name:          String,
    pub description:   Option<String>,
    pub image_url:     Option<String>,
    pub base_price:    i32,
    pub display_order: Option<i32>,
    pub sizes:         Option<Vec<CreateSizeRequest>>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateMenuItemRequest {
    pub category_id:   Option<Uuid>,
    pub name:          Option<String>,
    pub description:   Option<String>,
    pub image_url:     Option<String>,
    pub base_price:    Option<i32>,
    pub display_order: Option<i32>,
    pub is_active:     Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct MenuItemQuery {
    pub category_id: Option<Uuid>,
}

// ── Item Sizes ────────────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct ItemSizeRow {
    pub id:             Uuid,
    pub menu_item_id:   Uuid,
    pub label:          ItemSize,
    pub price_override: i32,
    pub display_order:  i32,
    pub is_active:      bool,
}

#[derive(Debug, Deserialize)]
pub struct CreateSizeRequest {
    pub label:          ItemSize,
    pub price_override: i32,
    pub display_order:  Option<i32>,
}

// ── Addon Items (global catalog) ──────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct AddonItem {
    pub id:            Uuid,
    pub org_id:        Uuid,
    pub name:          String,
    #[sqlx(rename = "type")]
    pub addon_type:    String,   // coffee_type | milk_type | extra
    pub default_price: i32,
    pub is_active:     bool,
    pub display_order: i32,
    pub created_at:    DateTime<Utc>,
    pub updated_at:    DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateAddonItemRequest {
    pub name:          String,
    #[serde(rename = "type")]
    pub addon_type:    String,
    pub default_price: i32,
    pub display_order: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateAddonItemRequest {
    pub name:          Option<String>,
    #[serde(rename = "type")]
    pub addon_type:    Option<String>,
    pub default_price: Option<i32>,
    pub display_order: Option<i32>,
    pub is_active:     Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct AddonItemQuery {
    #[serde(rename = "type")]
    pub addon_type: Option<String>,
}

// ── Drink Option Groups ───────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct DrinkOptionGroup {
    pub id:             Uuid,
    pub menu_item_id:   Uuid,
    #[sqlx(rename = "type")]
    pub group_type:     String,   // coffee_type | milk_type | extra
    pub selection_type: AddonSelection,
    pub is_required:    bool,
    pub min_selections: i32,
    pub display_order:  i32,
}

#[derive(Debug, Serialize)]
pub struct DrinkOptionGroupFull {
    #[serde(flatten)]
    pub group: DrinkOptionGroup,
    pub items: Vec<DrinkOptionItemFull>,
}

#[derive(Debug, Deserialize)]
pub struct CreateDrinkOptionGroupRequest {
    #[serde(rename = "type")]
    pub group_type:     String,
    pub selection_type: AddonSelection,
    pub is_required:    Option<bool>,
    pub min_selections: Option<i32>,
    pub display_order:  Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateDrinkOptionGroupRequest {
    pub selection_type: Option<AddonSelection>,
    pub is_required:    Option<bool>,
    pub min_selections: Option<i32>,
    pub display_order:  Option<i32>,
}

// ── Drink Option Items ────────────────────────────────────────

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct DrinkOptionItem {
    pub id:             Uuid,
    pub group_id:       Uuid,
    pub addon_item_id:  Uuid,
    pub price_override: Option<i32>,
    pub display_order:  i32,
    pub is_active:      bool,
}

#[derive(Debug, Serialize)]
pub struct DrinkOptionItemFull {
    pub id:             Uuid,
    pub group_id:       Uuid,
    pub addon_item_id:  Uuid,
    pub price_override: Option<i32>,
    pub display_order:  i32,
    pub is_active:      bool,
    // joined from addon_items
    pub name:           String,
    pub default_price:  i32,
    #[serde(rename = "type")]
    pub addon_type:     String,
}

#[derive(Debug, Deserialize)]
pub struct AddDrinkOptionItemRequest {
    pub addon_item_id:  Uuid,
    pub price_override: Option<i32>,
    pub display_order:  Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateDrinkOptionItemRequest {
    pub price_override: Option<i32>,
    pub display_order:  Option<i32>,
    pub is_active:      Option<bool>,
}