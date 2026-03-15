import 'client.dart';
import '../models/menu.dart';

class MenuApi {
  Future<List<Category>> categories(String orgId) async {
    final res =
        await dio.get('/categories', queryParameters: {'org_id': orgId});
    return (res.data as List).map((c) => Category.fromJson(c)).toList();
  }

  Future<List<MenuItem>> items(String orgId) async {
    final res =
        await dio.get('/menu-items', queryParameters: {'org_id': orgId});
    return (res.data as List).map((m) => MenuItem.fromJson(m)).toList();
  }

  Future<MenuItem> item(String id) async {
    final res = await dio.get('/menu-items/$id');
    return MenuItem.fromJson(res.data as Map<String, dynamic>);
  }
}

final menuApi = MenuApi();
