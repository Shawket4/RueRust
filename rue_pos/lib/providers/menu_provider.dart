import 'package:flutter/foundation.dart' hide Category;
import '../models/menu.dart';
import '../api/menu_api.dart';

class MenuProvider extends ChangeNotifier {
  List<Category> _categories = [];
  List<MenuItem> _items = [];
  String? _selectedCategoryId;
  bool _loading = false;

  List<Category> get categories => _categories;
  List<MenuItem> get items => _items;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get loading => _loading;

  List<MenuItem> get filteredItems => _selectedCategoryId == null
      ? _items
      : _items.where((i) => i.categoryId == _selectedCategoryId).toList();

  Future<void> load(String orgId) async {
    _loading = true;
    notifyListeners();
    try {
      _categories = await menuApi.getCategories(orgId);
      _items = await menuApi.getMenuItems(orgId);
      if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first.id;
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  void selectCategory(String id) {
    _selectedCategoryId = id;
    notifyListeners();
  }
}
