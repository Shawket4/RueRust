import 'client.dart';
import '../models/user.dart';

class AuthApi {
  Future<Map<String, dynamic>> loginWithPin({
    required String name,
    required String pin,
  }) async {
    final res = await dio.post('/auth/login', data: {'name': name, 'pin': pin});
    return res.data as Map<String, dynamic>;
  }

  Future<User> me() async {
    final res = await dio.get('/auth/me');
    return User.fromJson(res.data['user'] as Map<String, dynamic>);
  }
}

final authApi = AuthApi();
