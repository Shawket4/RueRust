import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:rue_pos/core/api/client.dart';
import 'package:rue_pos/core/api/menu_api.dart';
import 'package:rue_pos/core/models/pending_action.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/order_api.dart';
import '../../core/api/discount_api.dart';
import '../../core/api/recipe_api.dart';
import '../../core/models/discount.dart';
import '../../core/models/cart.dart';
import '../../core/models/menu.dart';
import '../../core/models/order.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/cart_notifier.dart';
import '../../core/providers/menu_notifier.dart';
import '../../core/providers/order_history_notifier.dart';
import '../../core/providers/shift_notifier.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_queue.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatting.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/label_value.dart';

const _skeletonBase = Color(0xFFEEF0F4);
const _skeletonHighlight = Color(0xFFE4E7ED);

// Top-level helpers shared by CheckoutSheet and its sub-widgets.
Color _methodColor(String m) => switch (m) {
      'cash' => AppColors.success,
      'card' => const Color(0xFF7C3AED),
      'talabat_online' => const Color(0xFFFF6B00),
      'talabat_cash' => const Color(0xFFFF6B00),
      _ => AppColors.primary,
    };

String _methodLabel(String m) => switch (m) {
      'cash' => 'Cash',
      'card' => 'Card',
      'talabat_online' => 'Talabat Online',
      'talabat_cash' => 'Talabat Cash',
      _ => m,
    };

bool _isCashMethod(String m) => m == 'cash' || m == 'talabat_cash';

// Safe sentinel — no orgId field, matches current AddonItem constructor
AddonItem _emptyAddon() => const AddonItem(
    id: '',
    name: '',
    addonType: '',
    defaultPrice: 0,
    isActive: false,
    displayOrder: 0);

// ─────────────────────────────────────────────────────────────────────────────
//  ROOT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});
  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgId = ref.read(authProvider).user?.orgId;
      if (orgId != null) ref.read(menuProvider.notifier).load(orgId);
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
    final isTablet = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      backgroundColor: AppColors.bg,
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
                Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
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
class _TopBar extends ConsumerWidget {
  final TextEditingController ctrl;
  final String query;
  const _TopBar({required this.ctrl, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final sync = ref.watch(offlineQueueProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final isTablet = MediaQuery.of(context).size.width >= 768;
    final cachedAt = ref.watch(menuProvider).cachedAt;
    final lastSynced = cachedAt != null ? timeShort(cachedAt) : '—';

    final bar = Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(children: [
        _IconBtn(
            icon: Icons.arrow_back_rounded, onTap: () => context.go('/home')),
        const SizedBox(width: 6),
        _SyncBtn(),
        const SizedBox(width: 6),
        Text(lastSynced,
            style: cairo(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border)),
            child: TextField(
              controller: ctrl,
              style: cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search menu…',
                hintStyle: cairo(fontSize: 14, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 17, color: AppColors.textMuted),
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
                      boxShadow: AppShadows.primaryGlow(),
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

    if (!isOnline || sync.orderCount > 0) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        bar,
        if (!isOnline)
          const _StatusBanner(
              color: Color(0xFFFFF3CD),
              icon: Icons.wifi_off_rounded,
              text: 'Offline — cached menu. Orders will sync when connected.',
              textColor: Color(0xFF856404)),
        if (isOnline && sync.orderCount > 0)
          _StatusBanner(
              color: const Color(0xFFCFE2FF),
              icon: Icons.sync_rounded,
              text:
                  'Syncing ${sync.orderCount} offline order${sync.orderCount == 1 ? "" : "s"}…',
              textColor: const Color(0xFF084298),
              animate: true),
      ]);
    }
    return bar;
  }
}

class _StatusBanner extends StatelessWidget {
  final Color color, textColor;
  final IconData icon;
  final String text;
  final bool animate;
  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.text,
    required this.textColor,
    this.animate = false,
  });

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
              : Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: cairo(fontSize: 11, color: textColor))),
        ]),
      );
}

class _SyncBtn extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SyncBtn> createState() => _SyncBtnState();
}

