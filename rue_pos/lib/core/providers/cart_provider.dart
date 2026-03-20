import 'package:flutter/foundation.dart';
import '../models/order.dart';

enum DiscountType { percentage, fixed }

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String        _payment       = 'cash';
  String?       _customer;
  String?       _notes;
  DiscountType? _discountType;
  int?          _discountValue;

  List<CartItem> get items    => List.unmodifiable(_items);
  String         get payment  => _payment;
  String?        get customer => _customer;
  String?        get notes    => _notes;
  bool           get isEmpty  => _items.isEmpty;
  int            get count    => _items.fold(0, (s, i) => s + i.quantity);

  int get subtotal => _items.fold(0, (s, i) => s + i.lineTotal);

  int get discountAmount {
    if (_discountType == null || (_discountValue ?? 0) == 0) return 0;
    return _discountType == DiscountType.percentage
        ? (subtotal * _discountValue! / 100).round()
        : _discountValue!;
  }

  int get total => subtotal - discountAmount;

  String? get discountTypeStr => switch (_discountType) {
    DiscountType.percentage => 'percentage',
    DiscountType.fixed      => 'fixed',
    null                    => null,
  };
  int? get discountValue => _discountValue;

  void add(CartItem item) {
    // Merge only if same item + size + identical addon set (by drinkOptionItemId)
    final existing = _items.firstWhere(
      (i) =>
          i.menuItemId == item.menuItemId &&
          i.sizeLabel  == item.sizeLabel  &&
          _addonsMatch(i.addons, item.addons),
      orElse: () => _sentinel,
    );
    if (!identical(existing, _sentinel)) {
      existing.quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  // Sentinel to avoid nullable firstWhere hack
  static final _sentinel = CartItem(
    menuItemId: '__sentinel__', itemName: '', unitPrice: 0,
  );

  /// Two addon lists match iff they contain the same drinkOptionItemIds
  /// (order-independent).
  static bool _addonsMatch(
      List<SelectedAddon> a, List<SelectedAddon> b) {
    if (a.length != b.length) return false;
    final aIds = a.map((x) => x.drinkOptionItemId).toSet();
    final bIds = b.map((x) => x.drinkOptionItemId).toSet();
    return aIds.containsAll(bIds) && bIds.containsAll(aIds);
  }

  void removeAt(int i)        { _items.removeAt(i); notifyListeners(); }
  void setQty(int i, int qty) {
    if (qty <= 0) { removeAt(i); } else { _items[i].quantity = qty; notifyListeners(); }
  }

  void setPayment(String m)   { _payment  = m; notifyListeners(); }
  void setCustomer(String? n) { _customer = n; notifyListeners(); }
  void setNotes(String? n)    { _notes    = n; notifyListeners(); }

  void setDiscount(DiscountType? t, int? v) {
    _discountType  = t;
    _discountValue = v;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _payment       = 'cash';
    _customer      = null;
    _notes         = null;
    _discountType  = null;
    _discountValue = null;
    notifyListeners();
  }
}
