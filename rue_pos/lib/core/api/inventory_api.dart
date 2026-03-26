import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory.dart';
import 'client.dart';

class InventoryApi {
  final DioClient _c;
  InventoryApi(this._c);

  Future<List<InventoryItem>> items(String branchId) async {
    final res = await _c.dio.get('/inventory/branches/$branchId/items');
    return (res.data as List).map((i) => InventoryItem.fromJson(i)).toList();
  }
}

final inventoryApiProvider = Provider<InventoryApi>(
    (ref) => InventoryApi(ref.watch(dioClientProvider)));
