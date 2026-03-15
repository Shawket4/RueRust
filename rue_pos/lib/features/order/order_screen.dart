import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/api/menu_api.dart';
import '../../core/api/order_api.dart';
import '../../core/models/menu.dart';
import '../../core/models/order.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/menu_provider.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/label_value.dart';

// ─────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────

/// Normalises item names: "bLended lATte" → "Blended Latte"
String _normaliseName(String s) => s
    .split(' ')
    .map((w) =>
        w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

// ─────────────────────────────────────────────────────────────
//  ROOT SCREEN
// ─────────────────────────────────────────────────────────────
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});
  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgId = context.read<AuthProvider>().user?.orgId;
      if (orgId != null) context.read<MenuProvider>().load(orgId);
    });
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          _TopBar(ctrl: _searchCtrl, query: _query),
          Expanded(
            child: Row(children: [
              if (_query.isEmpty) const _CategoryRail(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _query.isNotEmpty
                      ? _SearchResults(key: ValueKey(_query), query: _query)
                      : const _MenuGrid(key: ValueKey('grid')),
                ),
              ),
              const _CartPanel(),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String query;
  const _TopBar({required this.ctrl, required this.query});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(children: [
        // Back
        _IconBtn(
          icon: Icons.arrow_back_rounded,
          onTap: () => context.go('/home'),
        ),
        const SizedBox(width: 10),

        // Logo — small, subtle
        Image.asset('assets/TheRue.png', height: 22),
        const SizedBox(width: 14),

        // Search
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: ctrl,
              style: cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search menu…',
                hintStyle: cairo(fontSize: 14, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.textMuted),
                suffixIcon: query.isNotEmpty
                    ? GestureDetector(
                        onTap: ctrl.clear,
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textMuted),
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
                filled: false,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Cart pill
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: cart.isEmpty
              ? const SizedBox.shrink(key: ValueKey('empty'))
              : Container(
                  key: const ValueKey('pill'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.shopping_bag_outlined,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '${cart.count} · ${egp(cart.total)}',
                      style: cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ]),
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CATEGORY RAIL
// ─────────────────────────────────────────────────────────────
class _CategoryRail extends StatelessWidget {
  const _CategoryRail();

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();

    return Container(
      width: 86,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: menu.categories.length,
            itemBuilder: (_, i) {
              final cat = menu.categories[i];
              final sel = cat.id == menu.selectedId;
              return GestureDetector(
                onTap: () => menu.select(cat.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    Icon(_catIcon(cat.name),
                        size: 20,
                        color: sel ? Colors.white : AppColors.textMuted),
                    const SizedBox(height: 5),
                    Text(
                      _normaliseName(cat.name),
                      style: cairo(
                        fontSize: 9.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : AppColors.textSecondary,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  IconData _catIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('matcha')) return Icons.eco_rounded;
    if (n.contains('latte') ||
        n.contains('espresso') ||
        n.contains('americano') ||
        n.contains('cappuc') ||
        n.contains('flat') ||
        n.contains('cortado') ||
        n.contains('machiato') ||
        n.contains('coffee')) return Icons.coffee_rounded;
    if (n.contains('chocolate')) return Icons.cake_rounded;
    if (n.contains('croissant') ||
        n.contains('pain') ||
        n.contains('brownie') ||
        n.contains('cookie') ||
        n.contains('tart') ||
        n.contains('melt') ||
        n.contains('chicken') ||
        n.contains('turkey')) return Icons.bakery_dining_rounded;
    if (n.contains('bottle') || n.contains('cold brew'))
      return Icons.liquor_rounded;
    if (n.contains('soft serve') || n.contains('affogato'))
      return Icons.icecream_rounded;
    if (n.contains('lemon') ||
        n.contains('peach') ||
        n.contains('strawberry') ||
        n.contains('water') ||
        n.contains('tea') ||
        n.contains('pina')) return Icons.local_drink_rounded;
    return Icons.restaurant_menu_rounded;
  }
}

// ─────────────────────────────────────────────────────────────
//  MENU GRID
// ─────────────────────────────────────────────────────────────
class _MenuGrid extends StatelessWidget {
  const _MenuGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    final items = menu.filtered.where((i) => i.isActive).toList();

    if (menu.loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (menu.error != null) {
      return _ErrorState(
        message: menu.error!,
        onRetry: () {
          final orgId = context.read<AuthProvider>().user?.orgId;
          if (orgId != null) context.read<MenuProvider>().refresh(orgId);
        },
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text('No items in this category',
            style: cairo(color: AppColors.textMuted)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // Bigger cards — fewer per row
        maxCrossAxisExtent: 185,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Fixed aspect ratio — info area always same height
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _MenuCard(item: items[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SEARCH RESULTS
// ─────────────────────────────────────────────────────────────
class _SearchResults extends StatelessWidget {
  final String query;
  const _SearchResults({required this.query, super.key});

  @override
  Widget build(BuildContext context) {
    final found = context
        .watch<MenuProvider>()
        .allItems
        .where((i) =>
            i.isActive &&
            (i.name.toLowerCase().contains(query) ||
                (i.description?.toLowerCase().contains(query) ?? false)))
        .toList();

    if (found.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded,
              size: 44, color: AppColors.border),
          const SizedBox(height: 14),
          Text('No results for "$query"',
              style: cairo(fontSize: 14, color: AppColors.textSecondary)),
        ]),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 185,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: found.length,
      itemBuilder: (_, i) => _MenuCard(item: found[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MENU CARD  — fixed info height, normalised name, fetch on tap
// ─────────────────────────────────────────────────────────────
class _MenuCard extends StatefulWidget {
  final MenuItem item;
  const _MenuCard({required this.item, super.key});
  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard>
    with SingleTickerProviderStateMixin {
  bool _fetching = false;
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _pressAnim = Tween<double>(begin: 1, end: 0.96)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_fetching) return;
    setState(() => _fetching = true);
    try {
      final full = await menuApi.item(widget.item.id);
      if (mounted) {
        setState(() => _fetching = false);
        ItemDetailSheet.show(context, full);
      }
    } catch (_) {
      if (mounted) setState(() => _fetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _normaliseName(widget.item.name);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) async {
        await _pressCtrl.reverse();
        _onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressAnim,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image area — flexible, fills available space ──
              Expanded(
                child: Stack(children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: widget.item.imageUrl != null
                        ? Image.network(
                            widget.item.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (_, child, prog) =>
                                prog == null ? child : _ImageSkeleton(),
                            errorBuilder: (_, __, ___) =>
                                _Placeholder(item: widget.item),
                          )
                        : _Placeholder(item: widget.item),
                  ),
                  if (_fetching)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      ),
                    ),
                ]),
              ),

              // ── Info area — FIXED height so all cards are consistent ──
              SizedBox(
                height: 66,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Name — always 2 lines, never resizes the card
                      Text(
                        name,
                        style: cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Price
                      Text(
                        egp(widget.item.basePrice),
                        style: cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  IMAGE SKELETON (loading state)
// ─────────────────────────────────────────────────────────────
class _ImageSkeleton extends StatefulWidget {
  @override
  State<_ImageSkeleton> createState() => _ImageSkeletonState();
}

class _ImageSkeletonState extends State<_ImageSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(color: const Color(0xFFEEEEEE)),
      );
}

// ─────────────────────────────────────────────────────────────
//  PLACEHOLDER  (no image)
// ─────────────────────────────────────────────────────────────
class _Placeholder extends StatelessWidget {
  final MenuItem item;
  const _Placeholder({required this.item});

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _pick(item.name.toLowerCase());
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bg,
      alignment: Alignment.center,
      child: Icon(icon, size: 32, color: fg),
    );
  }

  static (IconData, Color, Color) _pick(String n) {
    if (n.contains('matcha'))
      return (
        Icons.eco_rounded,
        const Color(0xFFE8F5E9),
        const Color(0xFF388E3C)
      );
    if (n.contains('latte') ||
        n.contains('espresso') ||
        n.contains('americano') ||
        n.contains('cappuc') ||
        n.contains('flat') ||
        n.contains('cortado') ||
        n.contains('machiato') ||
        n.contains('coffee'))
      return (
        Icons.coffee_rounded,
        const Color(0xFFF5EEE6),
        const Color(0xFF795548)
      );
    if (n.contains('chocolate'))
      return (
        Icons.cake_rounded,
        const Color(0xFFF3E5E5),
        const Color(0xFF6D4C41)
      );
    if (n.contains('croissant') ||
        n.contains('pain') ||
        n.contains('brownie') ||
        n.contains('cookie') ||
        n.contains('tart'))
      return (
        Icons.bakery_dining_rounded,
        const Color(0xFFFFF8E1),
        const Color(0xFFF9A825)
      );
    if (n.contains('melt') || n.contains('chicken') || n.contains('turkey'))
      return (
        Icons.lunch_dining_rounded,
        const Color(0xFFFFF3E0),
        const Color(0xFFEF6C00)
      );
    if (n.contains('affogato') || n.contains('soft serve'))
      return (
        Icons.icecream_rounded,
        const Color(0xFFF3E5F5),
        const Color(0xFF8E24AA)
      );
    if (n.contains('lemon') ||
        n.contains('peach') ||
        n.contains('strawberry') ||
        n.contains('pina') ||
        n.contains('tea') ||
        n.contains('lemonade'))
      return (
        Icons.local_drink_rounded,
        const Color(0xFFFFF8E1),
        const Color(0xFFF57F17)
      );
    if (n.contains('water') || n.contains('sparkling'))
      return (
        Icons.water_drop_rounded,
        const Color(0xFFE3F2FD),
        const Color(0xFF1976D2)
      );
    return (
      Icons.coffee_maker_rounded,
      const Color(0xFFF5F5F5),
      const Color(0xFF90A4AE)
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ITEM DETAIL SHEET
// ─────────────────────────────────────────────────────────────
class ItemDetailSheet extends StatefulWidget {
  final MenuItem item;
  const ItemDetailSheet({super.key, required this.item});

  static void show(BuildContext ctx, MenuItem item) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ItemDetailSheet(item: item),
      );

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  String? _selectedSize;
  final Map<String, String> _single = {};
  final Map<String, Set<String>> _multi = {};
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    if (widget.item.sizes.isNotEmpty) {
      _selectedSize = widget.item.sizes.first.label;
    }
  }

  int get _unitPrice => widget.item.priceForSize(_selectedSize);

  int get _addonsTotal {
    int t = 0;
    for (final g in widget.item.optionGroups) {
      if (g.isMultiSelect) {
        for (final o in g.items) {
          if ((_multi[g.id] ?? {}).contains(o.id)) t += o.price;
        }
      } else {
        for (final o in g.items) {
          if (o.id == _single[g.id]) {
            t += o.price;
            break;
          }
        }
      }
    }
    return t;
  }

  int get _lineTotal => (_unitPrice + _addonsTotal) * _qty;

  bool get _canAdd {
    for (final g in widget.item.optionGroups) {
      if (!g.isRequired) continue;
      if (g.isMultiSelect) {
        if ((_multi[g.id] ?? {}).isEmpty) return false;
      } else {
        if (!_single.containsKey(g.id)) return false;
      }
    }
    return true;
  }

  void _toggleSingle(String gId, String oId, bool req) => setState(() {
        if (_single[gId] == oId) {
          if (!req) _single.remove(gId);
        } else
          _single[gId] = oId;
      });

  void _toggleMulti(String gId, String oId) => setState(() {
        final s = _multi.putIfAbsent(gId, () => {});
        s.contains(oId) ? s.remove(oId) : s.add(oId);
        if (s.isEmpty) _multi.remove(gId);
      });

  void _addToCart() {
    final addons = <SelectedAddon>[];
    for (final g in widget.item.optionGroups) {
      if (g.isMultiSelect) {
        for (final o in g.items) {
          if ((_multi[g.id] ?? {}).contains(o.id)) {
            addons.add(SelectedAddon(
                addonItemId: o.addonItemId,
                drinkOptionItemId: o.id,
                name: o.name,
                priceModifier: o.price));
          }
        }
      } else {
        final sId = _single[g.id];
        if (sId == null) continue;
        for (final o in g.items) {
          if (o.id == sId) {
            addons.add(SelectedAddon(
                addonItemId: o.addonItemId,
                drinkOptionItemId: o.id,
                name: o.name,
                priceModifier: o.price));
            break;
          }
        }
      }
    }
    context.read<CartProvider>().add(CartItem(
          menuItemId: widget.item.id,
          itemName: _normaliseName(widget.item.name),
          sizeLabel: _selectedSize,
          unitPrice: _unitPrice,
          quantity: _qty,
          addons: addons,
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)),
          )),
        ),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + live price
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(_normaliseName(widget.item.name),
                        style: cairo(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        )),
                  ),
                  const SizedBox(width: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, -0.3), end: Offset.zero)
                          .animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text(
                      egp(_unitPrice + _addonsTotal),
                      key: ValueKey(_unitPrice + _addonsTotal),
                      style: cairo(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ]),
                if (widget.item.description != null) ...[
                  const SizedBox(height: 6),
                  Text(widget.item.description!,
                      style:
                          cairo(fontSize: 13, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 22),

                // Sizes
                if (widget.item.sizes.isNotEmpty) ...[
                  _SheetLabel('Size'),
                  const SizedBox(height: 10),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.item.sizes
                          .map((s) => _Chip(
                                label: _normaliseName(s.label),
                                sublabel: egp(s.price),
                                selected: s.label == _selectedSize,
                                checkbox: false,
                                onTap: () =>
                                    setState(() => _selectedSize = s.label),
                              ))
                          .toList()),
                  const SizedBox(height: 22),
                ],

                // Option groups
                for (final g in widget.item.optionGroups) ...[
                  _SheetLabel(
                    g.displayName,
                    required: g.isRequired,
                    multi: g.isMultiSelect,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: g.items.map((opt) {
                        final sel = g.isMultiSelect
                            ? (_multi[g.id] ?? {}).contains(opt.id)
                            : _single[g.id] == opt.id;
                        return _Chip(
                          label: _normaliseName(opt.name),
                          sublabel: opt.price > 0 ? '+${egp(opt.price)}' : null,
                          selected: sel,
                          checkbox: g.isMultiSelect,
                          onTap: () => g.isMultiSelect
                              ? _toggleMulti(g.id, opt.id)
                              : _toggleSingle(g.id, opt.id, g.isRequired),
                        );
                      }).toList()),
                  const SizedBox(height: 22),
                ],

                // Quantity
                _SheetLabel('Quantity'),
                const SizedBox(height: 10),
                Row(children: [
                  _QtyBtn(
                      icon: Icons.remove,
                      onTap: () =>
                          setState(() => _qty = (_qty - 1).clamp(1, 99))),
                  SizedBox(
                    width: 52,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Text(
                          '$_qty',
                          key: ValueKey(_qty),
                          style:
                              cairo(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  _QtyBtn(
                      icon: Icons.add,
                      onTap: () =>
                          setState(() => _qty = (_qty + 1).clamp(1, 99))),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // CTA
        Container(
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
          ),
          child: AppButton(
            label: _canAdd
                ? 'Add to Order — ${egp(_lineTotal)}'
                : 'Select required options',
            width: double.infinity,
            height: 52,
            onTap: _canAdd ? _addToCart : null,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CART PANEL
// ─────────────────────────────────────────────────────────────
class _CartPanel extends StatelessWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Container(
      width: 310,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
          ),
          child: Row(children: [
            Text('Order',
                style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
            if (!cart.isEmpty) ...[
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(cart.count),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${cart.count}',
                      style: cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      )),
                ),
              ),
            ],
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: () => _confirmClear(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Clear',
                      style: cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      )),
                ),
              ),
          ]),
        ),

        // Items
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: cart.isEmpty
                ? const _EmptyCart()
                : ListView.separated(
                    key: const ValueKey('items'),
                    padding: const EdgeInsets.all(10),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _CartRow(index: i),
                  ),
          ),
        ),

        // Footer
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: cart.isEmpty ? const SizedBox.shrink() : _CartFooter(),
        ),
      ]),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Order?', style: cairo(fontWeight: FontWeight.w700)),
        content: Text('Remove all items from the cart.', style: cairo()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: cairo(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CartProvider>().clear();
            },
            child: Text('Clear',
                style: cairo(
                    color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shopping_bag_outlined,
                size: 28, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Text('Cart is empty',
              style: cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Tap any item to add it',
              style: cairo(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
}

class _CartRow extends StatelessWidget {
  final int index;
  const _CartRow({required this.index});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final item = cart.items[index];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(
                item.itemName +
                    (item.sizeLabel != null
                        ? ' · ${_normaliseName(item.sizeLabel!)}'
                        : ''),
                style: cairo(
                    fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
              ),
            ),
            const SizedBox(width: 8),
            Text(egp(item.lineTotal),
                style: cairo(fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          if (item.addons.isNotEmpty) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: item.addons
                  .map((a) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          a.priceModifier > 0
                              ? '${_normaliseName(a.name)} +${egp(a.priceModifier)}'
                              : _normaliseName(a.name),
                          style: cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            _InlineBtn(
                icon: Icons.remove,
                onTap: () => cart.setQty(index, item.quantity - 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${item.quantity}',
                  style: cairo(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            _InlineBtn(
                icon: Icons.add,
                onTap: () => cart.setQty(index, item.quantity + 1)),
            const Spacer(),
            GestureDetector(
              onTap: () => cart.removeAt(index),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.delete_outline_rounded,
                    size: 15, color: AppColors.danger),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(children: [
        LabelValue('Subtotal', egp(cart.subtotal)),
        if (cart.discountAmount > 0)
          LabelValue('Discount', '− ${egp(cart.discountAmount)}',
              valueColor: AppColors.success),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, -0.3), end: Offset.zero)
                      .animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(egp(cart.total),
                    key: ValueKey(cart.total),
                    style: cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        AppButton(
          label: 'Checkout',
          width: double.infinity,
          height: 50,
          icon: Icons.arrow_forward_rounded,
          onTap: () => CheckoutSheet.show(context),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CHECKOUT SHEET
// ─────────────────────────────────────────────────────────────
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});

  static void show(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const CheckoutSheet(),
      );

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  bool _loading = false;
  String? _error;
  static const _methods = ['cash', 'card', 'instapay'];

  Future<void> _place() async {
    final cart = context.read<CartProvider>();
    final shift = context.read<ShiftProvider>().shift;
    if (shift == null) {
      setState(() => _error = 'No open shift');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await orderApi.create(
        branchId: shift.branchId,
        shiftId: shift.id,
        paymentMethod: cart.payment,
        items: cart.items.toList(),
        customerName: cart.customer,
        discountType: cart.discountTypeStr,
        discountValue: cart.discountValue,
      );
      context.read<OrderHistoryProvider>().addOrder(order);
      final total = cart.total;
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        ReceiptSheet.show(context, order: order, total: total);
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint('ORDER ${e.response?.statusCode}: ${e.response?.data}');
      }
      setState(() {
        _error = 'Failed to place order — please retry';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 18),
          Text('Checkout',
              style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              LabelValue('Subtotal', egp(cart.subtotal)),
              if (cart.discountAmount > 0)
                LabelValue('Discount', '− ${egp(cart.discountAmount)}',
                    valueColor: AppColors.success),
              const Divider(height: 16, color: Color(0xFFEEEEEE)),
              LabelValue('Total', egp(cart.total), bold: true),
            ]),
          ),
          const SizedBox(height: 18),
          Text('PAYMENT',
              style: cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1,
              )),
          const SizedBox(height: 10),
          Row(
            children: _methods.map((m) {
              final sel = cart.payment == m;
              return GestureDetector(
                onTap: () => cart.setPayment(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? AppColors.primary : const Color(0xFFE8E8E8),
                    ),
                  ),
                  child: Text(
                    _normaliseName(m),
                    style: cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 15, color: AppColors.danger),
                const SizedBox(width: 8),
                Text(_error!,
                    style: cairo(fontSize: 13, color: AppColors.danger)),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Place Order',
            loading: _loading,
            width: double.infinity,
            height: 52,
            icon: Icons.check_rounded,
            onTap: _place,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  RECEIPT SHEET
// ─────────────────────────────────────────────────────────────
class ReceiptSheet extends StatelessWidget {
  final Order order;
  final int total;
  const ReceiptSheet({super.key, required this.order, required this.total});

  static void show(BuildContext ctx,
          {required Order order, required int total}) =>
      showModalBottomSheet(
        context: ctx,
        backgroundColor: Colors.transparent,
        builder: (_) => ReceiptSheet(order: order, total: total),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 14, 24, MediaQuery.of(context).padding.bottom + 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 24),

          // Animated check
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 34),
            ),
          ),
          const SizedBox(height: 14),

          Text('Order Placed!',
              style: cairo(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Order #${order.orderNumber}',
              style: cairo(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              LabelValue('Payment', _normaliseName(order.paymentMethod)),
              LabelValue('Total', egp(order.totalAmount), bold: true),
              LabelValue('Time', timeShort(order.createdAt)),
            ]),
          ),
          const SizedBox(height: 20),

          AppButton(
            label: 'New Order',
            width: double.infinity,
            height: 52,
            icon: Icons.add_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────
class _SheetLabel extends StatelessWidget {
  final String label;
  final bool required;
  final bool multi;
  const _SheetLabel(this.label, {this.required = false, this.multi = false});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label.toUpperCase(),
            style: cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            )),
        if (required) ...[
          const SizedBox(width: 6),
          _Pill('Required', AppColors.danger),
        ],
        if (multi) ...[
          const SizedBox(width: 6),
          _Pill('Pick multiple', AppColors.primary),
        ],
      ]);
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: cairo(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            )),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final bool checkbox;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    this.sublabel,
    required this.selected,
    required this.checkbox,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE8E8E8),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (checkbox) ...[
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 15,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                )),
            if (sublabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.2)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(sublabel!,
                    style: cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.primary,
                    )),
              ),
            ],
          ]),
        ),
      );
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      );
}

class _InlineBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _InlineBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 13, color: AppColors.textPrimary),
        ),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message,
              style: cairo(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}
