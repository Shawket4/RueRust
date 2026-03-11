import 'client.dart';
import '../models/menu.dart';

class MenuApi {
  Future<List<Category>> getCategories(String orgId) async {
    final res = await dio.get('/categories', queryParameters: {'org_id': orgId});
    return (res.data as List).map((c) => Category.fromJson(c)).toList();
  }

  Future<List<MenuItem>> getMenuItems(String orgId, {String? categoryId}) async {
    final params = <String, dynamic>{'org_id': orgId};
    if (categoryId != null) params['category_id'] = categoryId;
    final res = await dio.get('/menu-items', queryParameters: params);
    return (res.data as List).map((m) => MenuItem.fromJson(m)).toList();
  }

  Future<MenuItem> getMenuItem(String id) async {
    final res = await dio.get('/menu-items/$id');
    return MenuItem.fromJson(res.data);
  }

  Future<List<AddonItem>> getAddonItems(String orgId) async {
    final res =
        await dio.get('/addon-items', queryParameters: {'org_id': orgId});
    return (res.data as List).map((a) => AddonItem.fromJson(a)).toList();
  }
}

final menuApi = MenuApi();
