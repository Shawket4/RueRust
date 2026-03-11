class Category {
  final String id;
  final String name;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.displayOrder,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        imageUrl: j['image_url'],
        displayOrder: j['display_order'],
        isActive: j['is_active'],
      );
}

class ItemSize {
  final String id;
  final String label;
  final int price;

  const ItemSize({required this.id, required this.label, required this.price});

  factory ItemSize.fromJson(Map<String, dynamic> j) => ItemSize(
        id: j['id'],
        label: j['label'],
        price: j['price'],
      );
}

class DrinkOptionItem {
  final String id;
  final String name;
  final int priceModifier;

  const DrinkOptionItem({
    required this.id,
    required this.name,
    required this.priceModifier,
  });

  factory DrinkOptionItem.fromJson(Map<String, dynamic> j) => DrinkOptionItem(
        id: j['id'],
        name: j['name'],
        priceModifier: j['price_modifier'] ?? 0,
      );
}

class DrinkOptionGroup {
  final String id;
  final String name;
  final bool isRequired;
  final bool isMultiSelect;
  final List<DrinkOptionItem> items;

  const DrinkOptionGroup({
    required this.id,
    required this.name,
    required this.isRequired,
    required this.isMultiSelect,
    required this.items,
  });

  factory DrinkOptionGroup.fromJson(Map<String, dynamic> j) => DrinkOptionGroup(
        id: j['id'],
        name: j['name'],
        isRequired: j['is_required'] ?? false,
        isMultiSelect: j['is_multi_select'] ?? false,
        items: (j['items'] as List? ?? [])
            .map((i) => DrinkOptionItem.fromJson(i))
            .toList(),
      );
}

class AddonItem {
  final String id;
  final String name;
  final int defaultPrice;
  final String? addonType;

  const AddonItem({
    required this.id,
    required this.name,
    required this.defaultPrice,
    this.addonType,
  });

  factory AddonItem.fromJson(Map<String, dynamic> j) => AddonItem(
        id: j['id'],
        name: j['name'],
        defaultPrice: j['default_price'],
        addonType: j['addon_type'],
      );
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
    required this.sizes,
    required this.optionGroups,
  });

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
        sizes: (j['sizes'] as List? ?? [])
            .map((s) => ItemSize.fromJson(s))
            .toList(),
        optionGroups: (j['option_groups'] as List? ?? [])
            .map((g) => DrinkOptionGroup.fromJson(g))
            .toList(),
      );

  int priceForSize(String? sizeLabel) {
    if (sizeLabel == null || sizes.isEmpty) return basePrice;
    final s = sizes.where((s) => s.label == sizeLabel).firstOrNull;
    return s?.price ?? basePrice;
  }
}
