import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order.dart';
import '../repositories/order_repository.dart';

class OrderHistoryState {
  final List<Order> orders;
  final bool isLoading;
  final bool fromCache;
  final String? error;
  final String? shiftId;

  const OrderHistoryState({
    this.orders = const [],
    this.isLoading = false,
    this.fromCache = false,
    this.error,
    this.shiftId,
  });

  OrderHistoryState copyWith({
    List<Order>? orders,
    bool? isLoading,
    bool? fromCache,
    String? error,
    String? shiftId,
    bool clearError = false,
  }) =>
      OrderHistoryState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        fromCache: fromCache ?? this.fromCache,
        error: clearError ? null : (error ?? this.error),
        shiftId: shiftId ?? this.shiftId,
      );
}

class OrderHistoryNotifier extends Notifier<OrderHistoryState> {
  @override
  OrderHistoryState build() => const OrderHistoryState();

  Future<void> loadForShift(String shiftId, {bool force = false}) async {
    if (!force && state.shiftId == shiftId && state.orders.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders =
          await ref.read(orderRepositoryProvider).listForShift(shiftId);
      state = state.copyWith(
          isLoading: false, orders: orders, shiftId: shiftId, fromCache: false);
    } catch (_) {
      state = state.copyWith(
          isLoading: false,
          fromCache: true,
          error: 'Could not load orders — check connection');
    }
  }

  Future<void> refresh(String shiftId) => loadForShift(shiftId, force: true);

  /// Called after a successful order placement (online or synced offline).
  void addOrder(Order order) {
    if (state.orders.any((o) => o.id == order.id)) return;
    final updated = [order, ...state.orders];
    state = state.copyWith(orders: updated);
    if (state.shiftId != null) {
      ref
          .read(orderRepositoryProvider)
          .appendOrderToCache(state.shiftId!, order, state.orders);
    }
  }

  void updateOrder(Order updated) {
    state = state.copyWith(
      orders:
          state.orders.map((o) => o.id == updated.id ? updated : o).toList(),
    );
  }

  void clear() => state = const OrderHistoryState();
}

final orderHistoryProvider =
    NotifierProvider<OrderHistoryNotifier, OrderHistoryState>(
        OrderHistoryNotifier.new);
