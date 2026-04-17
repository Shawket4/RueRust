import '../../../core/api/recipe_api.dart';
import '../../../core/models/cart.dart';
import '../../../core/models/menu.dart';

/// Port of the Rust `preview_recipe` logic to Dart for zero-latency offline use.
List<RecipeIngredient> previewRecipeLocally({
  required MenuItem menuItem,
  required String? sizeLabel,
  required List<SelectedAddon> addons,
  required List<SelectedOptional> selectedOptionals,
  required List<AddonItem> allAddons,
}) {
  final List<RecipeIngredient> result = [];

  // 1. Base Recipe
  // Logic: Filter recipes by size. If size doesn't match, pick the first size group found.
  List<MenuItemRecipe> baseRows =
      menuItem.recipes.where((r) => r.sizeLabel == sizeLabel).toList();

  if (baseRows.isEmpty && menuItem.recipes.isNotEmpty) {
    final firstSize = menuItem.recipes.first.sizeLabel;
    baseRows = menuItem.recipes.where((r) => r.sizeLabel == firstSize).toList();
  }

  for (final r in baseRows) {
    result.add(RecipeIngredient(
      orgIngredientId: r.orgIngredientId,
      name: r.ingredientName,
      unit: r.ingredientUnit,
      quantity: r.quantityUsed,
      source: 'drink_recipe',
      category: r.category,
    ));
  }

  // 2. Addons
  for (final sel in addons) {
    final addon = allAddons.where((a) => a.id == sel.addonItemId).firstOrNull;
    if (addon == null) continue;

    final addonQty = sel.quantity.toDouble().clamp(1.0, 99.0);
    final targetCategory = _getTargetCategory(addon.addonType);

    if (targetCategory != null) {
      // SWAP LOGIC for milk_type and coffee_type
      final addonIng = addon.ingredients.firstOrNull;
      if (addonIng != null) {
        bool swapped = false;
        for (int i = 0; i < result.length; i++) {
          final r = result[i];
          if (r.source == 'drink_recipe' && r.category == targetCategory) {
            // Check if this is actually the base (no swap needed)
            final isBase = r.orgIngredientId != null &&
                addonIng.orgIngredientId != null &&
                r.orgIngredientId == addonIng.orgIngredientId;

            if (!isBase) {
              result[i] = RecipeIngredient(
                orgIngredientId: addonIng.orgIngredientId,
                name: addonIng.ingredientName,
                unit: addonIng.ingredientUnit,
                quantity: r.quantity, // Keep base quantity
                source: 'addon_swap:${addon.name}',
                category: targetCategory,
              );
            }
            swapped = true;
          }
        }
        if (swapped) continue;
      }
    }

    // GENERAL ADDON LOGIC
    for (final ing in addon.ingredients) {
      result.add(RecipeIngredient(
        orgIngredientId: ing.orgIngredientId,
        name: ing.ingredientName,
        unit: ing.ingredientUnit,
        quantity: ing.quantityUsed * addonQty,
        source: 'addon',
        category: 'general',
      ));
    }
  }

  // 3. Optionals
  for (final selOpt in selectedOptionals) {
    final field = menuItem.optionalFields
        .where((f) => f.id == selOpt.optionalFieldId)
        .firstOrNull;
    if (field != null && field.hasIngredient) {
      result.add(RecipeIngredient(
        orgIngredientId: field.orgIngredientId,
        name: field.ingredientName!,
        unit: field.ingredientUnit!,
        quantity: field.quantityUsed ?? 0,
        source: 'optional:${field.name}',
        category: 'general',
      ));
    }
  }

  return result;
}

String? _getTargetCategory(String type) {
  switch (type) {
    case 'milk_type':
      return 'milk';
    case 'coffee_type':
      return 'coffee_bean';
    default:
      return null;
  }
}
