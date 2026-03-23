import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../api/auth_api.dart';
import '../api/client.dart';
import 'branch_provider.dart';

class AuthProvider extends ChangeNotifier {
  final BranchProvider branchProvider;
  AuthProvider(this.branchProvider) {
    // Wire 401 → auto-logout so any API call can trigger it.
    onUnauthorized = () {
      if (_user != null) {
        _clear().then((_) => notifyListeners());
      }
    };
  }

  User? _user;
  bool _loading = true;

  User? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => authToken != null && _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('token');
    if (authToken != null) {
      try {
        _user = await authApi.me();
        await _loadBranch();
      } on DioException catch (e) {
        // 401 → token invalid, must re-login
        if (e.response?.statusCode == 401) {
          await _clear();
        }
        // Any other network error → stay logged in with cached user
        else {
          _user = _loadCachedUser(prefs);
          if (_user != null) {
            await _loadBranch();
          } else {
            await _clear();
          }
        }
      } catch (_) {
        // Non-network error — try cached user
        _user = _loadCachedUser(prefs);
        if (_user != null) {
          await _loadBranch();
        } else {
          await _clear();
        }
      }
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> login({required String name, required String pin}) async {
    final data = await authApi.loginWithPin(name: name, pin: pin);
    authToken = data['token'] as String;
    _user = User.fromJson(data['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', authToken!);
    await _saveUser(prefs, _user!);
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
    if (branchId != null) await branchProvider.load(branchId);
  }

  Future<void> _clear() async {
    authToken = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('cached_user');
  }

  // ── Cached user (for offline startup) ─────────────────────────────────────
  Future<void> _saveUser(SharedPreferences p, User u) async {
    try {
      await p.setString('cached_user',
          '${u.id}|${u.orgId ?? ''}|${u.branchId ?? ''}|${u.name}|${u.email ?? ''}|${u.role}|${u.isActive}');
    } catch (_) {}
  }

  User? _loadCachedUser(SharedPreferences p) {
    try {
      final raw = p.getString('cached_user');
      if (raw == null) return null;
      final parts = raw.split('|');
      if (parts.length < 7) return null;
      return User(
        id: parts[0],
        orgId: parts[1].isEmpty ? null : parts[1],
        branchId: parts[2].isEmpty ? null : parts[2],
        name: parts[3],
        email: parts[4].isEmpty ? null : parts[4],
        role: parts[5],
        isActive: parts[6] == 'true',
      );
    } catch (_) {
      return null;
    }
  }
}
