-- ============================================================
-- COFFEE SHOP POS — PostgreSQL Schema
-- Run this on your Hostinger VPS as the DB owner user
-- ============================================================

-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE user_role       AS ENUM ('super_admin', 'org_admin', 'branch_manager', 'teller');
CREATE TYPE shift_status    AS ENUM ('open', 'closed', 'force_closed');
CREATE TYPE order_status    AS ENUM ('pending', 'preparing', 'ready', 'completed', 'voided', 'refunded');
CREATE TYPE payment_method  AS ENUM ('cash', 'card', 'digital_wallet', 'mixed');
CREATE TYPE item_size       AS ENUM ('small', 'medium', 'large', 'extra_large', 'one_size');
CREATE TYPE addon_selection AS ENUM ('single', 'multi');
CREATE TYPE discount_type   AS ENUM ('percentage', 'fixed');
CREATE TYPE void_reason     AS ENUM ('customer_request', 'wrong_order', 'quality_issue', 'other');

-- ============================================================
-- 1. ORGANIZATIONS
-- ============================================================
CREATE TABLE organizations (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name           TEXT        NOT NULL,
    slug           TEXT        NOT NULL UNIQUE,
    logo_url       TEXT,
    currency_code  CHAR(3)     NOT NULL DEFAULT 'EGP',
    tax_rate       NUMERIC(5,4) NOT NULL DEFAULT 0.14,
    receipt_footer TEXT,
    is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at     TIMESTAMPTZ
);

-- ============================================================
-- 2. BRANCHES
-- ============================================================
CREATE TABLE branches (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id       UUID        NOT NULL REFERENCES organizations(id),
    name         TEXT        NOT NULL,
    address      TEXT,
    phone        TEXT,
    timezone     TEXT        NOT NULL DEFAULT 'Africa/Cairo',
    printer_ip   INET,
    printer_port INTEGER              DEFAULT 9100,
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at   TIMESTAMPTZ,

    UNIQUE (org_id, name)
);

-- ============================================================
-- 3. USERS
-- ============================================================
CREATE TABLE users (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         UUID        NOT NULL REFERENCES organizations(id),
    name           TEXT        NOT NULL,
    email          TEXT        UNIQUE,
    phone          TEXT,
    password_hash  TEXT,
    pin_hash       TEXT,
    role           user_role   NOT NULL,
    is_active      BOOLEAN     NOT NULL DEFAULT TRUE,
    last_login_at  TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at     TIMESTAMPTZ,

    CONSTRAINT chk_login_method CHECK (
        password_hash IS NOT NULL OR pin_hash IS NOT NULL
    )
);