class _SyncBtnState extends ConsumerState<_SyncBtn>
    with SingleTickerProviderStateMixin {
  bool _syncing = false;
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    _spinCtrl.repeat();
    try {
      final orgId = ref.read(authProvider).user?.orgId;
      if (orgId != null) {
        await ref.read(menuProvider.notifier).load(orgId, force: true);
      }
    } finally {
      if (mounted) {
        _spinCtrl.stop();
        _spinCtrl.reset();
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _sync,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.border)),
          alignment: Alignment.center,
          child: RotationTransition(
            turns: _spinCtrl,
            child: Icon(Icons.sync_rounded,
                size: 18,
                color: _syncing ? AppColors.primary : AppColors.textSecondary),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CATEGORY RAIL
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryRail extends ConsumerWidget {
  const _CategoryRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuProvider);
    return Container(
      width: 88,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: AppColors.borderLight))),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: menu.categories.length,
        itemBuilder: (_, i) {
          final cat = menu.categories[i];
          final sel = cat.id == menu.selectedCategoryId;
          return GestureDetector(
            onTap: () => ref.read(menuProvider.notifier).selectCategory(cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(children: [
                Icon(_CatStyle.of(cat.name).icon,
                    size: 20, color: sel ? Colors.white : AppColors.textMuted),
                const SizedBox(height: 5),
                Text(normaliseName(cat.name),
                    style: cairo(
                        fontSize: 9,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : AppColors.textSecondary,
                        height: 1.2),
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  MENU GRID
// ─────────────────────────────────────────────────────────────────────────────
class _MenuGrid extends ConsumerWidget {
  const _MenuGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuProvider);
    final items = menu.filtered.where((i) => i.isActive).toList();

    if (menu.isLoading) return _grid(8, (_, __) => const _MenuCardSkeleton());
    if (menu.error != null) {
      return _ErrorState(
        message: menu.error!,
        onRetry: () {
          final orgId = ref.read(authProvider).user?.orgId;
          if (orgId != null)
            ref.read(menuProvider.notifier).load(orgId, force: true);
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
class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = ref
        .watch(menuProvider)
        .items
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
//  MOBILE CART FAB + SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _MobileCartFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox.shrink();
    return FloatingActionButton.extended(
      onPressed: () => _MobileCartSheet.show(context),
      backgroundColor: AppColors.primary,
      elevation: 4,
      label: Text('${cart.count} items · ${egp(cart.total)}',
          style: cairo(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      icon: const Icon(Icons.shopping_bag_outlined,
          size: 18, color: Colors.white),
    );
  }
}

class _MobileCartSheet extends ConsumerWidget {
  const _MobileCartSheet();

  static void show(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _MobileCartSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: AppRadius.sheetRadius),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(children: [
            Text('Order',
                style: cairo(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            _CountBadge(count: cart.count),
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: () {
                  ref.read(cartProvider.notifier).clear();
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
        const SizedBox(height: 10),
        Container(height: 1, color: AppColors.border),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Text('Cart is empty',
                      style: cairo(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _CartRow(index: i)),
        ),
        if (!cart.isEmpty) const _CartFooter(),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETONS
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
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.card),
            child: Column(children: [
              Expanded(
                  child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.md)),
                      child: Container(color: c))),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Expanded(
                      child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(width: 12),
                  Container(
                      width: 40,
                      height: 10,
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
//  CATEGORY STYLE MAP
// ─────────────────────────────────────────────────────────────────────────────
class _CatStyle {
  final IconData icon;
  final Color bgTop, bgBottom, iconColor, accent;
  const _CatStyle({
    required this.icon,
    required this.bgTop,
    required this.bgBottom,
    required this.iconColor,
    required this.accent,
  });

  static _CatStyle of(String name) {
    final n = name.toLowerCase();
    if (n.contains('matcha'))
      return const _CatStyle(
          icon: Icons.eco_rounded,
          bgTop: Color(0xFFE8F5E9),
          bgBottom: Color(0xFFC8E6C9),
          iconColor: Color(0xFF2E7D32),
          accent: Color(0xFF388E3C));
    if (n.contains('latte') ||
        n.contains('espresso') ||
        n.contains('americano') ||
        n.contains('cappuc') ||
        n.contains('flat') ||
        n.contains('cortado') ||
        n.contains('coffee') ||
        n.contains('v60') ||
        n.contains('blended') ||
        n.contains('cold brew'))
      return const _CatStyle(
          icon: Icons.coffee_rounded,
          bgTop: Color(0xFFF5EEE6),
          bgBottom: Color(0xFFEDD9C0),
          iconColor: Color(0xFF5D4037),
          accent: Color(0xFF795548));
    if (n.contains('chocolate') || n.contains('mocha'))
      return const _CatStyle(
          icon: Icons.coffee_rounded,
          bgTop: Color(0xFFF3E5E5),
          bgBottom: Color(0xFFE8CECE),
          iconColor: Color(0xFF6D4C41),
          accent: Color(0xFF8D3A3A));
    if (n.contains('croissant') ||
        n.contains('brownie') ||
        n.contains('cookie') ||
        n.contains('pastry') ||
        n.contains('pastries') ||
        n.contains('cake') ||
        n.contains('waffle'))
      return const _CatStyle(
          icon: Icons.bakery_dining_rounded,
          bgTop: Color(0xFFFFF8E8),
          bgBottom: Color(0xFFFFF0C8),
          iconColor: Color(0xFFE65100),
          accent: Color(0xFFF57C00));
    if (n.contains('sandwich') ||
        n.contains('chicken') ||
        n.contains('turkey') ||
        n.contains('food'))
      return const _CatStyle(
          icon: Icons.lunch_dining_rounded,
          bgTop: Color(0xFFFFF3E0),
          bgBottom: Color(0xFFFFE0B2),
          iconColor: Color(0xFFE64A19),
          accent: Color(0xFFEF6C00));
    if (n.contains('affogato') || n.contains('ice cream'))
      return const _CatStyle(
          icon: Icons.icecream_rounded,
          bgTop: Color(0xFFF3E5F5),
          bgBottom: Color(0xFFE1BEE7),
          iconColor: Color(0xFF7B1FA2),
          accent: Color(0xFF9C27B0));
    if (n.contains('lemon') ||
        n.contains('lemonade') ||
        n.contains('refresher') ||
        n.contains('juice'))
      return const _CatStyle(
          icon: Icons.local_drink_rounded,
          bgTop: Color(0xFFFFFDE7),
          bgBottom: Color(0xFFFFF9C4),
          iconColor: Color(0xFFF57F17),
          accent: Color(0xFFFBC02D));
    if (n.contains('tea') || n.contains('chai'))
      return const _CatStyle(
          icon: Icons.emoji_food_beverage_rounded,
          bgTop: Color(0xFFE8F5E9),
          bgBottom: Color(0xFFC8E6C9),
          iconColor: Color(0xFF388E3C),
          accent: Color(0xFF43A047));
    if (n.contains('water') || n.contains('sparkling'))
      return const _CatStyle(
          icon: Icons.water_drop_rounded,
          bgTop: Color(0xFFE3F2FD),
          bgBottom: Color(0xFFBBDEFB),
          iconColor: Color(0xFF1565C0),
          accent: Color(0xFF1976D2));
    if (n.contains('iced'))
      return const _CatStyle(
          icon: Icons.ac_unit_rounded,
          bgTop: Color(0xFFE3F2FD),
          bgBottom: Color(0xFFBBDEFB),
          iconColor: Color(0xFF0277BD),
          accent: Color(0xFF0288D1));
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
class _MenuCard extends ConsumerStatefulWidget {
  final MenuItem item;
  const _MenuCard({required this.item});
  @override
  ConsumerState<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends ConsumerState<_MenuCard>
    with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final style = _CatStyle.of(item.name);
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) async {
        await _pressCtrl.reverse();
        if (mounted) ItemDetailSheet.show(context, item);
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressAnim,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                  color: style.accent.withOpacity(0.1),
                  blurRadius: 14,
                  offset: const Offset(0, 4)),
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Column(children: [
              Expanded(
                  child: Stack(children: [
                Positioned.fill(
                    child: hasImage
                        ? Image.network(item.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, prog) =>
                                prog == null ? child : _ImageSkeleton(),
                            errorBuilder: (_, __, ___) => _CardBg(style: style))
                        : _CardBg(style: style)),
                if (!hasImage)
                  Center(
                      child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: style.iconColor.withOpacity(0.11),
                        shape: BoxShape.circle),
                    child: Icon(style.icon, size: 26, color: style.iconColor),
                  )),
              ])),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                          width: 3,
                          height: 26,
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

class _CardBg extends StatelessWidget {
  final _CatStyle style;
  const _CardBg({required this.style});
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
class ItemDetailSheet extends ConsumerStatefulWidget {
  final MenuItem item;
  // When non-null the sheet is in edit mode: pre-populate from existingItem
  // and call replaceAt(editIndex) instead of add().
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
  // Unslotted global extras: addonItemId → quantity
  final Map<String, int> _extras = {};

  // Optional fields state
  List<OptionalField> _optionalFields = [];
  bool _optionalFieldsLoading = false;
  final Set<String> _selectedOptionals = {};

  // Recipe preview state
  bool _recipeLoading = false;
  List<RecipeIngredient>? _recipeResult;
  String? _recipeError;

  bool get _isEdit => widget.editIndex != null && widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (widget.item.sizes.isNotEmpty) {
      _selectedSize = widget.item.sizes.first.label;
    }

    // Load optional fields for this drink
    _loadOptionalFields();

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
        // Find the addon's type
        final addon = allAddons.where((a) => a.id == sa.addonItemId);
        if (addon.isEmpty) continue;
        final addonType = addon.first.addonType;

        // Find matching slot
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
        } else if (slottedTypes.contains(addonType) == false) {
          // Goes into extras
          _extras[sa.addonItemId] = sa.quantity;
        }
      }
    }
  }

  // ── Pricing ───────────────────────────────────────────────

  int get _unitPrice => widget.item.priceForSize(_selectedSize);

  int get _optionalsTotal => _optionalFields
      .where((f) => _selectedOptionals.contains(f.id))
      .fold(0, (s, f) => s + f.price);

  int get _addonsTotal {
    final allAddons = ref.read(menuProvider).allAddons;
    int t = 0;

    for (final aId in _single.values) {
      final matches = allAddons.where((a) => a.id == aId);
      if (matches.isNotEmpty) t += matches.first.defaultPrice;
    }
    for (final qtyMap in _multi.values) {
      for (final entry in qtyMap.entries) {
        final matches = allAddons.where((a) => a.id == entry.key);
        if (matches.isNotEmpty) t += matches.first.defaultPrice * entry.value;
      }
    }
    for (final entry in _extras.entries) {
      final matches = allAddons.where((a) => a.id == entry.key);
      if (matches.isNotEmpty) t += matches.first.defaultPrice * entry.value;
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

  void _toggleMulti(String slotId, String addonId, int? maxSel) => setState(() {
        final m = _multi.putIfAbsent(slotId, () => {});
        if (m.containsKey(addonId)) {
          m.remove(addonId);
          if (m.isEmpty) _multi.remove(slotId);
        } else {
          if (maxSel != null && m.length >= maxSel) {
            // At max: replace oldest (clear all then add)
            m.clear();
          }
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

  void _toggleExtra(String addonId) => setState(() {
        if (_extras.containsKey(addonId)) {
          _extras.remove(addonId);
        } else {
          _extras[addonId] = 1;
        }
        _clearRecipe();
      });

  void _incrementExtra(String addonId) => setState(() {
        _extras[addonId] = (_extras[addonId] ?? 1) + 1;
        _clearRecipe();
      });

  void _decrementExtra(String addonId) => setState(() {
        final cur = _extras[addonId] ?? 1;
        if (cur <= 1) {
          _extras.remove(addonId);
        } else {
          _extras[addonId] = cur - 1;
        }
        _clearRecipe();
      });

  // ── Recipe preview ────────────────────────────────────────

  void _clearRecipe() {
    _recipeResult = null;
    _recipeError = null;
  }

  Future<void> _fetchRecipe() async {
    setState(() {
      _recipeLoading = true;
      _recipeError = null;
    });
    try {
      final addons = _buildSelectedAddons();
      final optionals = _buildSelectedOptionals();
      final result = await ref.read(recipeApiProvider).preview(
            menuItemId: widget.item.id,
            sizeLabel: _selectedSize,
            addons: addons,
            optionals: optionals,
          );
      if (mounted)
        setState(() {
          _recipeResult = result;
          _recipeLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _recipeError = 'Could not load recipe';
          _recipeLoading = false;
        });
    }
  }

  void _showRecipeSheet() {
    _fetchRecipe();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Mirror loading state into sheet via listen
          return _RecipeSheet(
            itemName: normaliseName(widget.item.name),
            sizeLabel: _selectedSize,
            loading: _recipeLoading,
            result: _recipeResult,
            error: _recipeError,
            onRefresh: () {
              _fetchRecipe();
              // Sheet will pick up state changes on next frame via
              // the parent setState calls in _fetchRecipe
            },
          );
        },
      ),
    );
  }

  // ── Optional fields ──────────────────────────────────────

  Future<void> _loadOptionalFields() async {
    setState(() => _optionalFieldsLoading = true);
    try {
      final fields =
          await ref.read(menuApiProvider).optionalFields(widget.item.id);
      if (mounted) {
        setState(() {
          _optionalFields = fields.where((f) => f.isActive).toList();
          _optionalFieldsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _optionalFieldsLoading = false);
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
            priceModifier: a.defaultPrice,
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
              priceModifier: a.defaultPrice,
              quantity: entry.value));
        }
      }
    }

    // Extras with quantities
    for (final entry in _extras.entries) {
      final a = findAddon(entry.key);
      if (a != null) {
        result.add(SelectedAddon(
            addonItemId: a.id,
            name: a.name,
            priceModifier: a.defaultPrice,
            quantity: entry.value));
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
    final allAddons = ref.watch(menuProvider).allAddons;
    final byType = ref.watch(menuProvider).addonsByType;

    // Types covered by defined slots on this drink
    final slottedTypes = widget.item.addonSlots.map((s) => s.addonType).toSet();

    // Global addon types not covered by any custom slot — shown in Extras
    const globalTypes = ['milk_type', 'coffee_type', 'extra'];
    final extrasAddons = globalTypes
        .where((t) => !slottedTypes.contains(t))
        .expand((t) => byType[t] ?? <AddonItem>[])
        .where((a) => a.isActive)
        .toList();

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
                              onTap: () => setState(() {
                                _selectedSize = s.label;
                                _clearRecipe();
                              }),
                            ))
                        .toList()),
                const SizedBox(height: 20),
              ],

              // Custom slots
              for (final s in widget.item.addonSlots
                ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder))) ...[
                _AddonCard(
                  title: s.displayName,
                  isRequired: s.isRequired,
                  isMulti: (s.maxSelections ?? 2) > 1,
                  maxSelections: s.maxSelections,
                  items: (byType[s.addonType] ?? [])
                      .where((a) => a.isActive)
                      .toList(),
                  selectedSingle: _single[s.id],
                  selectedMulti: _multi[s.id] ?? {},
                  onToggleSingle: (aId) =>
                      _toggleSingle(s.id, aId, s.isRequired),
                  onToggleMulti: (aId) =>
                      _toggleMulti(s.id, aId, s.maxSelections),
                  onIncrement: (aId) => _incrementMulti(s.id, aId),
                  onDecrement: (aId) => _decrementMulti(s.id, aId),
                ),
                const SizedBox(height: 12),
              ],

              // Extras — global types not covered by a custom slot
              if (extrasAddons.isNotEmpty) ...[
                _AddonCard(
                  title: 'Extras',
                  isRequired: false,
                  isMulti: true,
                  maxSelections: null,
                  items: extrasAddons,
                  selectedSingle: null,
                  selectedMulti: _extras,
                  onToggleSingle: (_) {},
                  onToggleMulti: (aId) => _toggleExtra(aId),
                  onIncrement: (aId) => _incrementExtra(aId),
                  onDecrement: (aId) => _decrementExtra(aId),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 6),

              // Optionals section
              if (_optionalFieldsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))),
                )
              else if (_optionalFields.isNotEmpty) ...[
                _OptionalFieldsCard(
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

// ─────────────────────────────────────────────────────────────────────────────
//  RECIPE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _RecipeSheet extends StatelessWidget {
  final String itemName;
  final String? sizeLabel;
  final bool loading;
  final List<RecipeIngredient>? result;
  final String? error;
  final VoidCallback onRefresh;

  const _RecipeSheet({
    required this.itemName,
    required this.sizeLabel,
    required this.loading,
    required this.result,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: AppRadius.sheetRadius),
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2))))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Row(children: [
            const Icon(Icons.science_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              '$itemName${sizeLabel != null ? " · ${normaliseName(sizeLabel!)}" : ""} — Recipe',
              style: cairo(fontSize: 14, fontWeight: FontWeight.w700),
            )),
            if (!loading)
              GestureDetector(
                onTap: onRefresh,
                child: Icon(Icons.refresh_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
          ]),
        ),
        Container(height: 1, color: AppColors.border),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline,
                          size: 32, color: AppColors.border),
                      const SizedBox(height: 8),
                      Text(error!,
                          style: cairo(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: onRefresh, child: const Text('Retry')),
                    ]))
                  : result == null || result!.isEmpty
                      ? Center(
                          child: Text('No recipe data',
                              style: cairo(color: AppColors.textMuted)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: result!.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: AppColors.borderLight),
                          itemBuilder: (_, i) {
                            final ing = result![i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.only(right: 10, top: 1),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ing.isBase
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                ),
                                Expanded(
                                    child: Text(ing.name,
                                        style: cairo(
                                            fontSize: 13,
                                            fontWeight: ing.isBase
                                                ? FontWeight.w600
                                                : FontWeight.w500))),
                                Text(
                                    '${ing.quantity % 1 == 0 ? ing.quantity.toInt() : ing.quantity.toStringAsFixed(1)} ${ing.unit}',
                                    style: cairo(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: (ing.isBase
                                              ? AppColors.primary
                                              : AppColors.textMuted)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(ing.isBase ? 'base' : 'addon',
                                      style: cairo(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: ing.isBase
                                              ? AppColors.primary
                                              : AppColors.textMuted)),
                                ),
                              ]),
                            );
                          }),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ADDON CARD
// ─────────────────────────────────────────────────────────────────────────────
class _AddonCard extends StatefulWidget {
  final String title;
  final bool isRequired;
  final bool isMulti;
  final int? maxSelections;
  final List<AddonItem> items;
  // For single-select: the selected addonItemId
  final String? selectedSingle;
  // For multi-select: addonItemId → quantity (int)
  // Accepts both Map<String,int> and Set<String> for extras compatibility
  final dynamic selectedMulti;
  final void Function(String) onToggleSingle;
  final void Function(String) onToggleMulti;
  final void Function(String) onIncrement;
  final void Function(String) onDecrement;

  const _AddonCard({
    required this.title,
    required this.isRequired,
    required this.isMulti,
    required this.maxSelections,
    required this.items,
    required this.selectedSingle,
    required this.selectedMulti,
    required this.onToggleSingle,
    required this.onToggleMulti,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  State<_AddonCard> createState() => _AddonCardState();
}

class _AddonCardState extends State<_AddonCard> {
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

  // selectedMulti is Map<String,int> for slots, Set<String> or Map<String,int>
  // for extras — normalise to a qty lookup
  bool _isSelected(String id) {
    final m = widget.selectedMulti;
    if (m is Map<String, int>) return m.containsKey(id);
    if (m is Set<String>) return m.contains(id);
    return false;
  }

  int _qty(String id) {
    final m = widget.selectedMulti;
    if (m is Map<String, int>) return m[id] ?? 1;
    return 1;
  }

  int get _selCount {
    if (!widget.isMulti) return widget.selectedSingle != null ? 1 : 0;
    final m = widget.selectedMulti;
    if (m is Map<String, int>) return m.length;
    if (m is Set<String>) return m.length;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final showSearch = widget.items.length > 5;
    final opts = _query.isEmpty
        ? widget.items
        : widget.items
            .where((o) => o.name.toLowerCase().contains(_query))
            .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: _selCount > 0
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(
                child: Row(children: [
              Text(widget.title.toUpperCase(),
                  style: cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.7)),
              const SizedBox(width: 6),
              if (widget.isRequired) const _Pill('Required', AppColors.danger),
              if (widget.isMulti) ...[
                const SizedBox(width: 4),
                const _Pill('Multi', AppColors.primary),
              ],
              if (widget.maxSelections != null) ...[
                const SizedBox(width: 4),
                _Pill('Max ${widget.maxSelections}', AppColors.textSecondary),
              ],
            ])),
            if (_selCount > 0) _CountBadge(count: _selCount),
          ]),
        ),

        // Search
        if (showSearch) ...[
          const SizedBox(height: 10),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: AppColors.border)),
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

        // Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: opts.isEmpty
              ? Text('No match for "$_query"',
                  style: cairo(fontSize: 12, color: AppColors.textMuted))
              : Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: opts.map((opt) {
                    final sel = widget.isMulti
                        ? _isSelected(opt.id)
                        : widget.selectedSingle == opt.id;
                    final qty = _qty(opt.id);

                    // Multi-select selected chip: show qty stepper inline
                    if (widget.isMulti && sel) {
                      return _QtyChip(
                        label: normaliseName(opt.name),
                        price: opt.defaultPrice,
                        qty: qty,
                        onIncrement: () => widget.onIncrement(opt.id),
                        onDecrement: () => widget.onDecrement(opt.id),
                      );
                    }

                    return _Chip(
                      label: normaliseName(opt.name),
                      sublabel: opt.defaultPrice > 0
                          ? '+${egp(opt.defaultPrice)}'
                          : null,
                      selected: sel,
                      checkbox: widget.isMulti,
                      onTap: () => widget.isMulti
                          ? widget.onToggleMulti(opt.id)
                          : widget.onToggleSingle(opt.id),
                    );
                  }).toList()),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  QTY CHIP  — selected multi addon with inline +/- stepper
// ─────────────────────────────────────────────────────────────────────────────
class _QtyChip extends StatelessWidget {
  final String label;
  final int price;
  final int qty;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QtyChip({
    required this.label,
    required this.price,
    required this.qty,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: AppColors.primary, width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // Decrement / remove
          GestureDetector(
            onTap: onDecrement,
            child: Container(
              width: 30,
              height: 34,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, size: 13, color: Colors.white),
            ),
          ),
          // Label + qty
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              if (price > 0)
                Text('+${egp(price * qty)}',
                    style: cairo(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.8))),
            ]),
          ),
          // Qty badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4)),
            child: Text('$qty',
                style: cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          // Increment
          GestureDetector(
            onTap: onIncrement,
            child: Container(
              width: 30,
              height: 34,
              alignment: Alignment.center,
              child: const Icon(Icons.add, size: 13, color: Colors.white),
            ),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CART PANEL (tablet)
// ─────────────────────────────────────────────────────────────────────────────
class _CartPanel extends ConsumerWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = MediaQuery.of(context).size.width;
    final cartW = (w * 0.26).clamp(280.0, 360.0);
    final cart = ref.watch(cartProvider);

    return Container(
      width: cartW,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: AppColors.border))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Text('Order',
                style: cairo(fontSize: 15, fontWeight: FontWeight.w800)),
            if (!cart.isEmpty) ...[
              const SizedBox(width: 8),
              AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _CountBadge(
                      key: ValueKey(cart.count), count: cart.count)),
            ],
            const Spacer(),
            if (!cart.isEmpty)
              GestureDetector(
                onTap: () => _confirmClear(context, ref),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(AppRadius.xs)),
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
          child: cart.isEmpty ? const SizedBox.shrink() : const _CartFooter(),
        ),
      ]),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
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
                      ref.read(cartProvider.notifier).clear();
                    },
                    child: Text('Clear',
                        style: cairo(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700))),
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
              width: 110,
              height: 110,
              child: Lottie.asset('assets/lottie/empty_cart.json',
                  fit: BoxFit.contain, repeat: true)),
          const SizedBox(height: 8),
          Text('Cart is empty',
              style: cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text('Tap any item to add it',
              style: cairo(fontSize: 11, color: AppColors.textMuted)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CART ROW  — with edit button
// ─────────────────────────────────────────────────────────────────────────────
class _CartRow extends ConsumerWidget {
  final int index;
  const _CartRow({required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final item = cart.items[index];
    final menu = ref.watch(menuProvider);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border)),
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
                            borderRadius: BorderRadius.circular(AppRadius.xs)),
                        child: Text(
                            a.priceModifier > 0
                                ? '\${normaliseName(a.name)}\${a.quantity > 1 ? " ×\${a.quantity}" : ""} +\${egp(a.priceModifier * a.quantity)}'
                                : '\${normaliseName(a.name)}\${a.quantity > 1 ? " ×\${a.quantity}" : ""}',
                            style: cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ))
                  .toList()),
        ],
        if (item.optionals.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
              spacing: 4,
              runSpacing: 4,
              children: item.optionals
                  .map((o) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppRadius.xs)),
                        child: Text(
                            o.price > 0
                                ? '\${o.name} +\${egp(o.price)}'
                                : o.name,
                            style: cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning)),
                      ))
                  .toList()),
        ],
        const SizedBox(height: 8),
        Row(children: [
          _InlineBtn(
              icon: Icons.remove,
              onTap: () => ref
                  .read(cartProvider.notifier)
                  .setQty(index, item.quantity - 1)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${item.quantity}',
                  style: cairo(fontSize: 14, fontWeight: FontWeight.w700))),
          _InlineBtn(
              icon: Icons.add,
              onTap: () => ref
                  .read(cartProvider.notifier)
                  .setQty(index, item.quantity + 1)),
          const Spacer(),

          // Edit button — open ItemDetailSheet pre-populated
          GestureDetector(
            onTap: () {
              final menuItem = menu.items.where((m) => m.id == item.menuItemId);
              if (menuItem.isEmpty) return;
              ItemDetailSheet.show(
                context,
                menuItem.first,
                editIndex: index,
                existingItem: item,
              );
            },
            child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(AppRadius.xs)),
                alignment: Alignment.center,
                child: const Icon(Icons.edit_outlined,
                    size: 13, color: AppColors.primary)),
          ),

          // Delete button
          GestureDetector(
            onTap: () => ref.read(cartProvider.notifier).removeAt(index),
            child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(AppRadius.xs)),
                alignment: Alignment.center,
                child: const Icon(Icons.delete_outline_rounded,
                    size: 14, color: AppColors.danger)),
          ),
        ]),
      ]),
    );
  }
}

