// ignore_for_file: unused_element_parameter, unused_import

import 'dart:math' show max;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/menu_api.dart';
import '../../core/api/order_api.dart';
import '../../core/models/menu.dart';
import '../../core/models/order.dart';
import '../../core/models/pending_order.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/branch_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/menu_provider.dart';
import '../../core/providers/order_history_provider.dart';
import '../../core/providers/shift_provider.dart';
import '../../core/services/offline_sync_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/label_value.dart';

const _skeletonBase = Color(0xFFF0EBE3);
const _skeletonHighlight = Color(0xFFE8E0D5);

// ─────────────────────────────────────────────────────────────────────────────
//  ROOT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
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
    final w = MediaQuery.of(context).size.width;
    final isTablet = w >= 768;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // Mobile: floating cart button in bottom-right
      floatingActionButton: isTablet ? null : _MobileCartFab(),
      body: SafeArea(
        child: Column(children: [
          _TopBar(ctrl: _searchCtrl, query: _query),
          Expanded(
            child: isTablet
                ? Row(children: [
                    if (_query.isEmpty) const _CategoryRail(),
                    Expanded(child: _contentArea()),
                    const _CartPanel(),
                  ])
                : Row(children: [
                    if (_query.isEmpty) const _CategoryRail(),
                    Expanded(child: _contentArea()),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _contentArea() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(anim),
            child: child,
          ),
        ),
        child: _query.isNotEmpty
            ? _SearchResults(key: ValueKey(_query), query: _query)
            : const _MenuGrid(key: ValueKey('grid')),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TextEditingController ctrl;
  final String query;
  const _TopBar({required this.ctrl, required this.query});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final sync = context.watch<OfflineSyncService>();
    final isTablet = MediaQuery.of(context).size.width >= 768;

    final bar = Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(children: [
        _IconBtn(
            icon: Icons.arrow_back_rounded, onTap: () => context.go('/home')),
        const SizedBox(width: 10),
        Image.asset('assets/TheRue.png', height: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
                color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
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
                            size: 16, color: AppColors.textMuted))
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
        // On tablet show the cart pill; on mobile it's the FAB
        if (isTablet) ...[
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child)),
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
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Row(children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('${cart.count} · ${egp(cart.total)}',
                          style: cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
                  ),
          ),
        ],
      ]),
    );

    if (!sync.isOnline || sync.count > 0) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        bar,
        if (!sync.isOnline)
          const _StatusBanner(
            color: Color(0xFFFFF3CD),
            icon: Icons.wifi_off_rounded,
            text: 'Offline — cached menu. Orders will sync when connected.',
            textColor: Color(0xFF856404),
          ),
        if (sync.isOnline && sync.count > 0)
          _StatusBanner(
            color: const Color(0xFFCFE2FF),
            icon: Icons.sync_rounded,
            text:
                'Syncing ${sync.count} offline order${sync.count == 1 ? "" : "s"}…',
            textColor: const Color(0xFF084298),
            animate: true,
          ),
      ]);
    }
    return bar;
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final Color textColor;
  final bool animate;
  const _StatusBanner(
      {required this.color,
      required this.icon,
      required this.text,
      required this.textColor,
      this.animate = false});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(children: [
          animate
              ? SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: textColor))
              : Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: cairo(fontSize: 11, color: textColor))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CATEGORY RAIL
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryRail extends StatelessWidget {
  const _CategoryRail();

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    return Container(
      width: 86,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFF0F0F0)))),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: menu.categories.length,
        itemBuilder: (_, i) {
          final cat = menu.categories[i];
          final sel = cat.id == menu.selectedId;
          return GestureDetector(
            onTap: () => menu.select(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Icon(_catIcon(cat.name),
                    size: 20, color: sel ? Colors.white : AppColors.textMuted),
                const SizedBox(height: 5),
                Text(normaliseName(cat.name),
                    style: cairo(
                        fontSize: 9.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : AppColors.textSecondary,
                        height: 1.25),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    );
  }

  IconData _catIcon(String name) => _CatStyle.of(name).icon;
}

// ─────────────────────────────────────────────────────────────────────────────
//  MENU GRID  — adaptive columns based on available width
// ─────────────────────────────────────────────────────────────────────────────
class _MenuGrid extends StatelessWidget {
  const _MenuGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    final items = menu.filtered.where((i) => i.isActive).toList();

    if (menu.loading) {
      return _grid(8, (_, __) => const _MenuCardSkeleton());
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
              style: cairo(color: AppColors.textMuted)));
    }
    return _grid(items.length, (_, i) => _MenuCard(item: items[i]));
  }

  Widget _grid(int count, Widget Function(BuildContext, int) builder) =>
      LayoutBuilder(builder: (ctx, constraints) {
        // Adaptive: aim for cards ~160px wide, min 2, max 5
        final cols = (constraints.maxWidth / 160).floor().clamp(2, 5);
        final extent = constraints.maxWidth / cols;
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: extent / (extent * 1.3),
          ),
          itemCount: count,
          itemBuilder: builder,
        );
      });
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH RESULTS
// ─────────────────────────────────────────────────────────────────────────────
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
        SizedBox(
            width: 160,
            height: 160,
            child: Lottie.asset('assets/lottie/no_results.json',
                fit: BoxFit.contain, repeat: true)),
        const SizedBox(height: 8),
        Text('No results for "$query"',
            style: cairo(fontSize: 14, color: AppColors.textSecondary)),
      ]));
    }

    return LayoutBuilder(builder: (ctx, constraints) {
      final cols = (constraints.maxWidth / 160).floor().clamp(2, 5);
      final extent = constraints.maxWidth / cols;
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: extent / (extent * 1.3),
        ),
        itemCount: found.length,
        itemBuilder: (_, i) => _MenuCard(item: found[i]),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE CART FAB
// ─────────────────────────────────────────────────────────────────────────────
class _MobileCartFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    if (cart.isEmpty) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: () => _MobileCartSheet.show(context),
      backgroundColor: AppColors.primary,
      label: Text('${cart.count} items · ${egp(cart.total)}',
          style: cairo(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      icon: const Icon(Icons.shopping_bag_outlined,
          size: 18, color: Colors.white),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE CART BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _MobileCartSheet extends StatelessWidget {
  const _MobileCartSheet();

  static void show(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _MobileCartSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2)))),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            Text('Order',
                style: cairo(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${cart.count}',
                  style: cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: () {
                  cart.clear();
                  Navigator.pop(context);
                },
                child: Text('Clear',
                    style: cairo(
                        fontSize: 13,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Text('Cart is empty',
                      style: cairo(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _CartRow(index: i),
                ),
        ),
        if (!cart.isEmpty) _CartFooter(),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETON
// ─────────────────────────────────────────────────────────────────────────────
class _MenuCardSkeleton extends StatefulWidget {
  const _MenuCardSkeleton();
  @override
  State<_MenuCardSkeleton> createState() => _MenuCardSkeletonState();
}

class _MenuCardSkeletonState extends State<_MenuCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final c = Color.lerp(_skeletonBase, _skeletonHighlight, _anim.value)!;
          return Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]),
            child: Column(children: [
              Expanded(
                  child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(color: c))),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Expanded(
                      child: Container(
                          height: 11,
                          decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(width: 12),
                  Container(
                      width: 44,
                      height: 11,
                      decoration: BoxDecoration(
                          color: c, borderRadius: BorderRadius.circular(4))),
                ]),
              ),
            ]),
          );
        },
      );
}

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
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
          color: Color.lerp(_skeletonBase, _skeletonHighlight, _anim.value)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  CATEGORY STYLES
