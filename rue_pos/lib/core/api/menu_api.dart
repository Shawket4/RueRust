import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';
import '../models/menu.dart';

class MenuApi {
  Future<List<Category>> categories(String orgId) async {
    final res = await dio.get('/categories', queryParameters: {'org_id': orgId});
    return (res.data as List).map((c) => Category.fromJson(c)).toList();
  }

  Future<List<MenuItem>> items(String orgId) async {
    final res = await dio.get('/menu-items', queryParameters: {'org_id': orgId});
    return (res.data as List).map((m) => MenuItem.fromJson(m)).toList();
  }

  /// Fetch single item with full sizes + option groups.
  /// Caches result; serves cache on network failure.
  Future<MenuItem> item(String id) async {
    try {
      final res  = await dio.get('/menu-items/$id');
      final item = MenuItem.fromJson(res.data as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('menu_item_$id', jsonEncode(item.toJson()));
      return item;
    } catch (_) {
      final prefs  = await SharedPreferences.getInstance();
      final cached = prefs.getString('menu_item_$id');
      if (cached != null) {
        return MenuItem.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }
}

final menuApi = MenuApi();

