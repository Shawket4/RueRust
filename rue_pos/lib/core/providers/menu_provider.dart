import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import '../models/menu.dart';
import '../api/menu_api.dart';
import '../api/client.dart' show prefs;

class MenuProvider extends ChangeNotifier {
  List<Category>  _cats        = [];
  List<MenuItem>  _items       = [];
  String?         _selId;
  bool            _loading     = false;
  String?         _error;
  String?         _loadedOrgId;
  bool            _fromCache   = false;

  List<Category>  get categories => _cats;
  List<MenuItem>  get allItems   => _items;
  String?         get selectedId => _selId;
  bool            get loading    => _loading;
  String?         get error      => _error;
  bool            get fromCache  => _fromCache;

  List<MenuItem> get filtered => _selId == null
      ? _items
      : _items.where((i) => i.categoryId == _selId).toList();

  /// Load menu for [orgId].
  /// Skips network if fresh live data already loaded for this org.
  Future<void> load(String orgId) async {
    // Already have fresh live data — skip
    if (_loadedOrgId == orgId && _items.isNotEmpty && !_fromCache) return;

    _loading   = true;
    _fromCache = false;
    _error     = null;
    notifyListeners();

    try {
      // Fetch categories + items in parallel
      final results = await Future.wait([
        menuApi.categories(orgId),
        menuApi.items(orgId),
      ]);
      _cats        = results[0] as List<Category>;
      _items       = results[1] as List<MenuItem>;
      _selId       = _cats.isNotEmpty ? _cats.first.id : null;
      _loadedOrgId = orgId;
      _fromCache   = false;
      await _saveCache(orgId);
    } catch (_) {
      final ok = await _loadCache(orgId);
      if (ok) {
        _fromCache   = true;
        _loadedOrgId = orgId;
      } else {
        _error = 'No connection and no cached menu available';
      }
    }

    _loading = false;
    notifyListeners();
  }

  /// Force a fresh fetch regardless of current state.
  Future<void> refresh(String orgId) async {
    _loadedOrgId = null;
    await load(orgId);
  }

  void select(String id) { _selId = id; notifyListeners(); }

  // ── Cache ──────────────────────────────────────────────────────────────────
  Future<void> _saveCache(String orgId) async {
    try {
      final p = await prefs;
      await p.setString('menu_cache_v2_$orgId', jsonEncode({
        'categories': _cats.map((c)  => c.toJson()).toList(),
        'items':      _items.map((i) => i.toJson()).toList(),
      }));
    } catch (_) {}
  }

  Future<bool> _loadCache(String orgId) async {
    try {
      final p   = await prefs;
      final raw = p.getString('menu_cache_v2_$orgId');
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _cats  = (data['categories'] as List)
          .map((c) => Category.fromJson(c as Map<String, dynamic>)).toList();
      _items = (data['items'] as List)
          .map((i) => MenuItem.fromJson(i as Map<String, dynamic>)).toList();
      _selId = _cats.isNotEmpty ? _cats.first.id : null;
      return true;
    } catch (_) { return false; }
  }
}
