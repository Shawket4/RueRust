import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'client.dart';
import '../models/inventory.dart';

class InventoryApi {
  /// Fetch inventory items for a branch. Caches; serves cache offline.
  Future<List<InventoryItem>> items(String branchId) async {
    try {
      final res   = await dio.get('/inventory/branches/$branchId/items');
      final items = (res.data as List).map((i) => InventoryItem.fromJson(i)).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('inventory_$branchId',
          jsonEncode(items.map((i) => {
            'id': i.id, 'name': i.name,
            'unit': i.unit, 'current_stock': i.currentStock,
          }).toList()));
      return items;
    } catch (_) {
      final prefs  = await SharedPreferences.getInstance();
      final raw    = prefs.getString('inventory_$branchId');
      if (raw != null) {
        return (jsonDecode(raw) as List)
            .map((i) => InventoryItem.fromJson(i as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }
}

final inventoryApi = InventoryApi();

