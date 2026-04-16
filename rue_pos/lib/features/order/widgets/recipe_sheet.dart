import 'package:flutter/material.dart';
import '../../../core/api/recipe_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../shared/widgets/app_button.dart';
import 'shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  RECIPE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class RecipeSheet extends StatefulWidget {
  final String itemName;
  final String? sizeLabel;
  final Future<List<RecipeIngredient>> Function() fetchRecipe;

  const RecipeSheet({
    super.key,
    required this.itemName,
    required this.sizeLabel,
    required this.fetchRecipe,
  });

  @override
  State<RecipeSheet> createState() => _RecipeSheetState();
}

class _RecipeSheetState extends State<RecipeSheet> {
  late Future<List<RecipeIngredient>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetchRecipe();
  }

  void _retry() {
    setState(() {
      _future = widget.fetchRecipe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.sheetRadius,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.science_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.itemName,
                              style: cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (widget.sizeLabel != null) ...[
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.only(left: 36),
                          child: Text(
                            'Size: ${normaliseName(widget.sizeLabel!)}',
                            style: cairo(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.bg,
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Dynamic Body
          Flexible(
            child: FutureBuilder<List<RecipeIngredient>>(
              future: _future,
              builder: (context, snapshot) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildStateContent(snapshot),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent(AsyncSnapshot<List<RecipeIngredient>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return ListView.builder(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => const _RecipeRowSkeleton(),
      );
    }

    if (snapshot.hasError) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.broken_image_rounded,
                    size: 36, color: AppColors.danger),
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to construct recipe',
                style: cairo(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'There was a problem pulling the composition data from the server.',
                textAlign: TextAlign.center,
                style: cairo(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Try Again',
                icon: Icons.refresh_rounded,
                width: 140,
                height: 44,
                onTap: _retry,
              ),
            ],
          ),
        ),
      );
    }

    final result = snapshot.data;
    if (result == null || result.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded, size: 40, color: AppColors.border),
            const SizedBox(height: 12),
            Text('No ingredients mapped',
                style: cairo(fontSize: 14, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('data'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: result.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _RecipeIngredientCard(ingredient: result[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INGREDIENT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RecipeIngredientCard extends StatelessWidget {
  final RecipeIngredient ingredient;

  const _RecipeIngredientCard({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    final bool isBase = ingredient.isBase;
    final Color badgeColor =
        isBase ? AppColors.primary : AppColors.textSecondary;
    final Color bgColor =
        isBase ? AppColors.primary.withOpacity(0.04) : Colors.white;
    final Color borderColor =
        isBase ? AppColors.primary.withOpacity(0.15) : AppColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ingredient.quantity % 1 == 0
                      ? ingredient.quantity.toInt().toString()
                      : ingredient.quantity.toStringAsFixed(1),
                  style: cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                Text(
                  ingredient.unit,
                  style: cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              ingredient.name,
              style: cairo(
                fontSize: 14,
                fontWeight: isBase ? FontWeight.w700 : FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              ingredient.sourceLabel.toUpperCase(),
              style: cairo(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETON LOADER
// ─────────────────────────────────────────────────────────────────────────────
class _RecipeRowSkeleton extends StatefulWidget {
  const _RecipeRowSkeleton();

  @override
  State<_RecipeRowSkeleton> createState() => _RecipeRowSkeletonState();
}

class _RecipeRowSkeletonState extends State<_RecipeRowSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = Color.lerp(skeletonBase, skeletonHighlight, _anim.value)!;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, color: c),
                    const SizedBox(height: 8),
                    Container(width: 60, height: 10, color: c),
                  ],
                ),
              ),
              Container(
                width: 45,
                height: 20,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
