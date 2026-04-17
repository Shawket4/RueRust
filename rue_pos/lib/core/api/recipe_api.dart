import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';
import '../models/menu.dart';
import 'client.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  RecipeIngredient — output model (same shape as backend response)
// ─────────────────────────────────────────────────────────────────────────────
class RecipeIngredient {
  final String? orgIngredientId;
  final String  name;
  final String  unit;
  final double  quantity;
  final String  source; // drink_recipe | addon | addon_swap:Name | optional:FieldName
  final String  category;

  const RecipeIngredient({
    this.orgIngredientId,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.source,
    required this.category,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        orgIngredientId: j['org_ingredient_id'] as String?,
        name:     j['ingredient_name'] as String,
        unit:     j['unit']            as String,
        quantity: (j['quantity']       as num).toDouble(),
        source:   j['source']          as String,
        category: (j['category'] ?? 'general') as String,
      );

  RecipeIngredient copyWith({
    String? orgIngredientId,
    String? name,
    String? unit,
    double? quantity,
    String? source,
    String? category,
  }) =>
      RecipeIngredient(
        orgIngredientId: orgIngredientId ?? this.orgIngredientId,
        name:     name     ?? this.name,
        unit:     unit     ?? this.unit,
        quantity: quantity ?? this.quantity,
        source:   source   ?? this.source,
        category: category ?? this.category,
      );

  bool get isBase     => source == 'drink_recipe';
  bool get isAddon    => source == 'addon';
  bool get isOptional => source.startsWith('optional');
  bool get isSwap     => source.startsWith('addon_swap');

  String get sourceLabel {
    if (isBase)     return 'base';
    if (isAddon)    return 'addon';
    if (isOptional) return source.split(':').length > 1 ? source.split(':')[1] : 'optional';
    if (isSwap)     return source.split(':').length > 1 ? source.split(':')[1] : 'swap';
    return source;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Local recipe computation — mirrors the Rust preview_recipe handler exactly.
//
//  Returns null if the item lacks embedded recipe data (recipes list empty),
//  which is the signal to fall back to the network call.
// ─────────────────────────────────────────────────────────────────────────────
List<RecipeIngredient>? computeRecipeLocally({
  required MenuItem           item,
  required String?            sizeLabel,
  required List<SelectedAddon> addons,
  required List<SelectedOptional> optionals,
  required List<AddonItem>    allAddons,
}) {
  // ── Guard: no embedded recipes ───────────────────────────────────────────
  if (item.recipes.isEmpty) return null;

  // ── 1. Base recipe rows filtered by size ─────────────────────────────────
  //
  //   Mirrors Rust: if size_label provided → filter by it.
  //   Otherwise → use the first size_label found in the recipe rows
  //   (same fallback the backend uses).

  List<MenuItemRecipe> baseRows;

  if (sizeLabel != null) {
    baseRows = item.recipes.where((r) => r.sizeLabel == sizeLabel).toList();
  } else {
    // Pick the first available size_label present
    final firstSize = item.recipes
        .map((r) => r.sizeLabel)
        .firstWhere((s) => s != null, orElse: () => null);
    baseRows = firstSize != null
        ? item.recipes.where((r) => r.sizeLabel == firstSize).toList()
        : item.recipes.toList();
  }

  // Build mutable working list
  final result = baseRows
      .map((r) => RecipeIngredient(
            orgIngredientId: r.orgIngredientId,
            name:     r.ingredientName,
            unit:     r.ingredientUnit,
            quantity: r.quantityUsed,
            source:   'drink_recipe',
            category: r.category,
          ))
      .toList();

  // ── 2. Addons ─────────────────────────────────────────────────────────────
  //
  //   milk_type / coffee_type → SWAP the base ingredient of matching category.
  //   Everything else          → ADD ingredient rows (multiplied by qty).

  for (final sa in addons) {
    final addonItem =
        allAddons.where((a) => a.id == sa.addonItemId).firstOrNull;
    if (addonItem == null) continue;

    final addonQty = sa.quantity.toDouble();

    // Category-to-ingredient-category mapping (mirrors Rust match)
    final String? targetCategory = switch (addonItem.addonType) {
      'milk_type'   => 'milk',
      'coffee_type' => 'coffee_bean',
      _             => null,
    };

    if (targetCategory != null) {
      // --- Swap logic ---
      //
      // Find the base recipe ingredient for this category
      final baseRow = result
          .where((r) => r.source == 'drink_recipe' && r.category == targetCategory)
          .firstOrNull;

      // Guard: if no embedded ingredient rows on this addon item, we can't
      // determine whether it's a swap or the base → fallback to API.
      if (addonItem.ingredients.isEmpty) continue;

      final addonIngId  = addonItem.ingredients.first.orgIngredientId;
      final baseIngId   = baseRow?.orgIngredientId;

      // If the addon ingredient IS the base ingredient → no swap, skip
      final isBase = baseIngId != null &&
          addonIngId != null &&
          baseIngId == addonIngId;

      if (!isBase && baseRow != null) {
        final replIng = addonItem.ingredients.first;
        // Replace matching base rows in-place (may be multiple if present)
        for (int i = 0; i < result.length; i++) {
          if (result[i].source == 'drink_recipe' &&
              result[i].category == targetCategory) {
            result[i] = result[i].copyWith(
              name:   replIng.ingredientName,
              unit:   replIng.ingredientUnit,
              source: 'addon_swap:${addonItem.name}',
              // quantity stays the same — the swap inherits the base qty
            );
          }
        }
      }
      // Skip the additive logic for swap types
      continue;
    }

    // --- Additive addon ---
    // Guard: if this addon has no ingredient data at all, fall back to API.
    // (An addon having zero ingredients is valid — e.g. a flavour shot with
    //  no stock impact.  We only fall back if the list is null/missing, which
    //  means the backend didn't include the field at all.)
    for (final ing in addonItem.ingredients) {
      result.add(RecipeIngredient(
        orgIngredientId: ing.orgIngredientId,
        name:     ing.ingredientName,
        unit:     ing.ingredientUnit,
        quantity: ing.quantityUsed * addonQty,
        source:   'addon',
        category: 'general',
      ));
    }
  }

  // ── 3. Optional fields ────────────────────────────────────────────────────
  //
  //   Only adds a row if the field has a mapped ingredient (name + unit + qty).
  //   Fields without an ingredient mapping are purely cosmetic and produce no row.

  for (final so in optionals) {
    final field = item.optionalFields
        .where((f) => f.id == so.optionalFieldId)
        .firstOrNull;
    if (field == null) continue;

    if (field.ingredientName != null &&
        field.ingredientUnit  != null &&
        field.quantityUsed    != null) {
      result.add(RecipeIngredient(
        orgIngredientId: field.orgIngredientId,
        name:     field.ingredientName!,
        unit:     field.ingredientUnit!,
        quantity: field.quantityUsed!,
        source:   'optional:${field.name}',
        category: 'general',
      ));
    }
  }

  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
//  RecipeApi — tries local computation first, network as fallback
// ─────────────────────────────────────────────────────────────────────────────
class RecipeApi {
  final DioClient _c;
  RecipeApi(this._c);

  /// Returns a recipe ingredient list for the given item + selections.
  ///
  /// Strategy:
  ///   1. If [menuItem] has embedded recipe data AND all selected addons
  ///      have embedded ingredient data → compute locally (works offline).
  ///   2. Otherwise → call POST /orders/preview-recipe.
  ///
  /// [menuItem] and [allAddonItems] are optional — pass them to enable the
  /// offline path.  If omitted the API call is always used.
  Future<List<RecipeIngredient>> preview({
    required String           menuItemId,
    String?                   sizeLabel,
    required List<SelectedAddon>    addons,
    required List<SelectedOptional> optionals,
    // Optional: supply for offline-capable local computation
    MenuItem?         menuItem,
    List<AddonItem>?  allAddonItems,
  }) async {
    // ── Attempt local computation ─────────────────────────────────────────
    if (menuItem != null && allAddonItems != null) {
      final local = computeRecipeLocally(
        item:        menuItem,
        sizeLabel:   sizeLabel,
        addons:      addons,
        optionals:   optionals,
        allAddons:   allAddonItems,
      );
      if (local != null) return local;
      // local == null means data was insufficient → fall through to network
    }

    // ── Network fallback ──────────────────────────────────────────────────
    final res = await _c.dio.post('/orders/preview-recipe', data: {
      'menu_item_id': menuItemId,
      if (sizeLabel != null) 'size_label': sizeLabel,
      'addons': addons
          .map((a) => {'addon_item_id': a.addonItemId, 'quantity': a.quantity})
          .toList(),
      'optional_field_ids': optionals.map((o) => o.optionalFieldId).toList(),
    });

    return (res.data as List)
        .map((e) =>
            RecipeIngredient.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final recipeApiProvider =
    Provider<RecipeApi>((ref) => RecipeApi(ref.watch(dioClientProvider)));  