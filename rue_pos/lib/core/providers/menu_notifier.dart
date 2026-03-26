import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu.dart';
import '../repositories/menu_repository.dart';

class MenuState {
  final List<Category> categories;
  final List<MenuItem> items;
  final String? selectedCategoryId;
  final bool isLoading;
  final bool fromCache;
  final String? error;
  final String? loadedOrgId;

  const MenuState({
    this.categories = const [],
    this.items = const [],
    this.selectedCategoryId,
    this.isLoading = false,
    this.fromCache = false,
    this.error,
    this.loadedOrgId,
  });

  List<MenuItem> get filtered => selectedCategoryId == null
      ? items
      : items.where((i) => i.categoryId == selectedCategoryId).toList();

  MenuState copyWith({
    List<Category>? categories,
    List<MenuItem>? items,
    String? selectedCategoryId,
    bool? isLoading,
    bool? fromCache,
    String? error,
    String? loadedOrgId,
    bool clearError = false,
  }) =>
      MenuState(
        categories: categories ?? this.categories,
        items: items ?? this.items,
        selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
        isLoading: isLoading ?? this.isLoading,
        fromCache: fromCache ?? this.fromCache,
        error: clearError ? null : (error ?? this.error),
        loadedOrgId: loadedOrgId ?? this.loadedOrgId,
      );
}

class MenuNotifier extends Notifier<MenuState> {
  @override
  MenuState build() => const MenuState();

  Future<void> load(String orgId, {bool force = false}) async {
    if (!force &&
        state.loadedOrgId == orgId &&
        state.items.isNotEmpty &&
        !state.fromCache) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref.read(menuRepositoryProvider).fetchMenu(orgId);
      state = state.copyWith(
        isLoading: false,
        categories: result.categories,
        items: result.items,
        fromCache: result.fromCache,
        loadedOrgId: orgId,
        selectedCategoryId:
            result.categories.isNotEmpty ? result.categories.first.id : null,
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: 'No connection and no cached menu available');
    }
  }

  void selectCategory(String id) =>
      state = state.copyWith(selectedCategoryId: id);
}

final menuProvider =
    NotifierProvider<MenuNotifier, MenuState>(MenuNotifier.new);