// ─────────────────────────────────────────────────────────────────────────────
class _CatStyle {
  final IconData icon;
  final Color bgTop, bgBottom, iconColor, accent;
  const _CatStyle(
      {required this.icon,
      required this.bgTop,
      required this.bgBottom,
      required this.iconColor,
      required this.accent});

  static _CatStyle of(String name) {
    final n = name.toLowerCase();
    if (n.contains('matcha')) {
      return const _CatStyle(
          icon: Icons.eco_rounded,
          bgTop: Color(0xFFE8F5E9),
          bgBottom: Color(0xFFC8E6C9),
          iconColor: Color(0xFF2E7D32),
          accent: Color(0xFF388E3C));
    }
    if (n.contains('latte') ||
        n.contains('espresso') ||
        n.contains('americano') ||
        n.contains('cappuc') ||
        n.contains('flat') ||
        n.contains('cortado') ||
        n.contains('coffee') ||
        n.contains('v60') ||
        n.contains('blended') ||
        n.contains('cold brew')) {
      return const _CatStyle(
          icon: Icons.coffee_rounded,
          bgTop: Color(0xFFF5EEE6),
          bgBottom: Color(0xFFEDD9C0),
          iconColor: Color(0xFF5D4037),
          accent: Color(0xFF795548));
    }
    if (n.contains('chocolate') || n.contains('mocha')) {
      return const _CatStyle(
          icon: Icons.coffee_rounded,
          bgTop: Color(0xFFF3E5E5),
          bgBottom: Color(0xFFE8CECE),
          iconColor: Color(0xFF6D4C41),
          accent: Color(0xFF8D3A3A));
    }
    if (n.contains('croissant') ||
        n.contains('brownie') ||
        n.contains('cookie') ||
        n.contains('pastry') ||
        n.contains('pastries') ||
        n.contains('cake') ||
        n.contains('waffle')) {
      return const _CatStyle(
          icon: Icons.bakery_dining_rounded,
          bgTop: Color(0xFFFFF8E8),
          bgBottom: Color(0xFFFFF0C8),
          iconColor: Color(0xFFE65100),
          accent: Color(0xFFF57C00));
    }
    if (n.contains('sandwich') ||
        n.contains('chicken') ||
        n.contains('turkey') ||
        n.contains('food')) {
      return const _CatStyle(
          icon: Icons.lunch_dining_rounded,
          bgTop: Color(0xFFFFF3E0),
          bgBottom: Color(0xFFFFE0B2),
          iconColor: Color(0xFFE64A19),
          accent: Color(0xFFEF6C00));
    }
    if (n.contains('affogato') || n.contains('ice cream')) {
      return const _CatStyle(
          icon: Icons.icecream_rounded,
          bgTop: Color(0xFFF3E5F5),
          bgBottom: Color(0xFFE1BEE7),
          iconColor: Color(0xFF7B1FA2),
          accent: Color(0xFF9C27B0));
    }
    if (n.contains('lemon') ||
        n.contains('lemonade') ||
        n.contains('refresher') ||
        n.contains('juice')) {
      return const _CatStyle(
          icon: Icons.local_drink_rounded,
          bgTop: Color(0xFFFFFDE7),
          bgBottom: Color(0xFFFFF9C4),
          iconColor: Color(0xFFF57F17),
          accent: Color(0xFFFBC02D));
    }
    if (n.contains('tea') || n.contains('chai')) {
      return const _CatStyle(
          icon: Icons.emoji_food_beverage_rounded,
          bgTop: Color(0xFFE8F5E9),
          bgBottom: Color(0xFFC8E6C9),
          iconColor: Color(0xFF388E3C),
          accent: Color(0xFF43A047));
    }
    if (n.contains('water') || n.contains('sparkling')) {
      return const _CatStyle(
          icon: Icons.water_drop_rounded,
          bgTop: Color(0xFFE3F2FD),
          bgBottom: Color(0xFFBBDEFB),
          iconColor: Color(0xFF1565C0),
          accent: Color(0xFF1976D2));
    }
    if (n.contains('iced')) {
      return const _CatStyle(
          icon: Icons.ac_unit_rounded,
          bgTop: Color(0xFFE3F2FD),
          bgBottom: Color(0xFFBBDEFB),
          iconColor: Color(0xFF0277BD),
          accent: Color(0xFF0288D1));
    }
    return const _CatStyle(
        icon: Icons.local_cafe_rounded,
        bgTop: Color(0xFFF5EEE6),
        bgBottom: Color(0xFFEDD9C0),
        iconColor: Color(0xFF795548),
        accent: Color(0xFF8D6E63));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MENU CARD
// ─────────────────────────────────────────────────────────────────────────────
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
    final item = widget.item;
    final style = _CatStyle.of(item.name);
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

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
                  color: style.accent.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(children: [
              Expanded(
                  child: Stack(children: [
                Positioned.fill(
                    child: hasImage
                        ? Image.network(item.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, prog) =>
                                prog == null ? child : _ImageSkeleton(),
                            errorBuilder: (_, __, ___) =>
                                _CardBackground(style: style))
                        : _CardBackground(style: style)),
                if (!hasImage)
                  Center(
                      child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: style.iconColor.withOpacity(0.12),
                        shape: BoxShape.circle),
                    child: Icon(style.icon, size: 28, color: style.iconColor),
                  )),
                if (_fetching)
                  Positioned.fill(
                      child: Container(
                    color: Colors.black.withOpacity(0.3),
                    alignment: Alignment.center,
                    child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white)),
                  )),
              ])),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                          width: 4,
                          height: 28,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: style.accent,
                              borderRadius: BorderRadius.circular(2))),
                      Expanded(
                          child: Text(normaliseName(item.name),
                              style: cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      Text(egp(item.basePrice),
                          style: cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: style.accent)),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CardBackground extends StatelessWidget {
  final _CatStyle style;
  const _CardBackground({required this.style});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [style.bgTop, style.bgBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  ITEM DETAIL SHEET
// ─────────────────────────────────────────────────────────────────────────────
class ItemDetailSheet extends StatefulWidget {
  final MenuItem item;
  const ItemDetailSheet({super.key, required this.item});

  static void show(BuildContext ctx, MenuItem item) => showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemDetailSheet(item: item));

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
        } else {
          _single[gId] = oId;
        }
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
        itemName: normaliseName(widget.item.name),
        sizeLabel: _selectedSize,
        unitPrice: _unitPrice,
        quantity: _qty,
        addons: addons));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.90),
        decoration: const BoxDecoration(
            color: Color(0xFFFAF8F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: const Color(0xFFDDD8D0),
                          borderRadius: BorderRadius.circular(2))))),
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
            decoration: const BoxDecoration(
                color: Color(0xFFFAF8F5),
                border: Border(bottom: BorderSide(color: Color(0xFFECE8E0)))),
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
              const SizedBox(width: 16),
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
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(egp(_unitPrice + _addonsTotal),
                      style: cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ),
              ),
            ]),
          ),
          // Options scroll area
          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (widget.item.sizes.isNotEmpty) ...[
                const _SectionLabel('Size'),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.item.sizes
                        .map((s) => _Chip(
                              label: normaliseName(s.label),
                              sublabel: egp(s.price),
                              selected: s.label == _selectedSize,
                              checkbox: false,
                              onTap: () =>
                                  setState(() => _selectedSize = s.label),
                            ))
                        .toList()),
                const SizedBox(height: 20),
              ],
              for (final g in widget.item.optionGroups) ...[
                _OptionGroupCard(
                  group: g,
                  selectedSingle: _single[g.id],
                  selectedMulti: _multi[g.id] ?? {},
                  onToggleSingle: (oId) =>
                      _toggleSingle(g.id, oId, g.isRequired),
                  onToggleMulti: (oId) => _toggleMulti(g.id, oId),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 6),
            ]),
          )),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFECE8E0)))),
            child: Row(children: [
              Container(
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F0EB),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _QtyBtn(
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
                  _QtyBtn(
                      icon: Icons.add,
                      onTap: () =>
                          setState(() => _qty = (_qty + 1).clamp(1, 99))),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: AppButton(
                label: _canAdd
                    ? 'Add to Order — ${egp(_lineTotal)}'
                    : 'Select required options',
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

// ─────────────────────────────────────────────────────────────────────────────
//  OPTION GROUP CARD
// ─────────────────────────────────────────────────────────────────────────────
class _OptionGroupCard extends StatefulWidget {
  final dynamic group;
  final String? selectedSingle;
  final Set<String> selectedMulti;
  final void Function(String) onToggleSingle;
  final void Function(String) onToggleMulti;
  const _OptionGroupCard(
      {required this.group,
      required this.selectedSingle,
      required this.selectedMulti,
      required this.onToggleSingle,
      required this.onToggleMulti});
  @override
  State<_OptionGroupCard> createState() => _OptionGroupCardState();
}

class _OptionGroupCardState extends State<_OptionGroupCard> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  @override
  void initState() {
    super.initState();
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
    final g = widget.group;
    final allOpts = g.items as List;
    final showSearch = allOpts.length > 5;
    final opts = _query.isEmpty
        ? allOpts
        : allOpts
            .where((o) => (o.name as String).toLowerCase().contains(_query))
            .toList();
    final selCount = g.isMultiSelect
        ? widget.selectedMulti.length
        : (widget.selectedSingle != null ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: selCount > 0
                ? AppColors.primary.withOpacity(0.2)
                : const Color(0xFFECE8E0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(
                child: Row(children: [
              Text(g.displayName.toString().toUpperCase(),
                  style: cairo(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.7)),
              const SizedBox(width: 6),
              if (g.isRequired) const _Pill('Required', AppColors.danger),
              if (g.isMultiSelect) ...[
                const SizedBox(width: 4),
                const _Pill('Multi', AppColors.primary)
              ],
            ])),
            if (selCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$selCount',
                    style: cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
          ]),
        ),
        if (showSearch) ...[
          const SizedBox(height: 10),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F0EB),
                    borderRadius: BorderRadius.circular(9)),
                child: TextField(
                    controller: _searchCtrl,
                    style: cairo(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search options…',
                      hintStyle:
                          cairo(fontSize: 13, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 15, color: AppColors.textMuted),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: _searchCtrl.clear,
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: AppColors.textMuted))
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      isDense: true,
                      filled: false,
                    )),
              )),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: opts.isEmpty
              ? Text('No options match "$_query"',
                  style: cairo(fontSize: 12, color: AppColors.textMuted))
              : Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: opts.map((opt) {
                    final sel = g.isMultiSelect
                        ? widget.selectedMulti.contains(opt.id)
                        : widget.selectedSingle == opt.id;
                    return _Chip(
                      label: normaliseName(opt.name as String),
                      sublabel: (opt.price as int) > 0
                          ? '+${egp(opt.price as int)}'
                          : null,
                      selected: sel,
                      checkbox: g.isMultiSelect,
                      onTap: () => g.isMultiSelect
                          ? widget.onToggleMulti(opt.id as String)
                          : widget.onToggleSingle(opt.id as String),
                    );
                  }).toList()),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CART PANEL (tablet sidebar)