class _CartFooter extends ConsumerWidget {
  const _CartFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(children: [
        LabelValue('Subtotal', egp(cart.subtotal)),
        if (cart.discountAmount > 0)
          LabelValue('Discount', '− ${egp(cart.discountAmount)}',
              valueColor: AppColors.success),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
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
        const SizedBox(height: 2),
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

class _PaymentMethod {
  final String value, label;
  final IconData icon;
  final Color color;
  const _PaymentMethod(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});
}

const _kPaymentMethods = [
  _PaymentMethod(
      value: 'cash',
      label: 'Cash',
      icon: Icons.payments_outlined,
      color: AppColors.primary),
  _PaymentMethod(
      value: 'card',
      label: 'Card',
      icon: Icons.credit_card_rounded,
      color: AppColors.primary),
  _PaymentMethod(
      value: 'talabat_online',
      label: 'Talabat Online',
      icon: Icons.delivery_dining_rounded,
      color: Color(0xFFFF6B00)),
  _PaymentMethod(
      value: 'talabat_cash',
      label: 'Talabat Cash',
      icon: Icons.delivery_dining_rounded,
      color: Color(0xFFFF6B00)),
];

// ─────────────────────────────────────────────────────────────────────────────
//  CHECKOUT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key});

  static void show(BuildContext ctx) => showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CheckoutSheet());

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  bool _loading = false;
  String? _error;
  final _customerCtrl = TextEditingController();

