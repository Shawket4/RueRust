import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../api/auth_api.dart';
import '../api/client.dart';
import 'branch_provider.dart';

class AuthProvider extends ChangeNotifier {
  final BranchProvider branchProvider;

  AuthProvider(this.branchProvider);

  User?  _user;
  bool   _loading = true;

  User?  get user            => _user;
  bool   get loading         => _loading;
  bool   get isAuthenticated => authToken != null && _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('token');
    if (authToken != null) {
      try {
        _user = await authApi.me();
        await _loadBranch();
      } catch (_) {
        await _clear();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login({required String name, required String pin}) async {
    final data = await authApi.loginWithPin(name: name, pin: pin);
    authToken = data['token'] as String;
    _user     = User.fromJson(data['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', authToken!);
    await _loadBranch();
    notifyListeners();
  }

  Future<void> logout() async {
    branchProvider.clear();
    await _clear();
    notifyListeners();
  }

  Future<void> _loadBranch() async {
    final branchId = _user?.branchId;
    if (branchId != null) {
      await branchProvider.load(branchId);
    }
  }

  Future<void> _clear() async {
    authToken = null;
    _user     = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}

