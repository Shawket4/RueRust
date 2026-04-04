import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu.dart';
import 'client.dart';

class MenuApi {
  final DioClient _c;
  MenuApi(this._c);

  Future<List<Category>> categories(String orgId) async {
    final res =
        await _c.dio.get('/categories', queryParameters: {'org_id': orgId});
    return (res.data as List).map((c) => Category.fromJson(c)).toList();
  }

  Future<List<MenuItem>> items(String orgId) async {
    final res = await _c.dio.get('/menu-items', queryParameters: {
      'org_id': orgId,
      'full': 'true',
    });
    return (res.data as List)
        .map((m) => MenuItem.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<MenuItem> item(String id) async {
    final res = await _c.dio.get('/menu-items/$id');
    return MenuItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<AddonItem>> addons(String orgId) async {
    final res =
        await _c.dio.get('/addon-items', queryParameters: {'org_id': orgId});
    return (res.data as List).map((a) => AddonItem.fromJson(a)).toList();
  }
}

final menuApiProvider =
    Provider<MenuApi>((ref) => MenuApi(ref.watch(dioClientProvider)));
