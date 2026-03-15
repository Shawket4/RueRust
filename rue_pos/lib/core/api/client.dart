import 'package:dio/dio.dart';

String? authToken;

final dio = _build();

Dio _build() {
  final d = Dio(BaseOptions(
    baseUrl:        'http://187.124.33.153:8080',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers:        const {'Content-Type': 'application/json'},
  ));
  d.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (authToken != null) {
        options.headers['Authorization'] = 'Bearer $authToken';
      }
      handler.next(options);
    },
  ));
  return d;
}
