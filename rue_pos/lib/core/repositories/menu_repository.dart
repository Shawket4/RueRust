import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/menu_api.dart';
import '../models/menu.dart';
import '../storage/storage_service.dart';

class MenuRepository {
  final MenuApi        _api;
  final StorageService _storage;
  MenuRepository(this._api, this._storage);

  Future<({List<Category> categories, List<MenuItem> items, List<AddonItem> addons, bool fromCache})>
      fetchMenu(String orgId) async {
    try {
      final results = await Future.wait([
        _api.categories(orgId),
        _api.items(orgId),
        _api.addons(orgId),
      ]);
      final cats    = results[0] as List<Category>;
      final items   = results[1] as List<MenuItem>;
      final addons  = results[2] as List<AddonItem>;
      await _storage.saveMenu(orgId, {
        'categories': cats.map((c)  => c.toJson()).toList(),
        'items':      items.map((i) => i.toJson()).toList(),
        'addons':     addons.map((a) => a.toJson()).toList(),
      });
      return (categories: cats, items: items, addons: addons, fromCache: false);
    } catch (_) {
      final cached = _storage.loadMenu(orgId);
      if (cached != null) {
        return (
          categories: (cached['categories'] as List)
              .map((c) => Category.fromJson(c as Map<String, dynamic>)).toList(),
          items: (cached['items'] as List)
              .map((i) => MenuItem.fromJson(i as Map<String, dynamic>)).toList(),
          addons: (cached['addons'] as List? ?? [])
              .map((a) => AddonItem.fromJson(a as Map<String, dynamic>)).toList(),
          fromCache: true,
        );
      }
      rethrow;
    }
  }

  Future<MenuItem> fetchItem(String id) => _api.item(id);
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) => MenuRepository(
  ref.watch(menuApiProvider),
  ref.watch(storageServiceProvider),
));
