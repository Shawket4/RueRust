import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/discount_api.dart';
import '../models/discount.dart';
import '../storage/storage_service.dart';

class DiscountState {
  final List<Discount> items;
  final bool isLoading;
  final String? loadedOrgId;

  const DiscountState({
    this.items = const [],
    this.isLoading = false,
    this.loadedOrgId,
  });

  DiscountState copyWith({
    List<Discount>? items,
    bool? isLoading,
    String? loadedOrgId,
  }) =>
      DiscountState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        loadedOrgId: loadedOrgId ?? this.loadedOrgId,
      );
}

class DiscountNotifier extends Notifier<DiscountState> {
  @override
  DiscountState build() => const DiscountState();

  Future<void> load(String orgId, {bool force = false}) async {
    if (!force && state.loadedOrgId == orgId && state.items.isNotEmpty) return;

    final storage = ref.read(storageServiceProvider);

    // Initial silent load from cache so it's instantly available offline
    if (state.items.isEmpty) {
      final cachedRaw = storage.loadDiscounts(orgId);
      if (cachedRaw.isNotEmpty) {
        state = state.copyWith(
          items: cachedRaw.map(Discount.fromJson).toList(),
          loadedOrgId: orgId,
        );
      }
    }

    state = state.copyWith(isLoading: true);
    
    try {
      final api = ref.read(discountApiProvider);
      final list = await api.list(orgId);
      
      // Update cache
      await storage.saveDiscounts(
          orgId, list.map((e) => e.toJson()).toList());

      state = state.copyWith(
        isLoading: false,
        items: list,
        loadedOrgId: orgId,
      );
    } catch (_) {
      // Fallback gracefully without throwing, keep existing items
      state = state.copyWith(isLoading: false);
    }
  }
}

final discountProvider =
    NotifierProvider<DiscountNotifier, DiscountState>(DiscountNotifier.new);
