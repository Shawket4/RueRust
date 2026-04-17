import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/menu_api.dart';
import '../../../core/api/recipe_api.dart';
import '../../../core/models/cart.dart';
import '../../../core/models/menu.dart';
import '../../../core/providers/cart_notifier.dart';
import '../../../core/providers/menu_notifier.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../shared/widgets/app_button.dart';
import '../helpers/payment_helpers.dart';
import '../helpers/recipe_engine.dart';
import 'addon_card.dart';
import 'optional_fields_card.dart';
import 'recipe_sheet.dart';
import 'shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ITEM DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class ItemDetailSheet extends ConsumerStatefulWidget {
  final MenuItem item;
  final int? editIndex;
  final CartItem? existingItem;

  const ItemDetailSheet({
    super.key,
    required this.item,
    this.editIndex,
    this.existingItem,
  });

  static void show(BuildContext ctx, MenuItem item,
          {int? editIndex, CartItem? existingItem}) =>
      showModalBottomSheet(
          context: ctx,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => ItemDetailSheet(
              item: item, editIndex: editIndex, existingItem: existingItem));

  @override
  ConsumerState<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends ConsumerState<ItemDetailSheet> {
  String? _selectedSize;
  int _qty = 1;

  // Single-select slots: slotId → addonItemId
  final Map<String, String> _single = {};
  // Multi-select slots:  slotId → { addonItemId → quantity }
  final Map<String, Map<String, int>> _multi = {};
  // Unslotted multi-select extras: addonType → { addonItemId → quantity }
  final Map<String, Map<String, int>> _extras = {};
  // Unslotted single-select extras: addonType → addonItemId (e.g. milk_type)
  final Map<String, String> _extrasSingle = {};
  
  // Base prices for swap addons (milk_type, coffee_type) so we only charge the difference
  final Map<String, int> _baseSwapPrices = {};

  /// Types that should be single-select (pick one, no qty stepper)
  static const _singleSelectTypes = {'milk_type'};

  // Optional fields state
  late List<OptionalField> _optionalFields;
  final Set<String> _selectedOptionals = {};

  // Recipe preview state
  bool _recipeLoading = false;

  bool get _isEdit => widget.editIndex != null && widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (widget.item.sizes.isNotEmpty) {
      _selectedSize = widget.item.sizes.first.label;
    }

    _optionalFields = widget.item.optionalFields.where((f) => f.isActive).toList();
    _initBaseMilk();

    // Pre-populate from existing cart item when editing
    if (_isEdit) {
      final existing = widget.existingItem!;
      _selectedSize = existing.sizeLabel;
      _qty = existing.quantity;

      final allAddons = ref.read(menuProvider).allAddons;
      final slottedTypes =
          widget.item.addonSlots.map((s) => s.addonType).toSet();
      for (final so in existing.optionals) {
        _selectedOptionals.add(so.optionalFieldId);
      }

      for (final sa in existing.addons) {
        final addon = allAddons.where((a) => a.id == sa.addonItemId);
        if (addon.isEmpty) continue;
        final addonType = addon.first.addonType;

        final matchingSlot =
            widget.item.addonSlots.where((s) => s.addonType == addonType);

        if (matchingSlot.isNotEmpty) {
          final slot = matchingSlot.first;
          final isMulti = (slot.maxSelections ?? 2) > 1;
          if (isMulti) {
            _multi.putIfAbsent(slot.id, () => {})[sa.addonItemId] = sa.quantity;
          } else {
            _single[slot.id] = sa.addonItemId;
          }
        } else if (!slottedTypes.contains(addonType)) {
          // Goes into per-type extras (single or multi depending on type)
          if (_singleSelectTypes.contains(addonType)) {
            _extrasSingle[addonType] = sa.addonItemId;
          } else {
            _extras.putIfAbsent(addonType, () => {})[sa.addonItemId] =
                sa.quantity;
          }
        }
      }
    }
  }

  // ── Pricing ───────────────────────────────────────────────

  int get _unitPrice => widget.item.priceForSize(_selectedSize);

  int get _optionalsTotal => _optionalFields
      .where((f) => _selectedOptionals.contains(f.id))
      .fold(0, (s, f) => s + f.price);

  int _adjustedPrice(AddonItem a) {
    if (a.addonType == 'milk_type' || a.addonType == 'coffee_type') {
      final base = _baseSwapPrices[a.addonType] ?? 0;
      final diff = a.defaultPrice - base;
      return diff > 0 ? diff : 0;
    }
    return a.defaultPrice;
  }

  int get _addonsTotal {
    final allAddons = ref.read(menuProvider).allAddons;
    int t = 0;

    for (final aId in _single.values) {
      final matches = allAddons.where((a) => a.id == aId);
      if (matches.isNotEmpty) t += _adjustedPrice(matches.first);
    }
    for (final qtyMap in _multi.values) {
      for (final entry in qtyMap.entries) {
        final matches = allAddons.where((a) => a.id == entry.key);
        if (matches.isNotEmpty) t += _adjustedPrice(matches.first) * entry.value;
      }
    }
    for (final typeMap in _extras.values) {
      for (final entry in typeMap.entries) {
        final matches = allAddons.where((a) => a.id == entry.key);
        if (matches.isNotEmpty) t += _adjustedPrice(matches.first) * entry.value;
      }
    }
    // Single-select unslotted types (e.g. milk_type) — always qty 1
    for (final aId in _extrasSingle.values) {
      final matches = allAddons.where((a) => a.id == aId);
      if (matches.isNotEmpty) t += _adjustedPrice(matches.first);
    }
    return t;
  }

  int get _lineTotal => (_unitPrice + _addonsTotal + _optionalsTotal) * _qty;

  // ── Validation ────────────────────────────────────────────

  String? get _firstUnsatisfiedSlot {
    for (final s in widget.item.addonSlots) {
      if (!s.isRequired) continue;
      final min = s.minSelections.clamp(1, 999);
      final isMulti = (s.maxSelections ?? 2) > 1;
      final count = isMulti
          ? (_multi[s.id]?.length ?? 0)
          : (_single.containsKey(s.id) ? 1 : 0);
      if (count < min) return s.displayName;
    }
    return null;
  }

  bool get _canAdd => _firstUnsatisfiedSlot == null;

  // ── Toggle helpers ────────────────────────────────────────

  void _toggleSingle(String slotId, String addonId, bool required) =>
      setState(() {
        if (_single[slotId] == addonId) {
          if (!required) _single.remove(slotId);
        } else {
          _single[slotId] = addonId;
        }
        _clearRecipe();
      });

  void _toggleMulti(String slotId, String addonId, int? maxSel) =>
      setState(() {
        final m = _multi.putIfAbsent(slotId, () => {});
        if (m.containsKey(addonId)) {
          m.remove(addonId);
          if (m.isEmpty) _multi.remove(slotId);
        } else {
          // Disable at max — don't add (callers already grey out the chip)
          if (maxSel != null && m.length >= maxSel) return;
          m[addonId] = 1;
        }
        _clearRecipe();
      });

  void _incrementMulti(String slotId, String addonId) => setState(() {
        _multi.putIfAbsent(slotId, () => {})[addonId] =
            (_multi[slotId]![addonId] ?? 1) + 1;
        _clearRecipe();
      });

  void _decrementMulti(String slotId, String addonId) => setState(() {
        final m = _multi[slotId];
        if (m == null) return;
        final cur = m[addonId] ?? 1;
        if (cur <= 1) {
          m.remove(addonId);
          if (m.isEmpty) _multi.remove(slotId);
        } else {
          m[addonId] = cur - 1;
        }
        _clearRecipe();
      });

  void _toggleExtraSingle(String addonType, String addonId) => setState(() {
        if (_extrasSingle[addonType] == addonId) {
          _extrasSingle.remove(addonType);
        } else {
          _extrasSingle[addonType] = addonId;
        }
        _clearRecipe();
      });

  void _toggleExtra(String addonType, String addonId) => setState(() {
        final typeMap = _extras.putIfAbsent(addonType, () => {});
        if (typeMap.containsKey(addonId)) {
          typeMap.remove(addonId);
          if (typeMap.isEmpty) _extras.remove(addonType);
        } else {
          typeMap[addonId] = 1;
        }
        _clearRecipe();
      });

  void _incrementExtra(String addonType, String addonId) => setState(() {
        final typeMap = _extras.putIfAbsent(addonType, () => {});
        typeMap[addonId] = (typeMap[addonId] ?? 1) + 1;
        _clearRecipe();
      });

  void _decrementExtra(String addonType, String addonId) => setState(() {
        final typeMap = _extras[addonType];
        if (typeMap == null) return;
        final cur = typeMap[addonId] ?? 1;
        if (cur <= 1) {
          typeMap.remove(addonId);
          if (typeMap.isEmpty) _extras.remove(addonType);
        } else {
          typeMap[addonId] = cur - 1;
        }
        _clearRecipe();
      });

  // ── Recipe preview ────────────────────────────────────────

  void _clearRecipe() {
    // No-op, kept for compatibility
  }

  void _showRecipeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => RecipeSheet(
        itemName: normaliseName(widget.item.name),
        sizeLabel: _selectedSize,
        fetchRecipe: () async {
          final allAddons = ref.read(menuProvider).allAddons;
          return previewRecipeLocally(
            menuItem: widget.item,
            sizeLabel: _selectedSize,
            addons: _buildSelectedAddons(),
            selectedOptionals: _buildSelectedOptionals(),
            allAddons: allAddons,
          );
        },
      ),
    );
  }

  void _initBaseMilk() {
    final defaultId = widget.item.defaultMilkAddonId;
    if (defaultId == null) return;

    final allAddons = ref.read(menuProvider).allAddons;
    final defaultMilkAddon = allAddons.where((a) => a.id == defaultId).firstOrNull;

    if (defaultMilkAddon != null) {
      _baseSwapPrices['milk_type'] = defaultMilkAddon.defaultPrice;
      if (!_isEdit && _extrasSingle['milk_type'] == null) {
        _extrasSingle['milk_type'] = defaultMilkAddon.id;
      }
    }
  }

  List<SelectedOptional> _buildSelectedOptionals() {
    return _optionalFields
        .where((f) => _selectedOptionals.contains(f.id))
        .map((f) => SelectedOptional(
              optionalFieldId: f.id,
              name: f.name,
              price: f.price,
            ))
        .toList();
  }

  // ── Build selected addons list ────────────────────────────

  List<SelectedAddon> _buildSelectedAddons() {
    final allAddons = ref.read(menuProvider).allAddons;
    final result = <SelectedAddon>[];

    AddonItem? findAddon(String id) {
      final matches = allAddons.where((a) => a.id == id);
      return matches.isNotEmpty ? matches.first : null;
    }

    // Single-select slots (always qty 1)
    for (final aId in _single.values) {
      final a = findAddon(aId);
      if (a != null) {
        result.add(SelectedAddon(
            addonItemId: a.id,
            name: a.name,
            priceModifier: _adjustedPrice(a),
            quantity: 1));
      }
    }

    // Multi-select slots with quantities
    for (final qtyMap in _multi.values) {
      for (final entry in qtyMap.entries) {
        final a = findAddon(entry.key);
        if (a != null) {
          result.add(SelectedAddon(
              addonItemId: a.id,
              name: a.name,
              priceModifier: _adjustedPrice(a),
              quantity: entry.value));
        }
      }
    }

    // Per-type multi-select extras with quantities
    for (final typeMap in _extras.values) {
      for (final entry in typeMap.entries) {
        final a = findAddon(entry.key);
        if (a != null) {
          result.add(SelectedAddon(
              addonItemId: a.id,
              name: a.name,
              priceModifier: _adjustedPrice(a),
              quantity: entry.value));
        }
      }
    }

    // Single-select unslotted types (e.g. milk_type)
    for (final aId in _extrasSingle.values) {
      final a = findAddon(aId);
      if (a != null) {
        result.add(SelectedAddon(
            addonItemId: a.id,
            name: a.name,
            priceModifier: _adjustedPrice(a),
            quantity: 1));
      }
    }

    return result;
  }

  // ── Cart action ───────────────────────────────────────────

  void _addToCart() {
    final addons = _buildSelectedAddons();
    final optionals = _buildSelectedOptionals();
    final cartItem = CartItem(
      menuItemId: widget.item.id,
      itemName: normaliseName(widget.item.name),
      sizeLabel: _selectedSize,
      unitPrice: _unitPrice,
      quantity: _qty,
      addons: addons,
      optionals: optionals,
    );

    final notifier = ref.read(cartProvider.notifier);
    if (_isEdit) {
      notifier.replaceAt(widget.editIndex!, cartItem);
    } else {
      notifier.add(cartItem);
    }
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final byType = ref.watch(menuProvider).addonsByType;

    // Types covered by defined slots on this drink
    final slottedTypes =
        widget.item.addonSlots.map((s) => s.addonType).toSet();

    // Global addon types not covered by any custom slot — each gets its own card
    const globalTypes = ['milk_type', 'coffee_type', 'extra'];
    final unslottedTypes = globalTypes
        .where((t) => !slottedTypes.contains(t))
        .where((t) => (byType[t] ?? []).any((a) => a.isActive))
        .toList();

    // Sort addon slots without mutating original list
    final sortedSlots = widget.item.addonSlots.toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    List<AddonItem> getItemsWithAdjustedPrice(String type) {
      final list = (byType[type] ?? []).where((a) => a.isActive).toList();
      if (type == 'milk_type' || type == 'coffee_type') {
        return list.map((a) {
          return AddonItem(
            id: a.id,
            name: a.name,
            addonType: a.addonType,
            defaultPrice: _adjustedPrice(a),
            isActive: a.isActive,
            displayOrder: a.displayOrder,
            primaryIngredientId: a.primaryIngredientId,
          );
        }).toList();
      }
      return list;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.90),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: AppRadius.sheetRadius),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2))))),

          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(normaliseName(widget.item.name),
                        style: cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.2)),
                    if (widget.item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(widget.item.description!,
                          style: cairo(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              height: 1.4)),
                    ],
                  ])),
              const SizedBox(width: 10),

              // Recipe button
              GestureDetector(
                onTap: _showRecipeSheet,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(color: AppColors.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _recipeLoading
                        ? const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.primary))
                        : Icon(Icons.science_outlined,
                            size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Text('Recipe',
                        style: cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),

              // Price badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, -0.3), end: Offset.zero)
                        .animate(anim),
                    child: FadeTransition(opacity: anim, child: child)),
                child: Container(
                  key: ValueKey(_unitPrice + _addonsTotal),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(egp(_unitPrice + _addonsTotal + _optionalsTotal),
                      style: cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ),
              ),
            ]),
          ),

          // Scrollable body
          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Sizes
              if (widget.item.sizes.isNotEmpty) ...[
                const SectionLabel('Size'),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.item.sizes
                        .map((s) => SelectableChip(
                              label: normaliseName(s.label),
                              sublabel: egp(s.price),
                              selected: s.label == _selectedSize,
                              checkbox: false,
                              onTap: () => setState(() {
                                _selectedSize = s.label;
                                _clearRecipe();
                              }),
                            ))
                        .toList()),
                const SizedBox(height: 20),
              ],

              // Custom slots — each gets its own card with type-specific color
              for (final s in sortedSlots) ...[
                AddonCard(
                  title: s.displayName,
                  isRequired: s.isRequired,
                  isMulti: (s.maxSelections ?? 2) > 1,
                  maxSelections: s.maxSelections,
                  items: getItemsWithAdjustedPrice(s.addonType),
                  selectedSingle: _single[s.id],
                  selectedMulti: _multi[s.id] ?? {},
                  onToggleSingle: (aId) =>
                      _toggleSingle(s.id, aId, s.isRequired),
                  onToggleMulti: (aId) =>
                      _toggleMulti(s.id, aId, s.maxSelections),
                  onIncrement: (aId) => _incrementMulti(s.id, aId),
                  onDecrement: (aId) => _decrementMulti(s.id, aId),
                  accentColor: addonTypeColor(s.addonType),
                ),
                const SizedBox(height: 12),
              ],

              // Unslotted milk_type first (if present)
              if (unslottedTypes.contains('milk_type')) ...[
                AddonCard(
                  title: addonTypeLabel('milk_type'),
                  isRequired: false,
                  isMulti: false,
                  maxSelections: null,
                  items: getItemsWithAdjustedPrice('milk_type'),
                  selectedSingle: _extrasSingle['milk_type'],
                  selectedMulti: const {},
                  onToggleSingle: (aId) =>
                      _toggleExtraSingle('milk_type', aId),
                  onToggleMulti: (_) {},
                  onIncrement: (_) {},
                  onDecrement: (_) {},
                  accentColor: addonTypeColor('milk_type'),
                ),
                const SizedBox(height: 12),
              ],

              // Optionals section immediately after milk
              if (_optionalFields.isNotEmpty) ...[
                OptionalFieldsCard(
                  fields: _optionalFields,
                  selected: _selectedOptionals,
                  sizeLabel: _selectedSize,
                  onToggle: (id) => setState(() {
                    if (_selectedOptionals.contains(id)) {
                      _selectedOptionals.remove(id);
                    } else {
                      _selectedOptionals.add(id);
                    }
                    _clearRecipe();
                  }),
                ),
                const SizedBox(height: 12),
              ],

              // Other Unslotted types (excluding milk_type)
              for (final addonType in unslottedTypes.where((t) => t != 'milk_type')) ...[
                if (_singleSelectTypes.contains(addonType))
                  AddonCard(
                    title: addonTypeLabel(addonType),
                    isRequired: false,
                    isMulti: false,
                    maxSelections: null,
                    items: getItemsWithAdjustedPrice(addonType),
                    selectedSingle: _extrasSingle[addonType],
                    selectedMulti: const {},
                    onToggleSingle: (aId) =>
                        _toggleExtraSingle(addonType, aId),
                    onToggleMulti: (_) {},
                    onIncrement: (_) {},
                    onDecrement: (_) {},
                    accentColor: addonTypeColor(addonType),
                  )
                else
                  AddonCard(
                    title: addonTypeLabel(addonType),
                    isRequired: false,
                    isMulti: true,
                    maxSelections: null,
                    items: getItemsWithAdjustedPrice(addonType),
                    selectedSingle: null,
                    selectedMulti: _extras[addonType] ?? {},
                    onToggleSingle: (_) {},
                    onToggleMulti: (aId) => _toggleExtra(addonType, aId),
                    onIncrement: (aId) => _incrementExtra(addonType, aId),
                    onDecrement: (aId) => _decrementExtra(addonType, aId),
                    accentColor: addonTypeColor(addonType),
                  ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 6),
            ]),
          )),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Container(
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  QtyBtn(
                      icon: Icons.remove,
                      onTap: () =>
                          setState(() => _qty = (_qty - 1).clamp(1, 99))),
                  SizedBox(
                      width: 40,
                      child: Center(
                          child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Text('$_qty',
                                  key: ValueKey(_qty),
                                  style: cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800))))),
                  QtyBtn(
                      icon: Icons.add,
                      onTap: () =>
                          setState(() => _qty = (_qty + 1).clamp(1, 99))),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: AppButton(
                label: _canAdd
                    ? '${_isEdit ? "Update" : "Add"}  —  ${egp(_lineTotal)}'
                    : 'Select ${_firstUnsatisfiedSlot ?? "required options"}',
                height: 50,
                onTap: _canAdd ? _addToCart : null,
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}