  // Discount
  Discount? _selectedDiscount;
  List<Discount> _discounts = [];
  bool _discountsLoaded = false;

  // Cash tendered — only for cash/talabat_cash single-payment mode
  final _tenderedCtrl = TextEditingController();
  bool _showTendered = false;

  // Tip — shown in both single and split payment modes.
  final _tipCtrl = TextEditingController();
  String _tipPaymentMethod = 'cash';

  // Split payment.
  bool _isSplit = false;
  final Map<String, TextEditingController> _splitCtrs = {};
  final Set<String> _activeSplitMethods = {};

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
    final cart = ref.read(cartProvider);
    _showTendered = cart.payment == 'cash' || cart.payment == 'talabat_cash';
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _tenderedCtrl.dispose();
    _tipCtrl.dispose();
    for (final c in _splitCtrs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDiscounts() async {
    final orgId = ref.read(authProvider).user?.orgId;
    if (orgId == null) return;
    try {
      final list = await ref.read(discountApiProvider).list(orgId);
      if (mounted)
        setState(() {
          _discounts = list;
          _discountsLoaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => _discountsLoaded = true);
    }
  }

  void _toggleSplitMethod(String method) {
    setState(() {
      if (_activeSplitMethods.contains(method)) {
        _activeSplitMethods.remove(method);
        _splitCtrs[method]?.clear();
      } else {
        _activeSplitMethods.add(method);
        _splitCtrs.putIfAbsent(method, () => TextEditingController());
      }
    });
  }

  List<PaymentSplit> _buildSplits() {
    final splits = <PaymentSplit>[];
    for (final method in _activeSplitMethods) {
      final raw = double.tryParse(_splitCtrs[method]?.text ?? '');
      if (raw != null && raw > 0) {
        splits.add(PaymentSplit(method: method, amount: (raw * 100).round()));
      }
    }
    return splits;
  }

  // Tip is now available in both single and split modes.
  int? get _parsedTip {
    final v = double.tryParse(_tipCtrl.text);
    if (v == null || v <= 0) return null;
    return (v * 100).round();
  }

  // Whether the current tip method is a cash-based method.
  // Used to reduce change due (single mode) and reduce split balance target.
  bool get _tipIsCash => _isCashMethod(_tipPaymentMethod);

  Future<void> _place() async {
    final cart = ref.read(cartProvider);
    final shift = ref.read(shiftProvider).shift;
    final queue = ref.read(offlineQueueProvider.notifier);
    final isOnline = ref.read(isOnlineProvider);
    final customer =
        _customerCtrl.text.trim().isEmpty ? null : _customerCtrl.text.trim();

    if (_loading) return;
    if (cart.isEmpty) {
      setState(() => _error = 'Cart is empty');
      return;
    }
    if (shift == null) {
      setState(() => _error = 'No open shift');
      return;
    }
    if (!_isSplit && cart.payment.isEmpty) {
      setState(() => _error = 'Select a payment method');
      return;
    }

    final int? tip = _parsedTip;
    final String? tipMethod = tip != null ? _tipPaymentMethod : null;

    final int? tendered = _showTendered && !_isSplit
        ? (double.tryParse(_tenderedCtrl.text) != null
            ? (double.parse(_tenderedCtrl.text) * 100).round()
            : null)
        : null;

    // ── Single cash-mode validations ──────────────────────────────────────
    if (_showTendered && !_isSplit) {
      if (tendered == null || tendered == 0) {
        setState(() => _error = 'Enter the cash amount tendered');
        return;
      }
      if (tendered < cart.total) {
        setState(() => _error =
            'Tendered ${egp(tendered)} is less than total ${egp(cart.total)}');
        return;
      }
      // Only validate tip against change when the tip method is also cash.
      if (tip != null && _tipIsCash) {
        final change = tendered - cart.total;
        if (tip > change) {
          setState(() =>
              _error = 'Cash tip ${egp(tip)} exceeds change ${egp(change)}');
          return;
        }
      }
    }

    // ── Split-mode validation ──────────────────────────────────────────────
    // Split amounts must cover cartTotal. A cash tip comes out of the change
    // float of the cash split leg, so it reduces the required split total.
    List<PaymentSplit>? splits;
    if (_isSplit) {
      if (_activeSplitMethods.isEmpty) {
        setState(() => _error = 'Select at least one payment method');
        return;
      }
      splits = _buildSplits();
      if (splits.isEmpty) {
        setState(() => _error = 'Enter amounts for selected payment methods');
        return;
      }
      final splitTotal = splits.fold(0, (s, p) => s + p.amount);
      final expectedSplitTotal = cart.total - (_tipIsCash ? (tip ?? 0) : 0);
      if (splitTotal != expectedSplitTotal) {
        setState(() => _error =
            'Split total ${egp(splitTotal)} must equal ${egp(expectedSplitTotal)}');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final discountType =
        _selectedDiscount?.dtype ?? cart.discountType?.apiValue;
    final discountValue = _selectedDiscount?.value ?? cart.discountValue;
    final discountId = _selectedDiscount?.id;
    final paymentMethod = _isSplit
        ? (splits!.length == 1 ? splits.first.method : 'mixed')
        : cart.payment;

    if (!isOnline) {
      await queue.enqueueOrder(PendingOrder(
        localId: const Uuid().v4(),
        branchId: shift.branchId,
        shiftId: shift.id,
        paymentMethod: paymentMethod,
        customerName: customer,
        discountType: discountType,
        discountValue: discountValue,
        discountId: discountId,
        amountTendered: tendered,
        tipAmount: tip,
        tipPaymentMethod: tipMethod,
        paymentSplits: splits?.map((s) => s.toApiJson()).toList(),
        items: cart.items,
        orderedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ));
      ref.read(cartProvider.notifier).clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Order saved offline — will sync when connected')));
      }
      return;
    }

    try {
      final order = await ref.read(orderApiProvider).create(
            branchId: shift.branchId,
            shiftId: shift.id,
            paymentMethod: paymentMethod,
            items: cart.items,
            customerName: customer,
            discountType: discountType,
            discountValue: discountValue,
            discountId: discountId,
            amountTendered: tendered,
            tipAmount: tip,
            tipPaymentMethod: tipMethod,
            paymentSplits: splits,
            idempotencyKey: const Uuid().v4(),
          );
      ref.read(orderHistoryProvider.notifier).addOrder(order);
      final total = cart.total;
      ref.read(cartProvider.notifier).clear();
      if (mounted) {
        Navigator.pop(context);
        ReceiptSheet.show(context,
            order: order,
            total: total,
            changeGiven:
                tendered != null ? (tendered - total).clamp(0, 999999) : null);
      }
    } catch (e) {
      if (isNetworkError(e)) {
        await queue.enqueueOrder(PendingOrder(
          localId: const Uuid().v4(),
          branchId: shift.branchId,
          shiftId: shift.id,
          paymentMethod: paymentMethod,
          customerName: customer,
          discountType: discountType,
          discountValue: discountValue,
          discountId: discountId,
          amountTendered: tendered,
          tipAmount: tip,
          tipPaymentMethod: tipMethod,
          paymentSplits: splits?.map((s) => s.toApiJson()).toList(),
          items: cart.items,
          createdAt: DateTime.now(),
          orderedAt: DateTime.now(),
        ));
        ref.read(cartProvider.notifier).clear();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Connection lost — order saved offline')));
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
    final cart = ref.watch(cartProvider);
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height - mq.padding.top - 16;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: AppRadius.sheetRadius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)))),
          ),

          // Sticky header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(children: [
              Text('Checkout',
                  style: cairo(fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0.2, 0), end: Offset.zero)
                        .animate(anim),
                    child: FadeTransition(opacity: anim, child: child)),
                child: Container(
                  key: ValueKey(cart.total),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(egp(cart.total),
                      style: cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ),
              ),
            ]),
          ),
          Container(height: 1, color: AppColors.border),

          // Scrollable body
          Flexible(
            child: SingleChildScrollView(
              padding:
                  EdgeInsets.fromLTRB(24, 20, 24, mq.viewInsets.bottom + 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryCard(cart: cart),
                  const SizedBox(height: 20),

                  const _FieldLabel('CUSTOMER NAME (OPTIONAL)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customerCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: cairo(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'e.g. Ahmed',
                      hintStyle:
                          cairo(fontSize: 15, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          size: 18, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_discountsLoaded && _discounts.isNotEmpty) ...[
                    const _FieldLabel('DISCOUNT (OPTIONAL)'),
                    const SizedBox(height: 8),
                    _DiscountPicker(
                      discounts: _discounts,
                      selected: _selectedDiscount,
                      onSelect: (d) {
                        setState(() => _selectedDiscount = d);
                        if (d == null) {
                          ref
                              .read(cartProvider.notifier)
                              .setDiscount(null, null);
                        } else {
                          ref.read(cartProvider.notifier).setDiscount(
                              DiscountType.values.byName(d.dtype), d.value);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  Row(children: [
                    const _FieldLabel('PAYMENT'),
                    const Spacer(),
                    _SplitToggle(
                      active: _isSplit,
                      onToggle: () => setState(() {
                        _isSplit = !_isSplit;
                        if (!_isSplit) {
                          for (final c in _splitCtrs.values) c.clear();
                          _activeSplitMethods.clear();
                          final pay = ref.read(cartProvider).payment;
                          _showTendered =
                              pay == 'cash' || pay == 'talabat_cash';
                        } else {
                          _showTendered = false;
                        }
                      }),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  if (_isSplit)
                    _SplitPaymentSection(
                      activeMethods: _activeSplitMethods,
                      splitCtrs: _splitCtrs,
                      cartTotal: cart.total,
                      onToggleMethod: _toggleSplitMethod,
                      onAmountChanged: () => setState(() {}),
                      parsedTip: _parsedTip,
                      tipPaymentMethod: _tipPaymentMethod,
                    )
                  else ...[
                    _SinglePaymentGrid(
                      selected: cart.payment,
                      onSelect: (v) {
                        ref.read(cartProvider.notifier).setPayment(v);
                        setState(() =>
                            _showTendered = v == 'cash' || v == 'talabat_cash');
                      },
                    ),

                    // Cash tendered — single mode only
                    if (_showTendered) ...[
                      const SizedBox(height: 20),
                      _CashTenderedSection(
                        tenderedCtrl: _tenderedCtrl,
                        cartTotal: cart.total,
                        onChanged: () => setState(() {}),
                        // Pass cash tip so change display is reduced accordingly
                        cashTip: _tipIsCash ? _parsedTip : null,
                      ),
                    ],
                  ],

                  // Tip section — always shown in both single and split modes
                  const SizedBox(height: 20),
                  _TipSection(
                    tipCtrl: _tipCtrl,
                    tipPaymentMethod: _tipPaymentMethod,
                    parsedTip: _parsedTip,
                    onMethodChanged: (m) =>
                        setState(() => _tipPaymentMethod = m),
                    onAmountChanged: () => setState(() {}),
                  ),

                  // Error banner
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.07),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xs)),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 14, color: AppColors.danger),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_error!,
                                        style: cairo(
                                            fontSize: 13,
                                            color: AppColors.danger))),
                              ]),
                            ))
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Place Order — pinned
          Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, mq.padding.bottom + 16),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border))),
            child: AppButton(
              label: 'Place Order',
              loading: _loading,
              width: double.infinity,
              height: 52,
              icon: Icons.check_rounded,
              onTap: _place,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHECKOUT SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: cairo(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.2));
}

