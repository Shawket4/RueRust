import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/auth_api.dart';
import '../api/client.dart';
import '../models/user.dart';
import '../storage/storage_service.dart';

class AuthRepository {
  final AuthApi        _api;
  final StorageService _storage;
  AuthRepository(this._api, this._storage);

  String? get storedToken => _storage.token;

  /// Restore session from disk. Returns null if invalid / no token.
  Future<({String token, User user})?> restoreSession() async {
    final token = _storage.token;
    if (token == null) return null;
    setAuthToken(token);
    try {
      final user = await _api.me();
      await _storage.saveUser(user.toJson());
      return (token: token, user: user);
    } catch (e) {
      if (isNetworkError(e)) {
        final cached = _storage.loadUser();
        if (cached != null) {
          return (token: token, user: User.fromJson(cached));
        }
      }
      // 401 or no cache → clear
      await _storage.clearAuth();
      setAuthToken(null);
      return null;
    }
  }

  Future<({String token, User user})> login(
      {required String name, required String pin}) async {
    final data  = await _api.loginWithPin(name: name, pin: pin);
    final token = data['token'] as String;
    final user  = User.fromJson(data['user'] as Map<String, dynamic>);
    setAuthToken(token);
    await _storage.saveToken(token);
    await _storage.saveUser(user.toJson());
    return (token: token, user: user);
  }

  Future<void> logout() async {
    setAuthToken(null);
    await _storage.clearAuth();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
  ref.watch(authApiProvider),
  ref.watch(storageServiceProvider),
));
