import 'package:flutter/foundation.dart';
import '../models/branch.dart';
import '../api/branch_api.dart';

class BranchProvider extends ChangeNotifier {
  Branch? _branch;
  bool    _loading = false;
  String? _error;

  Branch? get branch   => _branch;
  bool    get loading  => _loading;
  String? get error    => _error;

  bool get hasPrinter => _branch?.hasPrinter ?? false;
  String? get printerIp   => _branch?.printerIp;
  int     get printerPort  => _branch?.printerPort ?? 9100;
  String  get branchName   => _branch?.name ?? '';

  Future<void> load(String branchId) async {
    if (_branch?.id == branchId) return;
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      _branch = await branchApi.get(branchId);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  void clear() {
    _branch  = null;
    _error   = null;
    _loading = false;
    notifyListeners();
  }
}

