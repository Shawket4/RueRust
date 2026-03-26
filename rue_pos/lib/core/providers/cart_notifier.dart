import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart.dart';

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => CartState.empty;

  void add(CartItem incoming) {
    final idx = state.items.indexWhere((i) =>
        i.menuItemId == incoming.menuItemId &&
        i.sizeLabel  == incoming.sizeLabel  &&
        CartItem.addonsMatch(i.addons, incoming.addons));

    if (idx >= 0) {
      final updated = List<CartItem>.of(state.items);
      updated[idx] = updated[idx].copyWith(
          quantity: updated[idx].quantity + incoming.quantity);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, incoming]);
    }
  }

  void removeAt(int index) {
    final updated = List<CartItem>.of(state.items)..removeAt(index);
    state = state.copyWith(items: updated);
  }

  void setQty(int index, int qty) {
    if (qty <= 0) { removeAt(index); return; }
    final updated = List<CartItem>.of(state.items);
    updated[index] = updated[index].copyWith(quantity: qty);
    state = state.copyWith(items: updated);
  }

  void setPayment(String m)   => state = state.copyWith(payment: m);
  void setCustomer(String? n) => state = state.copyWith(customerName: n, clearCustomer: n == null);
  void setNotes(String? n)    => state = state.copyWith(notes: n);

  void setDiscount(DiscountType? type, int? value) => state = type == null
      ? state.copyWith(clearDiscount: true)
      : state.copyWith(discountType: type, discountValue: value);

  void clear() => state = CartState.empty;
}

final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
