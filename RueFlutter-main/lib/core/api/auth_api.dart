import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import 'client.dart';

class AuthApi {
  final DioClient _c;
  AuthApi(this._c);

  Future<Map<String, dynamic>> loginWithPin(
      {required String name, required String pin}) async {
    final res = await _c.dio.post('/auth/login', data: {'name': name, 'pin': pin});
    return res.data as Map<String, dynamic>;
  }

  Future<User> me() async {
    final res = await _c.dio.get('/auth/me');
    return User.fromJson(res.data['user'] as Map<String, dynamic>);
  }
}

final authApiProvider = Provider<AuthApi>(
    (ref) => AuthApi(ref.watch(dioClientProvider)));
