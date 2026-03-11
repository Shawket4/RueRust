import 'package:flutter/foundation.dart';
import '../models/order.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String _paymentMethod = 'cash';
  String? _customerName;
  String? _discountType;
  int? _discountValue;

  List<CartItem> get items => List.unmodifiable(_items);
  String get paymentMethod => _paymentMethod;
  String? get customerName => _customerName;
  String? get discountType => _discountType;
  int? get discountValue => _discountValue;
  bool get isEmpty => _items.isEmpty;

  int get subtotal => _items.fold(0, (s, i) => s + i.lineTotal);

  int get discountAmount {
    if (_discountType == null || _discountValue == null) return 0;
    if (_discountType == 'percentage') {
      return (subtotal * _discountValue! / 100).round();
    }
    return _discountValue!;
  }

  int get total => subtotal - discountAmount;

  void addItem(CartItem item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void updateQuantity(int index, int qty) {
    if (qty <= 0) {
      removeItem(index);
    } else {
      _items[index].quantity = qty;
      notifyListeners();
    }
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setCustomerName(String? name) {
    _customerName = name;
    notifyListeners();
  }

  void setDiscount(String? type, int? value) {
    _discountType = type;
    _discountValue = value;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _paymentMethod = 'cash';
    _customerName = null;
    _discountType = null;
    _discountValue = null;
    notifyListeners();
  }
}
