import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../api/auth_api.dart';
import '../api/client.dart';

class AuthProvider extends ChangeNotifier {
  User?   _user;
  bool    _loading = true;

  User?  get user    => _user;
  bool   get loading => _loading;
  bool   get isAuthenticated => authToken != null && _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('token');
    if (authToken != null) {
      try {
        _user = await authApi.me();
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
    notifyListeners();
  }

  Future<void> logout() async {
    await _clear();
    notifyListeners();
  }

  Future<void> _clear() async {
    authToken = null;
    _user     = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}
