// ── Category ──────────────────────────────────────────────────
class Category {
  final String  id;
  final String  name;
  final String? imageUrl;
  final int     displayOrder;
  final bool    isActive;

  const Category({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.displayOrder,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id:           j['id']            as String,
    name:         j['name']          as String,
    imageUrl:     j['image_url']     as String?,
    displayOrder: j['display_order'] as int,
    isActive:     j['is_active']     as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'image_url': imageUrl,
    'display_order': displayOrder, 'is_active': isActive,
  };
}

// ── ItemSize ──────────────────────────────────────────────────
class ItemSize {
  final String id;
  final String label;
  final int    price;

  const ItemSize({required this.id, required this.label, required this.price});

  factory ItemSize.fromJson(Map<String, dynamic> j) => ItemSize(
    id:    j['id']             as String,
    label: j['label']          as String,
    price: (j['price_override'] ?? 0) as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'label': label, 'price_override': price,
  };
}

// ── MenuItemRecipe ─────────────────────────────────────────────
/// One ingredient row from menu_item_recipes, embedded on MenuItem.
/// Used for offline recipe preview computation.
class MenuItemRecipe {
  final String? orgIngredientId;
  final double  quantityUsed;
  final String  ingredientName;
  final String  ingredientUnit;
  final String  category;   // e.g. 'milk', 'coffee_bean', 'general'
  final String? sizeLabel;

  const MenuItemRecipe({
    this.orgIngredientId,
    required this.quantityUsed,
    required this.ingredientName,
    required this.ingredientUnit,
    required this.category,
    this.sizeLabel,
  });

  factory MenuItemRecipe.fromJson(Map<String, dynamic> j) => MenuItemRecipe(
    orgIngredientId: j['org_ingredient_id'] as String?,
    quantityUsed:    double.parse(j['quantity_used'].toString()),
    ingredientName:  j['ingredient_name']   as String,
    ingredientUnit:  j['ingredient_unit']   as String,
    category:        (j['category'] ?? 'general') as String,
    sizeLabel:       j['size_label']        as String?,
  );

  Map<String, dynamic> toJson() => {
    'org_ingredient_id': orgIngredientId,
    'quantity_used':     quantityUsed,
    'ingredient_name':   ingredientName,
    'ingredient_unit':   ingredientUnit,
    'category':          category,
    'size_label':        sizeLabel,
  };
}

// ── AddonItemIngredient ────────────────────────────────────────
/// One ingredient row from addon_item_ingredients, embedded on AddonItem.
/// Used for offline recipe preview computation.
class AddonItemIngredient {
  final String? orgIngredientId;
  final double  quantityUsed;
  final String  ingredientName;
  final String  ingredientUnit;

  const AddonItemIngredient({
    this.orgIngredientId,
    required this.quantityUsed,
    required this.ingredientName,
    required this.ingredientUnit,
  });

  factory AddonItemIngredient.fromJson(Map<String, dynamic> j) =>
      AddonItemIngredient(
        orgIngredientId: j['org_ingredient_id'] as String?,
  quantityUsed:    double.parse(j['quantity_used'].toString()),
        ingredientName:  j['ingredient_name']   as String,
        ingredientUnit:  j['ingredient_unit']   as String,
      );

  Map<String, dynamic> toJson() => {
    'org_ingredient_id': orgIngredientId,
    'quantity_used':     quantityUsed,
    'ingredient_name':   ingredientName,
    'ingredient_unit':   ingredientUnit,
  };
}

// ── AddonItem ─────────────────────────────────────────────────
class AddonItem {
  final String  id;
  final String  name;
  final String  addonType;
  final int     defaultPrice;
  final bool    isActive;
  final int     displayOrder;
  final String? primaryIngredientId;
  /// Ingredient rows embedded from the backend (populated when full=true).
  /// Empty list means either no ingredients or backend version doesn't support it.
  final List<AddonItemIngredient> ingredients;

  const AddonItem({
    required this.id,
    required this.name,
    required this.addonType,
    required this.defaultPrice,
    required this.isActive,
    required this.displayOrder,
    this.primaryIngredientId,
    this.ingredients = const [],
  });

