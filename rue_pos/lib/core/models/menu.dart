// ── Category ──────────────────────────────────────────────────
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
        id: j['id'] as String,
        name: j['name'] as String,
        imageUrl: j['image_url'] as String?,
        displayOrder: j['display_order'] as int,
        isActive: j['is_active'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'display_order': displayOrder,
        'is_active': isActive,
      };
}

// ── ItemSize ──────────────────────────────────────────────────
class ItemSize {
  final String id;
  final String label;
  final int price;

  const ItemSize({required this.id, required this.label, required this.price});

  factory ItemSize.fromJson(Map<String, dynamic> j) => ItemSize(
        id: j['id'] as String,
        label: j['label'] as String,
        price: (j['price_override'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'price_override': price,
      };
}

// ── AddonItem ─────────────────────────────────────────────────
// Represents a global addon (Oat Milk, Honey, Vanilla Syrup, etc.)
// type is now free text — not restricted to the 3 legacy values.
class AddonItem {
  final String id;
  final String name;
  final String type; // e.g. 'milk_type', 'coffee_type', 'extra', 'sweetener'
  final int defaultPrice;
  final bool isActive;
  final int displayOrder;

  const AddonItem({
    required this.id,
    required this.name,
    required this.type,
    required this.defaultPrice,
    required this.isActive,
    required this.displayOrder,
  });

  factory AddonItem.fromJson(Map<String, dynamic> j) => AddonItem(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        defaultPrice: (j['default_price'] ?? 0) as int,
        isActive: (j['is_active'] ?? true) as bool,
        displayOrder: (j['display_order'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'default_price': defaultPrice,
        'is_active': isActive,
        'display_order': displayOrder,
      };
}

// ── AddonSlot ─────────────────────────────────────────────────
// Defines a per-drink addon selection group.
// The 3 global types (coffee_type, milk_type, extra) are always available
// on every drink. Slots add EXTRA groups or configure rules for a global
// type on a specific drink.
//
// The POS uses slots to:
//   1. Know which addon types this drink has custom rules for
//   2. Enforce required / min-max selection constraints
//   3. Render custom slot labels (e.g. "Sweetness Level" instead of "sweetener")
class AddonSlot {
  final String id;
  final String menuItemId;
  final String addonType; // matches AddonItem.type
  final String? label; // optional display override
  final bool isRequired;
  final int minSelections;
  final int? maxSelections; // null = unlimited
  final int displayOrder;

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

  // Human-readable display name: use label if set, otherwise derive from type.
  String get displayName {
    if (label != null && label!.isNotEmpty) return label!;
    return addonType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  factory AddonSlot.fromJson(Map<String, dynamic> j) => AddonSlot(
        id: j['id'] as String,
        menuItemId: j['menu_item_id'] as String,
        addonType: j['addon_type'] as String,
        label: j['label'] as String?,
        isRequired: (j['is_required'] ?? false) as bool,
        minSelections: (j['min_selections'] ?? 0) as int,
        maxSelections: j['max_selections'] as int?,
        displayOrder: (j['display_order'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'menu_item_id': menuItemId,
        'addon_type': addonType,
        'label': label,
        'is_required': isRequired,
        'min_selections': minSelections,
        'max_selections': maxSelections,
        'display_order': displayOrder,
      };
}

// ── MenuItem ──────────────────────────────────────────────────
// addonSlots: only slots fetched from menu_item_addon_slots.
// The global addon types are loaded separately by the menu notifier
// and merged in the POS UI.
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
  final List<AddonSlot> addonSlots;

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
    this.sizes = const [],
    this.addonSlots = const [],
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

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'] as String,
        orgId: j['org_id'] as String,
        categoryId: j['category_id'] as String?,
        name: j['name'] as String,
        description: j['description'] as String?,
        imageUrl: j['image_url'] as String?,
        basePrice: j['base_price'] as int,
        isActive: j['is_active'] as bool,
        displayOrder: j['display_order'] as int,
        sizes: (j['sizes'] as List? ?? [])
            .map((s) => ItemSize.fromJson(s as Map<String, dynamic>))
            .toList(),
        // Slots are optionally embedded in the menu response (when fetched via
        // GET /menu-items/:id) or loaded separately.
        addonSlots: (j['addon_slots'] as List? ?? [])
            .map((s) => AddonSlot.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

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
        'addon_slots': addonSlots.map((s) => s.toJson()).toList(),
      };
}
