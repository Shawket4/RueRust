import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';

class CartNotifier extends Notifier<CartState> {
  CartItem? _lastRemovedItem;
  int? _lastRemovedIndex;

  @override
  CartState build() => CartState.empty;

  void add(CartItem incoming) {
    final idx = state.items.indexWhere((i) =>
        i.menuItemId == incoming.menuItemId &&
        i.sizeLabel  == incoming.sizeLabel &&
        CartItem.addonsMatch(i.addons, incoming.addons) &&
        CartItem.optionalsMatch(i.optionals, incoming.optionals));

    if (idx >= 0) {
      final updated = List<CartItem>.of(state.items);
      updated[idx] = updated[idx]
          .copyWith(quantity: updated[idx].quantity + incoming.quantity);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, incoming]);
    }
  }

  void removeAt(int index) {
    _lastRemovedItem = state.items[index];
    _lastRemovedIndex = index;
    final updated = List<CartItem>.of(state.items)..removeAt(index);
    state = state.copyWith(items: updated);
  }

  // Task 3.6: Restore method
  void restoreLastRemoved() {
    if (_lastRemovedItem == null || _lastRemovedIndex == null) return;
    
    final safeIndex = _lastRemovedIndex!.clamp(0, state.items.length);
    final updated = List<CartItem>.of(state.items)..insert(safeIndex, _lastRemovedItem!);
    state = state.copyWith(items: updated);
    
    _lastRemovedItem = null;
    _lastRemovedIndex = null;
  }

  void setQty(int index, int qty) {
    if (qty <= 0) { removeAt(index); return; }
    final updated = List<CartItem>.of(state.items);
    updated[index] = updated[index].copyWith(quantity: qty);
    state = state.copyWith(items: updated);
  }

  void replaceAt(int index, CartItem incoming) {
    final updated = List<CartItem>.of(state.items);
    updated[index] = incoming;
    state = state.copyWith(items: updated);
  }

  void setPayment(String m) =>
      state = state.copyWith(payment: m, clearSplits: true);

  void setCustomer(String? n) =>
      state = state.copyWith(customerName: n, clearCustomer: n == null);

  void setNotes(String? n) => state = state.copyWith(notes: n);

  void setDiscount(DiscountType? type, int? value) => state = type == null
      ? state.copyWith(clearDiscount: true, clearDiscountId: true)
      : state.copyWith(
          discountType: type, discountValue: value, clearDiscountId: true);

  void setDiscountById(String id, DiscountType type, int value) => state =
      state.copyWith(discountId: id, discountType: type, discountValue: value);

  void clearDiscount() =>
      state = state.copyWith(clearDiscount: true, clearDiscountId: true);

  void setAmountTendered(int? amount) => state =
      state.copyWith(amountTendered: amount, clearTendered: amount == null);

  void setTip(int? tip) => state = state.copyWith(tipAmount: tip);

  void setPaymentSplits(List<PaymentSplit> splits) {
    final method = splits.length == 1 ? splits.first.method : 'mixed';
    state = state.copyWith(paymentSplits: splits, payment: method);
  }

  void clearSplits() =>
      state = state.copyWith(clearSplits: true, payment: 'cash');

  void clear() {
    _lastRemovedItem = null;
    _lastRemovedIndex = null;
    state = CartState.empty;
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
