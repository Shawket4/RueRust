import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../api/order_api.dart';

class OrderHistoryProvider extends ChangeNotifier {
  List<Order> _orders = [];
  bool _loading = false;
  String? _error;
  String? _shiftId;

  List<Order> get orders => _orders;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadForShift(String shiftId) async {
    if (_shiftId == shiftId && _orders.isNotEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await orderApi.list(shiftId: shiftId);
      _shiftId = shiftId;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  void refresh(String shiftId) {
    _shiftId = null;
    loadForShift(shiftId);
  }

  void addOrder(Order o) {
    _orders.insert(0, o);
    notifyListeners();
  }
}
