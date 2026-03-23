class Category {
  final String id;
  final String name;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;

  const Category(
      {required this.id,
      required this.name,
      this.imageUrl,
      required this.displayOrder,
      required this.isActive});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
      id: j['id'],
      name: j['name'],
      imageUrl: j['image_url'],
      displayOrder: j['display_order'],
      isActive: j['is_active']);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'display_order': displayOrder,
        'is_active': isActive
      };
}

class ItemSize {
  final String id;
  final String label;
  final int price;
  const ItemSize({required this.id, required this.label, required this.price});

  factory ItemSize.fromJson(Map<String, dynamic> j) =>
      ItemSize(id: j['id'], label: j['label'], price: j['price_override'] ?? 0);

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'price_override': price};
}

class DrinkOptionItem {
  final String id;
  final String addonItemId;
  final String name;
  final int price;
  const DrinkOptionItem(
      {required this.id,
      required this.addonItemId,
      required this.name,
      required this.price});

  factory DrinkOptionItem.fromJson(Map<String, dynamic> j) => DrinkOptionItem(
      id: j['id'],
      addonItemId: j['addon_item_id'],
      name: j['name'],
      price: (j['price_override'] ?? j['default_price'] ?? 0) as int);

  Map<String, dynamic> toJson() => {
        'id': id,
        'addon_item_id': addonItemId,
        'name': name,
        'price_override': price,
        'default_price': price
      };
}

class DrinkOptionGroup {
  final String id;
  final String groupType;
  final bool isRequired;
  final bool isMultiSelect;
  final List<DrinkOptionItem> items;

  String get displayName => groupType
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  const DrinkOptionGroup(
      {required this.id,
      required this.groupType,
      required this.isRequired,
      required this.isMultiSelect,
      required this.items});

  factory DrinkOptionGroup.fromJson(Map<String, dynamic> j) => DrinkOptionGroup(
      id: j['id'],
      groupType: j['group_type'] ?? '',
      isRequired: (j['is_required'] ?? false) as bool,
      isMultiSelect: (j['selection_type'] ?? 'single') == 'multi',
      items: (j['items'] as List? ?? [])
          .map((i) => DrinkOptionItem.fromJson(i))
          .toList());

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_type': groupType,
        'is_required': isRequired,
        'selection_type': isMultiSelect ? 'multi' : 'single',
        'items': items.map((i) => i.toJson()).toList()
      };
}

class MenuItem {
  final String id;
  final String orgId;
  final String? categoryId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int basePrice;
  final bool isActive;
  final int displayOrder;
  final List<ItemSize> sizes;
  final List<DrinkOptionGroup> optionGroups;

  const MenuItem(
      {required this.id,
      required this.orgId,
      this.categoryId,
      required this.name,
      this.description,
      this.imageUrl,
      required this.basePrice,
      required this.isActive,
      required this.displayOrder,
      this.sizes = const [],
      this.optionGroups = const []});

  int priceForSize(String? label) {
    if (label == null || sizes.isEmpty) return basePrice;
    return sizes
        .firstWhere((s) => s.label == label,
            orElse: () => ItemSize(id: '', label: '', price: basePrice))
        .price;
  }

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
      id: j['id'],
      orgId: j['org_id'],
      categoryId: j['category_id'],
      name: j['name'],
      description: j['description'],
      imageUrl: j['image_url'],
      basePrice: j['base_price'],
      isActive: j['is_active'],
      displayOrder: j['display_order'],
      sizes:
          (j['sizes'] as List? ?? []).map((s) => ItemSize.fromJson(s)).toList(),
      optionGroups: (j['option_groups'] as List? ?? [])
          .map((g) => DrinkOptionGroup.fromJson(g))
          .toList());

  Map<String, dynamic> toJson() => {
        'id': id,
        'org_id': orgId,
        'category_id': categoryId,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'base_price': basePrice,
        'is_active': isActive,
        'display_order': displayOrder,
        'sizes': sizes.map((s) => s.toJson()).toList(),
        'option_groups': optionGroups.map((g) => g.toJson()).toList()
      };
}