  factory AddonItem.fromJson(Map<String, dynamic> j) => AddonItem(
    id:                   j['id']                     as String,
    name:                 j['name']                   as String,
    addonType:            j['addon_type']             as String,
    defaultPrice:         (j['default_price'] ?? 0)   as int,
    isActive:             (j['is_active']     ?? true) as bool,
    displayOrder:         (j['display_order'] ?? 0)   as int,
    primaryIngredientId:  j['primary_ingredient_id']  as String?,
    ingredients: (j['ingredients'] as List? ?? [])
        .map((i) => AddonItemIngredient.fromJson(i as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'addon_type': addonType,
    'default_price': defaultPrice, 'is_active': isActive,
    'display_order': displayOrder,
    'primary_ingredient_id': primaryIngredientId,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
  };
}

// ── AddonSlot ─────────────────────────────────────────────────
class AddonSlot {
  final String  id;
  final String  menuItemId;
  final String  addonType;
  final String? label;
  final bool    isRequired;
  final int     minSelections;
  final int?    maxSelections;
  final int     displayOrder;

  const AddonSlot({
    required this.id,
    required this.menuItemId,
    required this.addonType,
    this.label,
    required this.isRequired,
    required this.minSelections,
    this.maxSelections,
    required this.displayOrder,
  });

  String get displayName {
    if (label != null && label!.isNotEmpty) return label!;
    return addonType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  factory AddonSlot.fromJson(Map<String, dynamic> j) => AddonSlot(
    id:            j['id']             as String,
    menuItemId:    j['menu_item_id']   as String,
    addonType:     j['addon_type']     as String,
    label:         j['label']          as String?,
    isRequired:    (j['is_required']   ?? false) as bool,
    minSelections: (j['min_selections'] ?? 0) as int,
    maxSelections: j['max_selections'] as int?,
    displayOrder:  (j['display_order'] ?? 0) as int,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'menu_item_id': menuItemId, 'addon_type': addonType,
    'label': label, 'is_required': isRequired,
    'min_selections': minSelections, 'max_selections': maxSelections,
    'display_order': displayOrder,
  };
}

// ── OptionalField ─────────────────────────────────────────────
class OptionalField {
  final String  id;
  final String  menuItemId;
  final String  name;
  final int     price;
  final String? orgIngredientId;
  final String? ingredientName;
  final String? ingredientUnit;
  final double? quantityUsed;
  final String? sizeLabel;
  final int     displayOrder;
  final bool    isActive;

  const OptionalField({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    this.orgIngredientId,
    this.ingredientName,
    this.ingredientUnit,
    this.quantityUsed,
    this.sizeLabel,
    required this.displayOrder,
    required this.isActive,
  });

  bool get hasIngredient => ingredientName != null;
  bool get isFree        => price == 0;

  factory OptionalField.fromJson(Map<String, dynamic> j) => OptionalField(
    id:               j['id']               as String,
    menuItemId:       j['menu_item_id']      as String,
    name:             j['name']              as String,
    price:            (j['price']            ?? 0) as int,
    orgIngredientId:  j['org_ingredient_id'] as String?,
    ingredientName:   j['ingredient_name']   as String?,
    ingredientUnit:   j['ingredient_unit']   as String?,
    quantityUsed:     j['quantity_used'] != null
        ? double.tryParse(j['quantity_used'].toString()) : null,
    sizeLabel:        j['size_label']        as String?,
    displayOrder:     (j['display_order']    ?? 0) as int,
    isActive:         (j['is_active']        ?? true) as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'menu_item_id': menuItemId, 'name': name,
    'price': price, 'org_ingredient_id': orgIngredientId,
    'ingredient_name': ingredientName, 'ingredient_unit': ingredientUnit,
    'quantity_used': quantityUsed, 'size_label': sizeLabel,
    'display_order': displayOrder, 'is_active': isActive,
  };
}

// ── MenuItem ──────────────────────────────────────────────────
class MenuItem {
  final String          id;
  final String          orgId;
  final String?         categoryId;
  final String          name;
  final String?         description;
  final String?         imageUrl;
  final int             basePrice;
  final bool            isActive;
  final int             displayOrder;
  final List<ItemSize>  sizes;
  final List<AddonSlot> addonSlots;
  final List<OptionalField> optionalFields;
  final String?         defaultMilkAddonId;
  /// Recipe ingredient rows per size, embedded when backend returns full=true.
  /// Used for offline recipe preview. Empty if backend doesn't support it yet.
  final List<MenuItemRecipe> recipes;

  const MenuItem({
    required this.id,
    required this.orgId,
    this.categoryId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.basePrice,
    required this.isActive,
    required this.displayOrder,
    this.sizes          = const [],
    this.addonSlots     = const [],
    this.optionalFields = const [],
    this.defaultMilkAddonId,
    this.recipes        = const [],
  });

  int priceForSize(String? label) {
    if (label == null || sizes.isEmpty) return basePrice;
    return sizes
        .firstWhere(
          (s) => s.label == label,
          orElse: () => ItemSize(id: '', label: '', price: basePrice),
        )
        .price;
  }

  /// True if this item has enough embedded recipe data to compute offline.
  bool get hasLocalRecipes => recipes.isNotEmpty;

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id:           j['id']            as String,
    orgId:        j['org_id']        as String,
    categoryId:   j['category_id']   as String?,
    name:         j['name']          as String,
    description:  j['description']   as String?,
    imageUrl:     j['image_url']     as String?,
    basePrice:    j['base_price']    as int,
    isActive:     j['is_active']     as bool,
    displayOrder: j['display_order'] as int,
    sizes: (j['sizes'] as List? ?? [])
        .map((s) => ItemSize.fromJson(s as Map<String, dynamic>))
        .toList(),
    addonSlots: (j['addon_slots'] as List? ?? [])
        .map((s) => AddonSlot.fromJson(s as Map<String, dynamic>))
        .toList(),
    optionalFields: (j['optional_fields'] as List? ?? [])
        .map((o) => OptionalField.fromJson(o as Map<String, dynamic>))
        .toList(),
    defaultMilkAddonId: j['default_milk_addon_id'] as String?,
    recipes: (j['recipes'] as List? ?? [])
        .map((r) => MenuItemRecipe.fromJson(r as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'category_id': categoryId,
    'name': name, 'description': description, 'image_url': imageUrl,
    'base_price': basePrice, 'is_active': isActive,
    'display_order': displayOrder,
    'sizes':          sizes.map((s) => s.toJson()).toList(),
    'addon_slots':    addonSlots.map((s) => s.toJson()).toList(),
    'optional_fields': optionalFields.map((o) => o.toJson()).toList(),
    'default_milk_addon_id': defaultMilkAddonId,
    'recipes':        recipes.map((r) => r.toJson()).toList(),
  };
}