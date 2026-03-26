import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get stream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> init() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

final connectivityStreamProvider = StreamProvider<bool>((ref) =>
    ConnectivityService.instance.stream);

final isOnlineProvider = Provider<bool>((ref) =>
    ref.watch(connectivityStreamProvider).maybeWhen(
      data: (v) => v,
      orElse: () => ConnectivityService.instance.isOnline,
    ));
