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

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) =>
      RecipeIngredient(
        name:     j['ingredient_name'],
        unit:     j['unit'],
        quantity: (j['quantity'] as num).toDouble(),
        source:   j['source'],
      );

  bool get isBase => source == 'drink_recipe';
}

class RecipeApi {
  final DioClient _c;
  RecipeApi(this._c);

  /// Resolves the ingredient list for a given item + size + selected addons,
  /// exactly as the order handler would, but without creating an order.
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
                'addon_item_id':        a.addonItemId,
                'drink_option_item_id': a.drinkOptionItemId,
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