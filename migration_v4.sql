ALTER TABLE order_items ADD COLUMN deductions_snapshot JSONB DEFAULT '[]'::jsonb NOT NULL;
