import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_notifier.dart';
import '../../core/providers/menu_notifier.dart';
import '../../core/providers/discount_notifier.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/top_bar.dart';
import 'widgets/category_rail.dart';
import 'widgets/menu_grid.dart';
import 'widgets/cart_panel.dart';

class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});
  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgId = ref.read(authProvider).user?.orgId;
      if (orgId != null) {
        ref.read(menuProvider.notifier).load(orgId);
        ref.read(discountProvider.notifier).load(orgId);
      }
    });

    // Task 3.3: Debounce menu search
    _searchCtrl.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() => _query = _searchCtrl.text.trim().toLowerCase());
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Task 3.7
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: isTablet ? null : const MobileCartFab(),
      body: SafeArea(
        child: Column(children: [
          TopBar(ctrl: _searchCtrl, query: _query),
          Expanded(
            child: isTablet
                ? Row(children: [
                    if (_query.isEmpty) const CategoryRail(),
                    Expanded(child: _contentArea()),
                    const CartPanel(),
                  ])
                : Row(children: [
                    if (_query.isEmpty) const CategoryRail(),
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
            ? SearchResults(key: ValueKey(_query), query: _query)
            : const MenuGrid(key: ValueKey('grid')),
      );
}
