-- Migration v3: Ingredient substitution for milk-type addons
-- Adds replaces_org_ingredient_id to both tables.
-- When set, the order handler will remove the replaced ingredient's
-- base-recipe deduction before applying the addon's own deduction.

ALTER TABLE drink_option_ingredient_overrides
  ADD COLUMN IF NOT EXISTS replaces_org_ingredient_id UUID REFERENCES org_ingredients(id);

ALTER TABLE addon_item_ingredients
  ADD COLUMN IF NOT EXISTS replaces_org_ingredient_id UUID REFERENCES org_ingredients(id);
