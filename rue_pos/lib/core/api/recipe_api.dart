import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';
import 'client.dart';

class RecipeIngredient {
  final String name;
  final String unit;
  final double quantity;
  final String source; // drink_recipe | addon_base | addon_override

  const RecipeIngredient({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.source,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        name: j['ingredient_name'] as String,
        unit: j['unit'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        source: j['source'] as String,
      );

  bool get isBase => source == 'drink_recipe';
  bool get isAddon => source == 'addon_base' || source == 'addon_override';
  bool get isOverride => source == 'addon_override';
}

class RecipeApi {
  final DioClient _c;
  RecipeApi(this._c);

  /// Resolves the ingredient deduction list for a given item + size + addons,
  /// exactly as the order handler would, without creating an order.
  /// Uses the same combo-rule logic as create_order.
  Future<List<RecipeIngredient>> preview({
    required String menuItemId,
    String? sizeLabel,
    required List<SelectedAddon> addons,
  }) async {
    final res = await _c.dio.post('/orders/preview-recipe', data: {
      'menu_item_id': menuItemId,
      if (sizeLabel != null) 'size_label': sizeLabel,
      'addons': addons
          .map((a) => {
                'addon_item_id': a.addonItemId,
                'quantity': a.quantity,
              })
          .toList(),
    });
    return (res.data as List)
        .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final recipeApiProvider =
    Provider<RecipeApi>((ref) => RecipeApi(ref.watch(dioClientProvider)));
