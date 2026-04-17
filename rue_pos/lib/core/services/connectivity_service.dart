import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get stream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _pingTimer;

  final _dio = Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  Future<void> init() async {
    await _checkReal();

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final hasInterface = results.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) {
        _emit(false);
      } else {
        _checkReal();
      }
    });

    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkReal();
    });
  }

  Future<void> _checkReal() async {
    try {
      await _dio.get('/health',
          options: Options(
            headers: {},
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ));
      _emit(true);
    } catch (_) {
      _emit(false);
    }
  }

  void _emit(bool online) {
    if (online != _isOnline) {
      _isOnline = online;
      _controller.add(_isOnline);
    }
  }

  void dispose() {
    _sub?.cancel();
    _pingTimer?.cancel();
    _controller.close();
  }
}

final connectivityStreamProvider =
    StreamProvider<bool>((ref) => ConnectivityService.instance.stream);

final isOnlineProvider =
    Provider<bool>((ref) => ref.watch(connectivityStreamProvider).maybeWhen(
          data: (v) => v,
          orElse: () => ConnectivityService.instance.isOnline,
        ));
