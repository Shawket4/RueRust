import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Token storage
// ---------------------------------------------------------------------------
String? authToken;

/// Callback set by AuthProvider so the HTTP layer can trigger re-login on 401.
void Function()? onUnauthorized;

// ---------------------------------------------------------------------------
// SharedPreferences singleton — avoids repeated getInstance() calls
// ---------------------------------------------------------------------------
SharedPreferences? _prefs;
Future<SharedPreferences> get prefs async =>
    _prefs ??= await SharedPreferences.getInstance();

// ---------------------------------------------------------------------------
// Dio singleton
// ---------------------------------------------------------------------------
final dio = _build();

Dio _build() {
  final d = Dio(BaseOptions(
    baseUrl:        'https://rue-pos.ddns.net/api',
    connectTimeout: const Duration(seconds: 10),
    sendTimeout:    const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    headers: const {'Content-Type': 'application/json'},
  ));

  // ── Request: attach Bearer token ─────────────────────────────────────────
  d.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (authToken != null) {
        options.headers['Authorization'] = 'Bearer $authToken';
      }
      handler.next(options);
    },

    // ── Response: surface API-level errors cleanly ────────────────────────
    onResponse: (response, handler) {
      // Some backends return 200 with {"error": "..."} — surface as exception
      if (response.data is Map &&
          (response.data as Map).containsKey('error') &&
          response.statusCode == 200) {
        handler.reject(DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: (response.data as Map)['error']?.toString(),
        ));
      } else {
        handler.next(response);
      }
    },

    // ── Error: trigger logout on 401 ─────────────────────────────────────
    onError: (err, handler) {
      if (err.response?.statusCode == 401) {
        onUnauthorized?.call();
      }
      handler.next(err);
    },
  ));

  return d;
}

/// Human-readable network error message.
String friendlyError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 401) return 'Session expired — please sign in again';
    if (code == 403) return 'You do not have permission to do that';
    if (code == 404) return 'Not found';
    if (code == 409) return 'Conflict — resource already exists';
    if (code == 422) return 'Invalid data submitted';
    if (code != null && code >= 500) return 'Server error — please try again';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout    ||
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
