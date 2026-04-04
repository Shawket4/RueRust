-- ============================================================
-- GLOBAL ADDON RESTRUCTURE — v5 migration
-- Run on VPS: psql -U rue -d rue -f migration_v5.sql
-- ============================================================

BEGIN;

-- 1. Drop all per-drink option tables
DROP TABLE IF EXISTS drink_option_ingredient_overrides CASCADE;
DROP TABLE IF EXISTS drink_option_items CASCADE;
DROP TABLE IF EXISTS drink_option_groups CASCADE;

-- 2. Create Dynamic Categories (Slots)
CREATE TABLE menu_item_addon_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    addon_type TEXT NOT NULL,          -- e.g., 'sweetener', 'milk_type'
    is_required BOOLEAN NOT NULL DEFAULT false,
    min_selections INTEGER DEFAULT 0,
    max_selections INTEGER,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (menu_item_id, addon_type)
);

-- 3. Create Explicit Override Matrix
CREATE TABLE menu_item_addon_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    addon_item_id UUID NOT NULL REFERENCES addon_items(id) ON DELETE CASCADE,
    size_label item_size,
    quantity_used NUMERIC(12,3) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (menu_item_id, addon_item_id, size_label)
);

COMMIT;