class _SummaryCard extends StatelessWidget {
  final CartState cart;
  const _SummaryCard({required this.cart});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          LabelValue('Subtotal', egp(cart.subtotal)),
          if (cart.discountAmount > 0)
            LabelValue('Discount', '− ${egp(cart.discountAmount)}',
                valueColor: AppColors.success),
          const Divider(height: 16, color: AppColors.border),
          LabelValue('Total', egp(cart.total), bold: true),
        ]),
      );
}

class _SplitToggle extends StatelessWidget {
  final bool active;
  final VoidCallback onToggle;
  const _SplitToggle({required this.active, required this.onToggle});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withOpacity(0.1) : AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
                color: active ? AppColors.primary : AppColors.border),
          ),
          child: Text('Split',
              style: cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.primary : AppColors.textSecondary)),
        ),
      );
}

class _DiscountPicker extends StatelessWidget {
  final List<Discount> discounts;
  final Discount? selected;
  final void Function(Discount?) onSelect;
  const _DiscountPicker(
      {required this.discounts,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip('None', null, selected == null, AppColors.primary),
          ...discounts.map((d) =>
              _chip(d.label, d, selected?.id == d.id, AppColors.success)),
        ],
      );

  Widget _chip(String label, Discount? d, bool sel, Color color) =>
      GestureDetector(
        onTap: () => onSelect(sel ? null : d),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? color : AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
                color: sel ? color : AppColors.border, width: sel ? 1.5 : 1),
          ),
          child: Text(label,
              style: cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : AppColors.textPrimary)),
        ),
      );
}

