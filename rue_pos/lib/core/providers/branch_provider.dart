import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/branch.dart';
import '../api/branch_api.dart';
import '../api/client.dart' show prefs;

class BranchProvider extends ChangeNotifier {
  Branch? _branch;
  bool _loading = false;
  String? _error;

  Branch? get branch => _branch;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasPrinter => _branch?.hasPrinter ?? false;
  String? get printerIp => _branch?.printerIp;
  int get printerPort => _branch?.printerPort ?? 9100;
  String get branchName => _branch?.name ?? '';
  PrinterBrand? get printerBrand => _branch?.printerBrand;

  Future<void> load(String branchId) async {
    debugPrint('BranchProvider.load() called with: $branchId');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _branch = await branchApi.get(branchId);
      debugPrint('Branch loaded: ${_branch?.name}');
      debugPrint('printer_brand: ${_branch?.printerBrand}');
      debugPrint('hasPrinter: ${_branch?.hasPrinter}');
      await _save(_branch!);
    } catch (e) {
      debugPrint('Branch load FAILED: $e');
      final cached = await _load(branchId);
      if (cached != null) {
        _branch = cached;
      } else {
        _error = e.toString();
      }
    }
    _loading = false;
    notifyListeners();
  }

  void clear() {
    _branch = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────
  Future<void> _save(Branch b) async {
    try {
      final p = await prefs;
      await p.setString(
          'branch_${b.id}',
          jsonEncode({
            'id': b.id,
            'org_id': b.orgId,
            'name': b.name,
            'address': b.address,
            'phone': b.phone,
            'printer_brand': b.printerBrand?.name,
            'printer_ip': b.printerIp,
            'printer_port': b.printerPort,
            'is_active': b.isActive,
          }));
    } catch (_) {}
  }

  Future<Branch?> _load(String branchId) async {
    try {
      final p = await prefs;
      final raw = p.getString('branch_$branchId');
      if (raw == null) return null;
      return Branch.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
