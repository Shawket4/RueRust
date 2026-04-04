import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu.dart';
import '../repositories/menu_repository.dart';
import '../storage/storage_service.dart';

class MenuState {
  final List<Category> categories;
  final List<MenuItem> items;
  final List<AddonItem> allAddons;
  final String? selectedCategoryId;
  final bool isLoading;
  final bool fromCache;
  final String? error;
  final String? loadedOrgId;
  final DateTime? cachedAt;

  const MenuState({
    this.categories = const [],
    this.items = const [],
    this.allAddons = const [],
    this.selectedCategoryId,
    this.isLoading = false,
    this.fromCache = false,
    this.error,
    this.loadedOrgId,
    this.cachedAt,
  });

  List<MenuItem> get filtered => selectedCategoryId == null
      ? items
      : items.where((i) => i.categoryId == selectedCategoryId).toList();

  /// Active addon items grouped by type, sorted by display_order.
  /// Used by ItemDetailSheet to populate each slot's chip list.
  Map<String, List<AddonItem>> get addonsByType {
    final map = <String, List<AddonItem>>{};
    for (final a in allAddons) {
      if (!a.isActive) continue;
      map.putIfAbsent(a.type, () => []).add(a);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }
    return map;
  }

  MenuState copyWith({
    List<Category>? categories,
    List<MenuItem>? items,
    List<AddonItem>? allAddons,
    String? selectedCategoryId,
    bool? isLoading,
    bool? fromCache,
    String? error,
    String? loadedOrgId,
    DateTime? cachedAt,
    bool clearError = false,
  }) =>
      MenuState(
        categories: categories ?? this.categories,
        items: items ?? this.items,
        allAddons: allAddons ?? this.allAddons,
        selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
        isLoading: isLoading ?? this.isLoading,
        fromCache: fromCache ?? this.fromCache,
        error: clearError ? null : (error ?? this.error),
        loadedOrgId: loadedOrgId ?? this.loadedOrgId,
        cachedAt: cachedAt ?? this.cachedAt,
      );
}

class MenuNotifier extends Notifier<MenuState> {
  @override
  MenuState build() => const MenuState();

  Future<void> load(String orgId, {bool force = false}) async {
    if (!force &&
        state.loadedOrgId == orgId &&
        state.items.isNotEmpty &&
        !state.fromCache) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(menuRepositoryProvider);

      // Fetch menu (categories + items) and addon items concurrently.
      final menuResult = await repo.fetchMenu(orgId);
      final addonItems = await repo.fetchAddonItems(orgId);
      final cachedAt = ref.read(storageServiceProvider).menuCachedAt(orgId);

      state = state.copyWith(
        isLoading: false,
        categories: menuResult.categories,
        items: menuResult.items,
        allAddons: addonItems,
        fromCache: menuResult.fromCache,
        loadedOrgId: orgId,
        cachedAt: cachedAt,
        selectedCategoryId: menuResult.categories.isNotEmpty
            ? menuResult.categories.first.id
            : null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'No connection and no cached menu available',
      );
    }
  }

  void selectCategory(String id) =>
      state = state.copyWith(selectedCategoryId: id);
}

final menuProvider =
    NotifierProvider<MenuNotifier, MenuState>(MenuNotifier.new);