class _SinglePaymentGrid extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  const _SinglePaymentGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (ctx, constraints) {
        final btnW = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kPaymentMethods.map((m) {
            final sel = selected == m.value;
            return GestureDetector(
              onTap: () => onSelect(m.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: btnW,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                    color: sel ? m.color : AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                        color: sel ? m.color : AppColors.border,
                        width: sel ? 1.5 : 1)),
                child: Row(children: [
                  Icon(m.icon, size: 20, color: sel ? Colors.white : m.color),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(m.label,
                          style: cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  sel ? Colors.white : AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                  if (sel) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle_rounded,
                        size: 15, color: Colors.white)
                  ],
                ]),
              ),
            );
          }).toList(),
        );
      });
}

class _CashTenderedSection extends StatelessWidget {
  final TextEditingController tenderedCtrl;
  final int cartTotal;
  final VoidCallback onChanged;
  final int? cashTip; // When set, reduces the displayed change due
  const _CashTenderedSection({
    required this.tenderedCtrl,
    required this.cartTotal,
    required this.onChanged,
    this.cashTip,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('CASH TENDERED'),
          const SizedBox(height: 8),
          TextField(
            controller: tenderedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            style: cairo(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: 'EGP  ',
              prefixStyle: cairo(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
              hintText: '0',
              hintStyle: cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.border),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
            ),
          ),
          Builder(builder: (_) {
            final tendered = double.tryParse(tenderedCtrl.text);
            if (tendered == null || tendered == 0)
              return const SizedBox.shrink();
            final tenderedP = (tendered * 100).round();
            // Cash tip comes out of the change float, so subtract it
            final change = tenderedP - cartTotal - (cashTip ?? 0);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: change >= 0
                    ? AppColors.success.withOpacity(0.07)
                    : AppColors.danger.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                    color: change >= 0
                        ? AppColors.success.withOpacity(0.25)
                        : AppColors.danger.withOpacity(0.25)),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(change >= 0 ? 'Change due:' : 'Insufficient:',
                        style: cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: change >= 0
                                ? AppColors.success
                                : AppColors.danger)),
                    Text(egp(change.abs()),
                        style: cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: change >= 0
                                ? AppColors.success
                                : AppColors.danger)),
                  ]),
            );
          }),
        ],
      );
}

