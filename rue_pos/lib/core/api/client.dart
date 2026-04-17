import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';

String? _currentToken;
void setAuthToken(String? token) => _currentToken = token;
String? get currentToken => _currentToken;

/// Set by AuthNotifier so the Dio layer can trigger logout on 401.
void Function()? onUnauthorizedCallback;

class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(BaseOptions(
      baseUrl:        kApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout:    const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_currentToken != null) {
          options.headers['Authorization'] = 'Bearer $_currentToken';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (err, handler) {
        if (err.response?.statusCode == 401) {
          onUnauthorizedCallback?.call();
        }
        handler.next(err);
      },
    ));
  }

  Dio get dio => _dio;
}

final dioClientProvider = Provider<DioClient>((ref) => DioClient());

String friendlyError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Session expired — please sign in again';
    if (code == 403) return 'You do not have permission to do that';
    if (code == 404) return 'Not found';
    if (code == 409) return 'A conflict occurred — resource already exists';
    if (code == 422) return 'Invalid data submitted';
    if (code != null && code >= 500) return 'Server error — please try again';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout       ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out — check your connection';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection';
    }
    final msg = e.response?.data;
    if (msg is Map && msg['message'] != null) return msg['message'].toString();
    if (msg is Map && msg['error']   != null) return msg['error'].toString();
  }
  return 'Something went wrong — please try again';
}

bool isNetworkError(Object e) {
  if (e is DioException) {
    return e.type == DioExceptionType.connectionError    ||
           e.type == DioExceptionType.connectionTimeout  ||
           e.type == DioExceptionType.sendTimeout        ||
           e.type == DioExceptionType.receiveTimeout;
  }
  return false;
}
