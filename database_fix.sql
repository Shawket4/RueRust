UPDATE menu_item_recipes r
SET org_ingredient_id = i.id
FROM org_ingredients i
WHERE r.ingredient_name = i.name AND r.org_ingredient_id IS NULL;

UPDATE addon_item_ingredients a
SET org_ingredient_id = i.id
FROM org_ingredients i
WHERE a.ingredient_name = i.name AND a.org_ingredient_id IS NULL;
