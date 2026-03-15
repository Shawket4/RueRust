import 'package:flutter/foundation.dart' hide Category;
import '../models/menu.dart';
import '../api/menu_api.dart';

class MenuProvider extends ChangeNotifier {
  List<Category> _cats = [];
  List<MenuItem> _items = [];
  String? _selId;
  bool _loading = false;
  String? _error;
  String? _loadedOrgId;

  List<Category> get categories => _cats;
  List<MenuItem> get allItems => _items;
  String? get selectedId => _selId;
  bool get loading => _loading;
  String? get error => _error;

  List<MenuItem> get filtered => _selId == null
      ? _items
      : _items.where((i) => i.categoryId == _selId).toList();

  Future<void> load(String orgId) async {
    if (_loadedOrgId == orgId && _items.isNotEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      _cats = await menuApi.categories(orgId);
      _items = await menuApi.items(orgId);
      _selId = _cats.isNotEmpty ? _cats.first.id : null;
      _error = null;
      _loadedOrgId = orgId;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  void refresh(String orgId) {
    _loadedOrgId = null;
    load(orgId);
  }

  void select(String id) {
    _selId = id;
    notifyListeners();
  }
}
