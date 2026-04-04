class Category {
  final String  id;
  final String  name;
  final String? imageUrl;
  final int     displayOrder;
  final bool    isActive;

  const Category({
    required this.id, required this.name, this.imageUrl,
    required this.displayOrder, required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'], name: j['name'], imageUrl: j['image_url'],
    displayOrder: j['display_order'], isActive: j['is_active'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'image_url': imageUrl,
    'display_order': displayOrder, 'is_active': isActive,
  };
}

class ItemSize {
  final String id;
  final String label;
  final int    price;
  const ItemSize({required this.id, required this.label, required this.price});

  factory ItemSize.fromJson(Map<String, dynamic> j) =>
      ItemSize(id: j['id'], label: j['label'], price: j['price_override'] ?? 0);

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'price_override': price};
}

class AddonItem {
  final String id;
  final String orgId;
  final String name;
  final String addonType;
  final int    defaultPrice;
  final bool   isActive;
  final int    displayOrder;

  const AddonItem({
    required this.id, required this.orgId, required this.name,
    required this.addonType, required this.defaultPrice,
    required this.isActive, required this.displayOrder,
  });

  factory AddonItem.fromJson(Map<String, dynamic> j) => AddonItem(
    id: j['id'], orgId: j['org_id'], name: j['name'],
    addonType: j['addon_type'] ?? '', defaultPrice: j['default_price'] ?? 0,
    isActive: j['is_active'] ?? true, displayOrder: j['display_order'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'name': name, 'addon_type': addonType,
    'default_price': defaultPrice, 'is_active': isActive, 'display_order': displayOrder,
  };
}

class MenuItemAddonSlot {
  final String  id;
  final String  itemId;
  final String  addonType;
  final bool    isRequired;
  final int     minSelections;
  final int?    maxSelections;
  final int     displayOrder;

  String get displayName => addonType
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  const MenuItemAddonSlot({
    required this.id, required this.itemId, required this.addonType,
    required this.isRequired, required this.minSelections, this.maxSelections,
    required this.displayOrder,
  });

  factory MenuItemAddonSlot.fromJson(Map<String, dynamic> j) => MenuItemAddonSlot(
    id: j['id'], itemId: j['menu_item_id'], addonType: j['addon_type'] ?? '',
    isRequired: j['is_required'] ?? false,
    minSelections: j['min_selections'] ?? 0,
    maxSelections: j['max_selections'],
    displayOrder: j['display_order'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'menu_item_id': itemId, 'addon_type': addonType,
    'is_required': isRequired, 'min_selections': minSelections,
    'max_selections': maxSelections, 'display_order': displayOrder,
  };
}

class MenuItemAddonOverride {
  final String  id;
  final String  itemId;
  final String  addonItemId;
  final String? sizeLabel;
  final double  quantityUsed;

  const MenuItemAddonOverride({
    required this.id, required this.itemId, required this.addonItemId,
    this.sizeLabel, required this.quantityUsed,
  });

  factory MenuItemAddonOverride.fromJson(Map<String, dynamic> j) => MenuItemAddonOverride(
    id: j['id'], itemId: j['menu_item_id'], addonItemId: j['addon_item_id'],
    sizeLabel: j['size_label'],
    quantityUsed: (j['quantity_used'] ?? 0).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'menu_item_id': itemId, 'addon_item_id': addonItemId,
    'size_label': sizeLabel, 'quantity_used': quantityUsed,
  };
}

class MenuItem {
  final String                id;
  final String                orgId;
  final String?               categoryId;
  final String                name;
  final String?               description;
  final String?               imageUrl;
  final int                   basePrice;
  final bool                  isActive;
  final int                   displayOrder;
  final List<ItemSize>        sizes;
  final List<MenuItemAddonSlot> addonSlots;
  final List<MenuItemAddonOverride> addonOverrides;

  const MenuItem({
    required this.id, required this.orgId, this.categoryId,
    required this.name, this.description, this.imageUrl,
    required this.basePrice, required this.isActive, required this.displayOrder,
    this.sizes = const [], this.addonSlots = const [], this.addonOverrides = const [],
  });

  int priceForSize(String? label) {
    if (label == null || sizes.isEmpty) return basePrice;
    return sizes.firstWhere((s) => s.label == label,
        orElse: () => ItemSize(id: '', label: '', price: basePrice)).price;
  }

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id: j['id'], orgId: j['org_id'], categoryId: j['category_id'],
    name: j['name'], description: j['description'], imageUrl: j['image_url'],
    basePrice: j['base_price'], isActive: j['is_active'],
    displayOrder: j['display_order'],
    sizes: (j['sizes'] as List? ?? []).map((s) => ItemSize.fromJson(s)).toList(),
    addonSlots: (j['addon_slots'] as List? ?? [])
        .map((g) => MenuItemAddonSlot.fromJson(g)).toList(),
    addonOverrides: (j['addon_overrides'] as List? ?? [])
        .map((o) => MenuItemAddonOverride.fromJson(o)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'category_id': categoryId, 'name': name,
    'description': description, 'image_url': imageUrl,
    'base_price': basePrice, 'is_active': isActive, 'display_order': displayOrder,
    'sizes': sizes.map((s) => s.toJson()).toList(),
    'addon_slots': addonSlots.map((g) => g.toJson()).toList(),
    'addon_overrides': addonOverrides.map((o) => o.toJson()).toList(),
  };
}