// ─────────────────────────────────────────────────────────────────────────────
class _CartPanel extends StatelessWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // Adaptive cart width: 26% of screen, clamped 280–380px
    final cartW = (w * 0.26).clamp(280.0, 380.0);
    final cart = context.watch<CartProvider>();

    return Container(
      width: cartW,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
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
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${cart.count}',
                        style: cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  )),
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
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('Clear',
                      style: cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger)),
                ),
              ),
          ]),
        ),
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
                  itemBuilder: (_, i) => _CartRow(index: i)),
        )),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Clear Order?',
                  style: cairo(fontWeight: FontWeight.w700)),
              content: Text('Remove all items from the cart.', style: cairo()),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: cairo(color: AppColors.textSecondary))),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.read<CartProvider>().clear();
                  },
                  child: Text('Clear',
                      style: cairo(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ));
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 130,
              height: 130,
              child: Lottie.asset('assets/lottie/empty_cart.json',
                  fit: BoxFit.contain, repeat: true)),
          const SizedBox(height: 8),
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
          border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(
                  item.itemName +
                      (item.sizeLabel != null
                          ? ' · ${normaliseName(item.sizeLabel!)}'
                          : ''),
                  style: cairo(
                      fontSize: 13, fontWeight: FontWeight.w600, height: 1.3))),
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
                            borderRadius: BorderRadius.circular(5)),
                        child: Text(
                            a.priceModifier > 0
                                ? '${normaliseName(a.name)} +${egp(a.priceModifier)}'
                                : normaliseName(a.name),
                            style: cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ))
                  .toList()),
        ],
        const SizedBox(height: 8),
        Row(children: [
          _InlineBtn(
              icon: Icons.remove,
              onTap: () => cart.setQty(index, item.quantity - 1)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${item.quantity}',
                  style: cairo(fontSize: 14, fontWeight: FontWeight.w700))),
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
                    borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Icon(Icons.delete_outline_rounded,
                    size: 15, color: AppColors.danger)),
          ),
        ]),
      ]),
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
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
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
                        child: FadeTransition(opacity: anim, child: child)),
                    child: Text(egp(cart.total),
                        key: ValueKey(cart.total),
                        style: cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ),
                ])),
        const SizedBox(height: 4),
        AppButton(
            label: 'Checkout',
            width: double.infinity,
            height: 50,
            icon: Icons.arrow_forward_rounded,
            onTap: () => CheckoutSheet.show(context)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHECKOUT SHEET
//  FIXED: saves to offline queue when network is unavailable.
// ─────────────────────────────────────────────────────────────────────────────
class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});
  static void show(BuildContext ctx) => showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CheckoutSheet());
  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  bool _loading = false;
  String? _error;
  final _customerCtrl = TextEditingController();
  static const _methods = ['cash', 'card'];

  @override
  void dispose() {
    _customerCtrl.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    final cart = context.read<CartProvider>();
    final shift = context.read<ShiftProvider>().shift;
    final sync = context.read<OfflineSyncService>();
    final customer =
        _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim();

    if (shift == null) {
      setState(() => _error = 'No open shift');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    // ── OFFLINE PATH ──────────────────────────────────────────────────────
    if (!sync.isOnline) {
      final pending = PendingOrder(
        localId: const Uuid().v4(),
        branchId: shift.branchId,
        shiftId: shift.id,
        paymentMethod: cart.payment,
        customerName: customer,
        discountType: cart.discountTypeStr,
        discountValue: cart.discountValue,
        items: cart.items.toList(),
        createdAt: DateTime.now(),
      );
      await sync.savePending(pending);
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order saved offline — will sync when connected'),
          backgroundColor: Color(0xFF856404),
          duration: Duration(seconds: 4),
        ));
      }
      return;
    }

    // ── ONLINE PATH ───────────────────────────────────────────────────────
    try {
      final order = await orderApi.create(
        branchId: shift.branchId,
        shiftId: shift.id,
        paymentMethod: cart.payment,
        items: cart.items.toList(),
        customerName: customer,
        discountType: cart.discountTypeStr,
        discountValue: cart.discountValue,
        idempotencyKey: const Uuid().v4(),
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
      // If we lost connection mid-flight, queue it
      if (e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout)) {
        final pending = PendingOrder(
          localId: const Uuid().v4(),
          branchId: shift.branchId,
          shiftId: shift.id,
          paymentMethod: cart.payment,
          customerName: customer,
          discountType: cart.discountTypeStr,
          discountValue: cart.discountValue,
          items: cart.items.toList(),
          createdAt: DateTime.now(),
        );
        await context.read<OfflineSyncService>().savePending(pending);
        cart.clear();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Connection lost — order saved offline'),
            backgroundColor: Color(0xFF856404),
            duration: Duration(seconds: 4),
          ));
        }
      } else {
        setState(() {
          _error = 'Failed to place order — please retry';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final mq = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 14, 24, mq.viewInsets.bottom + 28),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text('Checkout',
                style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            // Totals
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(14)),
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
            // Customer
            Text('CUSTOMER NAME (OPTIONAL)',
                style: cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
                controller: _customerCtrl,
                textCapitalization: TextCapitalization.words,
                style: cairo(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. Ahmed',
                  hintStyle: cairo(fontSize: 15, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.textMuted),
                )),
            const SizedBox(height: 18),
            // Payment
            Text('PAYMENT',
                style: cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1)),
            const SizedBox(height: 10),
            Row(
                children: _methods.map((m) {
              final sel = cart.payment == m;
              final label = m[0].toUpperCase() + m.substring(1);
              final icon = m == 'cash'
                  ? Icons.payments_outlined
                  : Icons.credit_card_rounded;
              return Expanded(
                  child: GestureDetector(
                onTap: () => cart.setPayment(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      color: sel ? AppColors.primary : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : const Color(0xFFE8E8E8))),
                  child: Column(children: [
                    Icon(icon,
                        size: 22,
                        color: sel ? Colors.white : AppColors.textSecondary),
                    const SizedBox(height: 6),
                    Text(label,
                        style: cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                sel ? Colors.white : AppColors.textSecondary)),
                  ]),
                ),
              ));
            }).toList()),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 15, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Text(_error!,
                        style: cairo(fontSize: 13, color: AppColors.danger)),
                  ])),
            ],
            const SizedBox(height: 20),
            AppButton(
                label: 'Place Order',
                loading: _loading,
                width: double.infinity,
                height: 52,
                icon: Icons.check_rounded,
                onTap: _place),
          ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECEIPT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class ReceiptSheet extends StatefulWidget {
  final Order order;
  final int total;
  const ReceiptSheet({super.key, required this.order, required this.total});

  static void show(BuildContext ctx,
          {required Order order, required int total}) =>
      showModalBottomSheet(
          context: ctx,
          backgroundColor: Colors.transparent,
          builder: (_) => ReceiptSheet(order: order, total: total));

  @override
  State<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<ReceiptSheet> {
  bool _printing = false;
  String? _printError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _print();
    });
  }

  Future<void> _print() async {
    final bp = context.read<BranchProvider>();
    if (!bp.hasPrinter) return;
    setState(() {
      _printing = true;
      _printError = null;
    });
    final err = await PrinterService.print(
      ip: bp.printerIp!,
      port: bp.printerPort,
      order: widget.order,
      branchName: bp.branchName,
      brand: bp.printerBrand!,
    );
    if (mounted) {
      setState(() {
        _printing = false;
        _printError = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        SizedBox(
            width: 120,
            height: 120,
            child: Lottie.asset('assets/lottie/success.json',
                repeat: false, fit: BoxFit.contain)),
        const SizedBox(height: 8),
        Text('Order Placed!',
            style: cairo(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Order #${o.orderNumber}',
            style: cairo(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            LabelValue(
                'Payment',
                o.paymentMethod[0].toUpperCase() +
                    o.paymentMethod.substring(1).replaceAll('_', ' ')),
            if (o.customerName != null && o.customerName!.isNotEmpty)
              LabelValue('Customer', o.customerName!),
            LabelValue('Total', egp(o.totalAmount), bold: true),
            LabelValue('Time', timeShort(o.createdAt)),
          ]),
        ),
        const SizedBox(height: 16),
        _printing
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 10),
                Text('Printing…',
                    style: cairo(fontSize: 13, color: AppColors.textSecondary)),
              ])
            : GestureDetector(
                onTap: _print,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.print_rounded,
                        size: 16,
                        color: _printError != null
                            ? AppColors.danger
                            : AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                        _printError != null ? 'Retry Print' : 'Reprint Receipt',
                        style: cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _printError != null
                                ? AppColors.danger
                                : AppColors.primary)),
                  ]),
                ),
              ),
        const SizedBox(height: 16),
        AppButton(
            label: 'New Order',
            width: double.infinity,
            height: 52,
            icon: Icons.add_rounded,
            onTap: () => Navigator.pop(context)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: cairo(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.7));
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
          borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: cairo(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3)));
}

class _Chip extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final bool checkbox;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      this.sublabel,
      required this.selected,
      required this.checkbox,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFFF5F0EB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? AppColors.primary : const Color(0xFFE4DDD4),
                width: selected ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (checkbox) ...[
            Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 15,
                color: selected ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary)),
          if (sublabel != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.2)
                      : AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(sublabel!,
                  style: cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.primary)),
            ),
          ],
        ]),
      ));
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
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textPrimary)));
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
              border: Border.all(color: const Color(0xFFE0E0E0))),
          alignment: Alignment.center,
          child: Icon(icon, size: 13, color: AppColors.textPrimary)));
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
              color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textPrimary)));
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
      ]));
}
