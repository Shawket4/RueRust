-- ============================================================
-- Migration v5b — delta on top of the already-applied v5 stub
-- Run on VPS: psql -U rue -d rue -f migration_v5b.sql
--
-- The v5 stub already:
--   • Dropped drink_option_groups / items / ingredient_overrides
--   • Created menu_item_addon_slots  (minimal columns)
--   • Created menu_item_addon_overrides (thin: quantity_used only)
--
-- This migration:
--   1. Adds missing columns to menu_item_addon_slots
--   2. Drops the thin menu_item_addon_overrides and replaces it
--      with the full version (ingredient columns + combo support)
--   3. Drops the CHECK constraint on addon_items.type
--   4. Adds all indexes and the updated_at trigger
-- ============================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 1. Patch menu_item_addon_slots — add missing columns
-- ─────────────────────────────────────────────────────────────
ALTER TABLE menu_item_addon_slots
    ADD COLUMN IF NOT EXISTS label TEXT,
    ALTER COLUMN min_selections SET NOT NULL,
    ALTER COLUMN min_selections SET DEFAULT 0,
    ALTER COLUMN display_order  SET NOT NULL,
    ALTER COLUMN display_order  SET DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_mias_menu_item
    ON menu_item_addon_slots(menu_item_id);

-- ─────────────────────────────────────────────────────────────
-- 2. Replace the thin menu_item_addon_overrides
--    The stub UNIQUE(menu_item_id, addon_item_id, size_label)
--    won't work once we add ingredient_name as a key dimension
--    (one addon can override multiple ingredients), so we drop
--    and recreate with the correct schema.
-- ─────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS menu_item_addon_overrides CASCADE;

CREATE TABLE menu_item_addon_overrides (
    id                          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id                UUID          NOT NULL REFERENCES menu_items(id)   ON DELETE CASCADE,
    addon_item_id               UUID          NOT NULL REFERENCES addon_items(id)  ON DELETE CASCADE,
    -- NULL = applies to all sizes; size-specific rows take priority
    size_label                  item_size,
    -- Ingredient to deduct — name-keyed (same pattern as menu_item_recipes
    -- and addon_item_ingredients so cross-branch deduction works correctly)
    ingredient_name             TEXT          NOT NULL,
    org_ingredient_id           UUID          REFERENCES org_ingredients(id) ON DELETE SET NULL,
    ingredient_unit             TEXT          NOT NULL,
    quantity_used               NUMERIC(12,3) NOT NULL,
    -- If set, this deduction REPLACES that base ingredient from the drink recipe
    -- (same semantics as addon_item_ingredients.replaces_org_ingredient_id)
    replaces_org_ingredient_id  UUID          REFERENCES org_ingredients(id) ON DELETE SET NULL,
    -- Combo rule: when set, this row only fires when that other addon is
    -- ALSO selected on the same order item.
    -- NULL = standalone rule (always applies when this addon is selected).
    combo_addon_item_id         UUID          REFERENCES addon_items(id)     ON DELETE CASCADE,
    created_at                  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ── Uniqueness ────────────────────────────────────────────────
-- Plain UNIQUE constraints treat NULLs as always-distinct, so we use
-- partial unique indexes to enforce one rule per
-- (menu_item, addon, ingredient, size?, combo_partner?).

-- Standalone, size-specific
CREATE UNIQUE INDEX idx_miao_standalone_sized
    ON menu_item_addon_overrides (menu_item_id, addon_item_id, ingredient_name, size_label)
    WHERE combo_addon_item_id IS NULL AND size_label IS NOT NULL;

-- Standalone, size-wildcard
CREATE UNIQUE INDEX idx_miao_standalone_any_size
    ON menu_item_addon_overrides (menu_item_id, addon_item_id, ingredient_name)
    WHERE combo_addon_item_id IS NULL AND size_label IS NULL;

-- Combo, size-specific
CREATE UNIQUE INDEX idx_miao_combo_sized
    ON menu_item_addon_overrides (menu_item_id, addon_item_id, ingredient_name, size_label, combo_addon_item_id)
    WHERE combo_addon_item_id IS NOT NULL AND size_label IS NOT NULL;

-- Combo, size-wildcard
CREATE UNIQUE INDEX idx_miao_combo_any_size
    ON menu_item_addon_overrides (menu_item_id, addon_item_id, ingredient_name, combo_addon_item_id)
    WHERE combo_addon_item_id IS NOT NULL AND size_label IS NULL;

-- ── Lookup indexes ────────────────────────────────────────────
CREATE INDEX idx_miao_menu_item    ON menu_item_addon_overrides (menu_item_id);
CREATE INDEX idx_miao_addon_item   ON menu_item_addon_overrides (addon_item_id);
CREATE INDEX idx_miao_combo_target ON menu_item_addon_overrides (combo_addon_item_id)
    WHERE combo_addon_item_id IS NOT NULL;

-- ── updated_at trigger ────────────────────────────────────────
CREATE TRIGGER trg_miao_updated_at
    BEFORE UPDATE ON menu_item_addon_overrides
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─────────────────────────────────────────────────────────────
-- 3. Drop the CHECK constraint on addon_items.type so custom
--    slot types (e.g. 'sweetener') are valid addon types
-- ─────────────────────────────────────────────────────────────
ALTER TABLE addon_items DROP CONSTRAINT IF EXISTS addon_items_type_check;

COMMIT;