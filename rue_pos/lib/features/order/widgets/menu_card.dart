import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/menu.dart';
import '../../../core/services/menu_image_cache.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../helpers/category_style.dart';
import 'item_detail_sheet.dart';
import 'shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MENU CARD
// ─────────────────────────────────────────────────────────────────────────────
class MenuCard extends ConsumerStatefulWidget {
  final MenuItem item;
  const MenuCard({super.key, required this.item});
  @override
  ConsumerState<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends ConsumerState<MenuCard>
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
    final style = CatStyle.of(item.name);
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
                child: hasImage
                    ? MenuImage(
                        url: item.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: ImageSkeleton(),
                        errorWidget: MissingItemCard(item: item, style: style),
                      )
                    : MissingItemCard(item: item, style: style),
              ),
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

// ─────────────────────────────────────────────────────────────────────────────
//  MISSING-IMAGE PLACEHOLDER
//
//  Designed to sit next to real product photography without clashing:
//  neutral cream background matching the real photos' backdrops, a
//  large thin monogram as the hero, plus a small category pill in the
//  top-left so category is still readable at a glance.
// ─────────────────────────────────────────────────────────────────────────────
class MissingItemCard extends StatelessWidget {
  final MenuItem item;
  final CatStyle style;
  const MissingItemCard({
    super.key,
    required this.item,
    required this.style,
  });

  String get _monogram {
    final cleaned = normaliseName(item.name).trim();
    if (cleaned.isEmpty) return '?';
    final words =
        cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    final w = words.first;
    return w.substring(0, w.length.clamp(1, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFBFAF7), Color(0xFFEEEBE6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative outline circle, hinting at the product shape without
          // committing to one. Uses the category accent very softly so
          // coffee cards have a warm ring, matcha cards a green ring, etc.
          Positioned(
            right: -36,
            bottom: -36,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: style.accent.withOpacity(0.14),
                  width: 3,
                ),
              ),
            ),
          ),

          // Monogram (item initials). Thin weight + generous size reads as
          // elegant typography rather than a UI placeholder badge.
          Center(
            child: Text(
              _monogram,
              style: cairo(
                fontSize: 52,
                fontWeight: FontWeight.w200,
                color: style.accent.withOpacity(0.55),
                letterSpacing: 1.5,
                height: 1,
              ),
            ),
          ),

          // Tiny category indicator, top-left. Subtle enough to disappear
          // behind the monogram visually but still gives an at-a-glance hint.
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.75),
              ),
              child: Icon(
                style.icon,
                size: 12,
                color: style.accent.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETONS
// ─────────────────────────────────────────────────────────────────────────────
class MenuCardSkeleton extends StatefulWidget {
  const MenuCardSkeleton({super.key});
  @override
  State<MenuCardSkeleton> createState() => _MenuCardSkeletonState();
}

class _MenuCardSkeletonState extends State<MenuCardSkeleton>
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
          final c =
              Color.lerp(skeletonBase, skeletonHighlight, _anim.value)!;
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

class ImageSkeleton extends StatefulWidget {
  @override
  State<ImageSkeleton> createState() => _ImageSkeletonState();
}

class _ImageSkeletonState extends State<ImageSkeleton>
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
          color: Color.lerp(skeletonBase, skeletonHighlight, _anim.value)));
}