class _TipSection extends StatelessWidget {
  final TextEditingController tipCtrl;
  final String tipPaymentMethod;
  final int? parsedTip;
  final void Function(String) onMethodChanged;
  final VoidCallback onAmountChanged;

  static const _methods = ['cash', 'card', 'talabat_online', 'talabat_cash'];

  const _TipSection({
    required this.tipCtrl,
    required this.tipPaymentMethod,
    required this.parsedTip,
    required this.onMethodChanged,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: parsedTip != null
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.volunteer_activism_rounded,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            const _FieldLabel('TIP (OPTIONAL)'),
            const Spacer(),
            if (parsedTip != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Container(
                  key: ValueKey(parsedTip),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(egp(parsedTip!),
                      style: cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _methods.map((method) {
              final sel = tipPaymentMethod == method;
              final color = _methodColor(method);
              return GestureDetector(
                onTap: () => onMethodChanged(method),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? color : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                        color: sel ? color : AppColors.border,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (sel) ...[
                      const Icon(Icons.check_rounded,
                          size: 11, color: Colors.white),
                      const SizedBox(width: 4)
                    ],
                    Text(_methodLabel(method),
                        style: cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                sel ? Colors.white : AppColors.textSecondary)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tipCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onAmountChanged(),
            style: cairo(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: 'EGP  ',
              prefixStyle: cairo(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
              hintText: '0',
              hintStyle: cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.border),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
            ),
          ),
        ]),
      );
}

// Never calls putIfAbsent during build.
// All controllers are guaranteed present for every key in activeMethods.
// Balance indicator: cartTotal - entered - cashTipOffset.
class _SplitPaymentSection extends StatelessWidget {
  final Set<String> activeMethods;
  final Map<String, TextEditingController> splitCtrs;
  final int cartTotal;
  final void Function(String) onToggleMethod;
  final VoidCallback onAmountChanged;
  final int? parsedTip;
  final String tipPaymentMethod;

  static const _methods = ['cash', 'card', 'talabat_online', 'talabat_cash'];

  const _SplitPaymentSection({
    required this.activeMethods,
    required this.splitCtrs,
    required this.cartTotal,
    required this.onToggleMethod,
    required this.onAmountChanged,
    required this.parsedTip,
    required this.tipPaymentMethod,
  });

  List<PaymentSplit> _buildSplits() {
    final splits = <PaymentSplit>[];
    for (final method in activeMethods) {
      final raw = double.tryParse(splitCtrs[method]?.text ?? '');
      if (raw != null && raw > 0)
        splits.add(PaymentSplit(method: method, amount: (raw * 100).round()));
    }
    return splits;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('SELECT METHODS USED'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _methods.map((method) {
              final color = _methodColor(method);
              final active = activeMethods.contains(method);
              return GestureDetector(
                onTap: () => onToggleMethod(method),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? color : AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                        color: active ? color : AppColors.border,
                        width: active ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        active
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: active ? Colors.white : color),
                    const SizedBox(width: 6),
                    Text(_methodLabel(method),
                        style: cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                active ? Colors.white : AppColors.textPrimary)),
                  ]),
                ),
              );
            }).toList(),
          ),
          if (activeMethods.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _FieldLabel('ENTER AMOUNTS'),
            const SizedBox(height: 10),
            ...activeMethods.map((method) {
              final color = _methodColor(method);
              final ctrl = splitCtrs[method];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(_methodLabel(method),
                            style: cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ]),
                      const SizedBox(height: 6),
                      TextField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => onAmountChanged(),
                        style: cairo(fontSize: 20, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: 'EGP  ',
                          prefixStyle: cairo(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide:
                                  BorderSide(color: color.withOpacity(0.3))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide:
                                  BorderSide(color: color.withOpacity(0.3))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(color: color, width: 2)),
                          filled: true,
                          fillColor: color.withOpacity(0.03),
                        ),
                      ),
                    ]),
              );
            }),

            // Balance indicator — accounts for cash tip reducing required split total
            Builder(builder: (context) {
              final splits = _buildSplits();
              final entered = splits.fold(0, (s, p) => s + p.amount);
              // Cash tip comes out of the change float of the cash split leg,
              // so it reduces the amount the split amounts need to cover.
              final isCashTip = _isCashMethod(tipPaymentMethod);
              final tipOffset =
                  (isCashTip && parsedTip != null) ? parsedTip! : 0;
              final diff = cartTotal - entered - tipOffset;
              final ok = diff == 0;
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: ok
                      ? AppColors.success.withOpacity(0.07)
                      : AppColors.warning.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: ok
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(
                            ok
                                ? Icons.check_circle_outline_rounded
                                : Icons.pending_outlined,
                            size: 16,
                            color: ok ? AppColors.success : AppColors.warning),
                        const SizedBox(width: 8),
                        Text(ok ? 'Balanced ✓' : 'Remaining',
                            style: cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ok
                                    ? AppColors.success
                                    : AppColors.warning)),
                      ]),
                      if (!ok)
                        Text(egp(diff.abs()),
                            style: cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.warning)),
                    ]),
              );
            }),
          ],
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECEIPT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class ReceiptSheet extends ConsumerStatefulWidget {
  final Order order;
  final int total;
  final int? changeGiven;
  const ReceiptSheet(
      {super.key, required this.order, required this.total, this.changeGiven});

  static void show(BuildContext ctx,
          {required Order order, required int total, int? changeGiven}) =>
      showModalBottomSheet(
          context: ctx,
          backgroundColor: Colors.transparent,
          builder: (_) => ReceiptSheet(
              order: order, total: total, changeGiven: changeGiven));

  @override
  ConsumerState<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends ConsumerState<ReceiptSheet> {
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
    final branch = ref.read(authProvider).branch;
    if (branch == null || !branch.hasPrinter) return;
    setState(() {
      _printing = true;
      _printError = null;
    });
    final err = await PrinterService.print(
        ip: branch.printerIp!,
        port: branch.printerPort,
        brand: branch.printerBrand!,
        order: widget.order,
        branchName: branch.name);
    if (mounted)
      setState(() {
        _printing = false;
        _printError = err;
      });
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: AppRadius.sheetRadius),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).padding.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        SizedBox(
            width: 110,
            height: 110,
            child: Lottie.asset('assets/lottie/success.json',
                repeat: false, fit: BoxFit.contain)),
        const SizedBox(height: 10),
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
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border)),
          child: Column(children: [
            LabelValue('Payment', _paymentLabel(o.paymentMethod)),
            if (o.tipAmount != null && o.tipAmount! > 0)
              LabelValue('Tip',
                  '${egp(o.tipAmount!)}${o.tipPaymentMethod != null ? " · ${_paymentLabel(o.tipPaymentMethod!)}" : ""}',
                  valueColor: AppColors.success),
            if (o.customerName != null && o.customerName!.isNotEmpty)
              LabelValue('Customer', o.customerName!),
            LabelValue('Total', egp(o.totalAmount), bold: true),
            LabelValue('Time', timeShort(o.createdAt)),
            if (widget.changeGiven != null && widget.changeGiven! > 0)
              LabelValue('Change Given', egp(widget.changeGiven!),
                  valueColor: AppColors.success),
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
                      color: (_printError != null
                              ? AppColors.danger
                              : AppColors.primary)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppRadius.xs)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.print_rounded,
                        size: 15,
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

  String _paymentLabel(String method) => switch (method) {
        'cash' => 'Cash',
        'card' => 'Card',
        'digital_wallet' => 'Digital Wallet',
        'mixed' => 'Mixed',
        'talabat_online' => 'Talabat Online',
        'talabat_cash' => 'Talabat Cash',
        _ => method[0].toUpperCase() + method.substring(1).replaceAll('_', ' '),
      };
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
          fontSize: 10,
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
          borderRadius: BorderRadius.circular(AppRadius.xs)),
      child: Text(text,
          style: cairo(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3)));
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({super.key, required this.count});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text('$count',
          style: cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary)));
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
            color: selected ? AppColors.primary : AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (checkbox) ...[
            Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 14,
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
                  borderRadius: BorderRadius.circular(4)),
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
          width: 40,
          height: 40,
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
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.border)),
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
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.border)),
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
          const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.border),
          const SizedBox(height: 12),
          Text(message,
              style: cairo(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
//  OPTIONAL FIELDS CARD
// ─────────────────────────────────────────────────────────────
class _OptionalFieldsCard extends StatelessWidget {
  final List<OptionalField> fields;
  final Set<String> selected;
  final String? sizeLabel;
  final void Function(String) onToggle;

  const _OptionalFieldsCard({
    required this.fields,
    required this.selected,
    required this.sizeLabel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Show only fields that match current size (or have no size restriction)
    final visible = fields
        .where((f) => f.sizeLabel == null || f.sizeLabel == sizeLabel)
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: selected.any((id) => visible.any((f) => f.id == id))
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Text('OPTIONALS',
                style: cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.7)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs)),
              child: Text('Optional',
                  style: cairo(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: visible.map((f) {
              final sel = selected.contains(f.id);
              return GestureDetector(
                onTap: () => onToggle(f.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.bg,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        sel
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 14,
                        color: sel ? Colors.white : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(f.name,
                        style: cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.textPrimary)),
                    if (!f.isFree) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: sel
                                ? Colors.white.withOpacity(0.2)
                                : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('+${egp(f.price)}',
                            style: cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : AppColors.primary)),
                      ),
                    ],
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}
