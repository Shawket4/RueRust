import 'client.dart';
import '../models/inventory.dart';

class InventoryApi {
  Future<List<InventoryItem>> getItems(String branchId) async {
    final res =
        await dio.get('/inventory/branches/$branchId/items');
    return (res.data as List).map((i) => InventoryItem.fromJson(i)).toList();
  }
}

final inventoryApi = InventoryApi();