CREATE TABLE user_branch_assignments (
    user_id     UUID        NOT NULL REFERENCES users(id),
    branch_id   UUID        NOT NULL REFERENCES branches(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by UUID        REFERENCES users(id),

    PRIMARY KEY (user_id, branch_id)
);

-- ============================================================
-- 4. SHIFTS
-- ============================================================
CREATE TABLE shifts (
    id                     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id              UUID         NOT NULL REFERENCES branches(id),
    teller_id              UUID         NOT NULL REFERENCES users(id),
    status                 shift_status NOT NULL DEFAULT 'open',
    opening_cash           INTEGER      NOT NULL DEFAULT 0,
    closing_cash_declared  INTEGER,
    closing_cash_system    INTEGER,
    cash_discrepancy       INTEGER      GENERATED ALWAYS AS (
                               closing_cash_declared - closing_cash_system
                           ) STORED,
    opened_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    closed_at              TIMESTAMPTZ,
    closed_by              UUID         REFERENCES users(id),
    notes                  TEXT,
    created_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Only one open shift per branch at a time
CREATE UNIQUE INDEX idx_shifts_one_open_per_branch
    ON shifts (branch_id)
    WHERE status = 'open';

-- ============================================================
-- 5. CATEGORIES
-- ============================================================
CREATE TABLE categories (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID        NOT NULL REFERENCES organizations(id),
    name          TEXT        NOT NULL,
    image_url     TEXT,
    display_order INTEGER     NOT NULL DEFAULT 0,
    is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ,

    UNIQUE (org_id, name)
);

-- ============================================================
-- 6. MENU ITEMS (drinks + addons in one table)
-- ============================================================
CREATE TABLE menu_items (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID        NOT NULL REFERENCES organizations(id),
    category_id   UUID        REFERENCES categories(id),  -- nullable for addons
    name          TEXT        NOT NULL,
    description   TEXT,
    image_url     TEXT,
    is_addon      BOOLEAN     NOT NULL DEFAULT FALSE,
    base_price    INTEGER     NOT NULL DEFAULT 0,          -- piastres
    addon_type    TEXT,                                    -- Shot | Milk | Sauce | Syrup | Topping
    is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
    display_order INTEGER     NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at    TIMESTAMPTZ,

    -- addons don't need a category; drinks do
    CONSTRAINT chk_drink_has_category CHECK (
        is_addon = TRUE OR category_id IS NOT NULL
    )
);

-- ============================================================
-- 7. ITEM SIZES
-- Per-drink size variants with absolute prices
-- ============================================================
CREATE TABLE item_sizes (
    id             UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id   UUID      NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    label          item_size NOT NULL,
    price_override INTEGER   NOT NULL,   -- absolute price for this size, in piastres
    display_order  INTEGER   NOT NULL DEFAULT 0,
    is_active      BOOLEAN   NOT NULL DEFAULT TRUE,

    UNIQUE (menu_item_id, label)
);

-- ============================================================
-- 8. ADDON GROUPS
-- e.g. "Milk Type" (single, required), "Extras" (multi, optional)
-- ============================================================
CREATE TABLE addon_groups (
    id             UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         UUID           NOT NULL REFERENCES organizations(id),
    name           TEXT           NOT NULL,
    selection_type addon_selection NOT NULL DEFAULT 'multi',
    is_required    BOOLEAN        NOT NULL DEFAULT FALSE,
    min_selections INTEGER        NOT NULL DEFAULT 0,
    display_order  INTEGER        NOT NULL DEFAULT 0,
    is_active      BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 9. ADDON GROUP ITEMS
-- Which addon menu_items belong to which group
-- ============================================================
CREATE TABLE addon_group_items (
    addon_group_id UUID    NOT NULL REFERENCES addon_groups(id) ON DELETE CASCADE,
    addon_item_id  UUID    NOT NULL REFERENCES menu_items(id)   ON DELETE CASCADE,
    display_order  INTEGER NOT NULL DEFAULT 0,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,

    PRIMARY KEY (addon_group_id, addon_item_id),

    -- enforce only addon items can be added to a group (checked via trigger below)
    CONSTRAINT chk_is_addon CHECK (TRUE) -- see trigger
);

-- Trigger to enforce that only is_addon=TRUE items go into addon_group_items
CREATE OR REPLACE FUNCTION check_addon_group_item()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT (SELECT is_addon FROM menu_items WHERE id = NEW.addon_item_id) THEN
        RAISE EXCEPTION 'Only addon items can be added to an addon group';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_addon_group_item
    BEFORE INSERT OR UPDATE ON addon_group_items
    FOR EACH ROW EXECUTE FUNCTION check_addon_group_item();

-- ============================================================
-- 10. DRINK ADDON GROUPS
-- Which addon groups are attached to which drink
-- ============================================================
CREATE TABLE drink_addon_groups (
    menu_item_id   UUID    NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    addon_group_id UUID    NOT NULL REFERENCES addon_groups(id) ON DELETE CASCADE,
    display_order  INTEGER NOT NULL DEFAULT 0,

    PRIMARY KEY (menu_item_id, addon_group_id)
);

-- Trigger to enforce that only is_addon=FALSE items can have addon groups
CREATE OR REPLACE FUNCTION check_drink_addon_group()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT is_addon FROM menu_items WHERE id = NEW.menu_item_id) THEN
        RAISE EXCEPTION 'Only drink items can be linked to addon groups';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_drink_addon_group
    BEFORE INSERT OR UPDATE ON drink_addon_groups
    FOR EACH ROW EXECUTE FUNCTION check_drink_addon_group();

-- ============================================================
-- 11. BRANCH MENU OVERRIDES
-- Per-branch price or availability overrides
-- ============================================================
CREATE TABLE branch_menu_overrides (
    branch_id      UUID        NOT NULL REFERENCES branches(id)    ON DELETE CASCADE,
    menu_item_id   UUID        NOT NULL REFERENCES menu_items(id)  ON DELETE CASCADE,
    price_override INTEGER,                -- NULL = use global price
    is_available   BOOLEAN     NOT NULL DEFAULT TRUE,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (branch_id, menu_item_id)
);

-- ============================================================
-- 12. ORDERS
-- ============================================================
CREATE TABLE orders (
    id              UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id       UUID           NOT NULL REFERENCES branches(id),
    shift_id        UUID           NOT NULL REFERENCES shifts(id),
    teller_id       UUID           NOT NULL REFERENCES users(id),
    order_number    INTEGER        NOT NULL,           -- sequential per shift
    status          order_status   NOT NULL DEFAULT 'pending',
    payment_method  payment_method NOT NULL,
    subtotal        INTEGER        NOT NULL DEFAULT 0, -- before tax & discount
    discount_type   discount_type,
    discount_value  INTEGER        NOT NULL DEFAULT 0,
    discount_amount INTEGER        NOT NULL DEFAULT 0, -- computed & stored
    tax_amount      INTEGER        NOT NULL DEFAULT 0, -- computed & stored
    total_amount    INTEGER        NOT NULL DEFAULT 0, -- final
    customer_name   TEXT,
    notes           TEXT,
    voided_at       TIMESTAMPTZ,
    void_reason     void_reason,
    voided_by       UUID           REFERENCES users(id),
    created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),

    UNIQUE (shift_id, order_number)
);

-- ============================================================
-- 13. ORDER ITEMS
-- ============================================================
CREATE TABLE order_items (
    id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     UUID    NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    menu_item_id UUID    NOT NULL REFERENCES menu_items(id),
    item_name    TEXT    NOT NULL,  -- snapshot
    size_label   TEXT,              -- snapshot
    unit_price   INTEGER NOT NULL,  -- snapshot
    quantity     INTEGER NOT NULL DEFAULT 1,
    line_total   INTEGER NOT NULL,  -- (unit_price * quantity) + addons total
    notes        TEXT
);

-- ============================================================
-- 14. ORDER ITEM ADDONS
-- ============================================================
CREATE TABLE order_item_addons (
    id            UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    order_item_id UUID    NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
    addon_item_id UUID    NOT NULL REFERENCES menu_items(id),
    addon_name    TEXT    NOT NULL,  -- snapshot
    unit_price    INTEGER NOT NULL,  -- snapshot
    quantity      INTEGER NOT NULL DEFAULT 1,
    line_total    INTEGER NOT NULL   -- unit_price * quantity
);

-- ============================================================
-- 15. ORDER PAYMENTS
-- Supports mixed payments (part cash + part card)
-- ============================================================
CREATE TABLE order_payments (
    id         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id   UUID           NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    method     payment_method NOT NULL,
    amount     INTEGER        NOT NULL,
    reference  TEXT,           -- card terminal ref, wallet tx ID
    created_at TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

-- Branches
CREATE INDEX idx_branches_org      ON branches (org_id);

-- Users
CREATE INDEX idx_users_org         ON users (org_id);
CREATE INDEX idx_users_email       ON users (email) WHERE email IS NOT NULL;

-- Shifts
CREATE INDEX idx_shifts_branch     ON shifts (branch_id);
CREATE INDEX idx_shifts_teller     ON shifts (teller_id);
CREATE INDEX idx_shifts_opened_at  ON shifts (opened_at);

-- Menu items
CREATE INDEX idx_menu_items_org       ON menu_items (org_id);
CREATE INDEX idx_menu_items_category  ON menu_items (category_id);
CREATE INDEX idx_menu_items_is_addon  ON menu_items (is_addon);
CREATE INDEX idx_menu_items_name_trgm ON menu_items USING gin (name gin_trgm_ops);

-- Orders
CREATE INDEX idx_orders_branch     ON orders (branch_id);
CREATE INDEX idx_orders_shift      ON orders (shift_id);
CREATE INDEX idx_orders_teller     ON orders (teller_id);
CREATE INDEX idx_orders_status     ON orders (status);
CREATE INDEX idx_orders_created_at ON orders (created_at);

-- Order items
CREATE INDEX idx_order_items_order    ON order_items (order_id);
CREATE INDEX idx_order_item_addons_oi ON order_item_addons (order_item_id);

-- Payments
CREATE INDEX idx_order_payments_order ON order_payments (order_id);

-- ============================================================
-- updated_at AUTO-UPDATE TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_organizations_updated_at  BEFORE UPDATE ON organizations  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_branches_updated_at       BEFORE UPDATE ON branches       FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_users_updated_at          BEFORE UPDATE ON users          FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_shifts_updated_at         BEFORE UPDATE ON shifts         FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_categories_updated_at     BEFORE UPDATE ON categories     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_menu_items_updated_at     BEFORE UPDATE ON menu_items     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_addon_groups_updated_at   BEFORE UPDATE ON addon_groups   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_orders_updated_at         BEFORE UPDATE ON orders         FOR EACH ROW EXECUTE FUNCTION set_updated_at();