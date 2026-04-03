-- ============================================================
-- INVENTORY RESTRUCTURE — v2 migration
-- Run on VPS: psql -U rue -d rue -f migration_v2.sql
-- ============================================================

BEGIN;

-- 1. Org-level ingredient catalog
CREATE TABLE org_ingredients (
    id            UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID           NOT NULL REFERENCES organizations(id),
    name          TEXT           NOT NULL,
    unit          inventory_unit NOT NULL,
    description   TEXT,
    cost_per_unit INTEGER        NOT NULL DEFAULT 0,
    is_active     BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ,
    UNIQUE (org_id, name)
);

-- 2. Branch-level stock tracking
CREATE TABLE branch_inventory (
    id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id         UUID          NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    org_ingredient_id UUID          NOT NULL REFERENCES org_ingredients(id) ON DELETE RESTRICT,
    current_stock     NUMERIC(12,3) NOT NULL DEFAULT 0,
    reorder_threshold NUMERIC(12,3) NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (branch_id, org_ingredient_id)
);

-- 3. Adjustments (add / remove / transfer_in / transfer_out) — note is mandatory
CREATE TABLE branch_inventory_adjustments (
    id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id           UUID          NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    branch_inventory_id UUID          NOT NULL REFERENCES branch_inventory(id) ON DELETE RESTRICT,
    type                inventory_adjustment_type NOT NULL,
    quantity            NUMERIC(12,3) NOT NULL,
    note                TEXT          NOT NULL,
    transfer_id         UUID,         -- filled in for transfer_in / transfer_out
    adjusted_by         UUID          NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- 4. Transfers (always auto-applied — no pending flow)
CREATE TABLE branch_inventory_transfers (
    id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                UUID          NOT NULL REFERENCES organizations(id),
    source_branch_id      UUID          NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    destination_branch_id UUID          NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    org_ingredient_id     UUID          NOT NULL REFERENCES org_ingredients(id) ON DELETE RESTRICT,
    quantity              NUMERIC(12,3) NOT NULL,
    note                  TEXT,
    initiated_by          UUID          NOT NULL REFERENCES users(id),
    initiated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_transfer_branches CHECK (source_branch_id <> destination_branch_id)
);

-- 5. Self-referential FK: adjustments → transfers
ALTER TABLE branch_inventory_adjustments
    ADD CONSTRAINT fk_bia_transfer
    FOREIGN KEY (transfer_id) REFERENCES branch_inventory_transfers(id) ON DELETE SET NULL;

-- 6. Add org_ingredient_id to recipe linkage tables (nullable — old rows have none)
ALTER TABLE menu_item_recipes
    ADD COLUMN org_ingredient_id UUID REFERENCES org_ingredients(id) ON DELETE RESTRICT;

ALTER TABLE addon_item_ingredients
    ADD COLUMN org_ingredient_id UUID REFERENCES org_ingredients(id) ON DELETE RESTRICT;

ALTER TABLE drink_option_ingredient_overrides
    ADD COLUMN org_ingredient_id UUID REFERENCES org_ingredients(id) ON DELETE RESTRICT;

-- 7. Drop old inventory tables + soft serve tracking (order: children before parents)
DROP TABLE IF EXISTS soft_serve_batch_ingredients;
DROP TABLE IF EXISTS inventory_deduction_logs;
DROP TABLE IF EXISTS shift_inventory_counts;
DROP TABLE IF EXISTS shift_inventory_snapshots;
DROP TABLE IF EXISTS inventory_adjustments;
DROP TABLE IF EXISTS inventory_transfers;
DROP TABLE IF EXISTS inventory_items;

-- Soft serve is now treated as a regular drink (recipe-based deduction through orders).
-- Drop the dedicated soft serve tracking tables too.
DROP TABLE IF EXISTS soft_serve_serve_pools;
DROP TABLE IF EXISTS soft_serve_batches;

-- 8. Recreate shift_inventory_counts pointing to branch_inventory (no snapshots needed)
CREATE TABLE shift_inventory_counts (
    id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id            UUID          NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    branch_inventory_id UUID          NOT NULL REFERENCES branch_inventory(id) ON DELETE RESTRICT,
    expected_stock      NUMERIC(12,3) NOT NULL,
    actual_stock        NUMERIC(12,3) NOT NULL,
    discrepancy         NUMERIC(12,3) GENERATED ALWAYS AS (expected_stock - actual_stock) STORED,
    is_suspicious       BOOLEAN       NOT NULL DEFAULT FALSE,
    note                TEXT,
    counted_by          UUID          NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (shift_id, branch_inventory_id)
);

-- 9. Indexes
CREATE INDEX idx_org_ingredients_org          ON org_ingredients (org_id);
CREATE INDEX idx_branch_inventory_branch      ON branch_inventory (branch_id);
CREATE INDEX idx_branch_inventory_ingredient  ON branch_inventory (org_ingredient_id);
CREATE INDEX idx_bia_branch                   ON branch_inventory_adjustments (branch_id);
CREATE INDEX idx_bia_inv                      ON branch_inventory_adjustments (branch_inventory_id);
CREATE INDEX idx_bit_source                   ON branch_inventory_transfers (source_branch_id);
CREATE INDEX idx_bit_dest                     ON branch_inventory_transfers (destination_branch_id);
CREATE INDEX idx_bit_ingredient               ON branch_inventory_transfers (org_ingredient_id);
CREATE INDEX idx_sic_shift                    ON shift_inventory_counts (shift_id);

-- 11. Updated-at triggers
CREATE TRIGGER trg_org_ingredients_updated_at
    BEFORE UPDATE ON org_ingredients
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_branch_inventory_updated_at
    BEFORE UPDATE ON branch_inventory
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

COMMIT;
