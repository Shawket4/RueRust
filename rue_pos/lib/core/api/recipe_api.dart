import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';
import 'client.dart';

class RecipeIngredient {
  final String name;
  final String unit;
  final double quantity;
  final String source; // drink_recipe | addon | optional:FieldName

  const RecipeIngredient({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.source,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) =>
      RecipeIngredient(
        name:     j['ingredient_name'] as String,
        unit:     j['unit']            as String,
        quantity: (j['quantity'] as num).toDouble(),
        source:   j['source']          as String,
      );

  bool get isBase     => source == 'drink_recipe';
  bool get isAddon    => source == 'addon';
  bool get isOptional => source.startsWith('optional');

  String get sourceLabel {
    if (isBase)     return 'base';
    if (isAddon)    return 'addon';
    if (isOptional) {
      final parts = source.split(':');
      return parts.length > 1 ? parts[1] : 'optional';
    }
    return source;
  }
}

class RecipeApi {
  final DioClient _c;
  RecipeApi(this._c);

  Future<List<RecipeIngredient>> preview({
    required String             menuItemId,
    String?                     sizeLabel,
    required List<SelectedAddon>    addons,
    required List<SelectedOptional> optionals,
  }) async {
    final res = await _c.dio.post('/orders/preview-recipe', data: {
      'menu_item_id': menuItemId,
      if (sizeLabel != null) 'size_label': sizeLabel,
      'addons': addons
          .map((a) => {'addon_item_id': a.addonItemId, 'quantity': a.quantity})
          .toList(),
      'optional_field_ids': optionals.map((o) => o.optionalFieldId).toList(),
    });
    return (res.data as List)
        .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final recipeApiProvider =
    Provider<RecipeApi>((ref) => RecipeApi(ref.watch(dioClientProvider)));
