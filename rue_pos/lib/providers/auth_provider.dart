import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../api/auth_api.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  User? _user;
  String? _token;
  bool _loading = true;

  User? get user => _user;
  String? get token => _token;
  bool get loading => _loading;
  bool get isAuthenticated => _token != null && _user != null;

  Future<void> init() async {
    _token = await _storage.read(key: 'token');
    if (_token != null) {
      try {
        _user = await authApi.getMe();
      } catch (_) {
        await signOut();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loginWithPin({required String name, required String pin}) async {
    final data = await authApi.loginWithPin(name: name, pin: pin);
    _token = data['token'];
    _user = User.fromJson(data['user']);
    await _storage.write(key: 'token', value: _token);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _storage.delete(key: 'token');
    _token = null;
    _user = null;
    notifyListeners();
  }
}
