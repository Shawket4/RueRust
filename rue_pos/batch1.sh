#!/bin/bash

echo "Creating necessary directories..."
mkdir -p lib/core/config
mkdir -p lib/core/models
mkdir -p lib/shared/widgets
mkdir -p lib/core/api
mkdir -p lib/core/services
mkdir -p lib/core/storage

echo "Writing lib/core/config/api_config.dart..."
cat << 'EOF' > lib/core/config/api_config.dart
const String kApiBaseUrl = 'https://rue-pos.ddns.net/api';
EOF

echo "Writing lib/core/models/payment_method.dart..."
cat << 'EOF' > lib/core/models/payment_method.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PaymentMethod {
  cash('cash', 'Cash', Icons.payments_outlined, AppColors.success, true),
  card('card', 'Card', Icons.credit_card_rounded, Color(0xFF7C3AED), false),
  digitalWallet('digital_wallet', 'Digital Wallet', Icons.account_balance_wallet_rounded, Color(0xFF0EA5E9), false),
  mixed('mixed', 'Mixed', Icons.pie_chart_rounded, AppColors.primary, false),
  talabatOnline('talabat_online', 'Talabat Online', Icons.delivery_dining_rounded, Color(0xFFFF6B00), false),
  talabatCash('talabat_cash', 'Talabat Cash', Icons.delivery_dining_rounded, Color(0xFFFF6B00), true);

  final String wireFormat;
  final String label;
  final IconData icon;
  final Color color;
  final bool isCash;

  const PaymentMethod(this.wireFormat, this.label, this.icon, this.color, this.isCash);

  static PaymentMethod fromWire(String val) =>
      values.firstWhere((e) => e.wireFormat == val, orElse: () => PaymentMethod.cash);
}
EOF

echo "Writing lib/shared/widgets/sync_status_banner.dart..."
cat << 'EOF' > lib/shared/widgets/sync_status_banner.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum SyncBannerVariant { offline, syncing, stuck }

class SyncStatusBanner extends StatelessWidget {
  final SyncBannerVariant variant;
  final String text;

  const SyncStatusBanner({super.key, required this.variant, required this.text});

  @override
  Widget build(BuildContext context) {
    final (color, textColor, icon, animate) = switch (variant) {
      SyncBannerVariant.offline => (const Color(0xFFFFF3CD), const Color(0xFF856404), Icons.wifi_off_rounded, false),
      SyncBannerVariant.syncing => (const Color(0xFFCFE2FF), const Color(0xFF084298), Icons.sync_rounded, true),
      SyncBannerVariant.stuck   => (const Color(0xFFFFF3CD), AppColors.warning, Icons.warning_amber_rounded, false),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(children: [
        animate
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
            : Icon(icon, size: 16, color: textColor),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: cairo(fontSize: 12, fontWeight: FontWeight.w600, color: textColor))),
      ]),
    );
  }
}
EOF

echo "Writing lib/shared/widgets/responsive_sheet.dart..."
cat << 'EOF' > lib/shared/widgets/responsive_sheet.dart
import 'package:flutter/material.dart';

class ResponsiveSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    // Device-type based check instead of orientation
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    if (isTablet) {
      return showDialog<T>(
        context: context,
        barrierDismissible: isDismissible,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 850),
            child: builder(ctx),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        isDismissible: isDismissible,
        backgroundColor: Colors.transparent,
        builder: builder,
      );
    }
  }
}
EOF

echo "Writing lib/core/api/client.dart..."
cat << 'EOF' > lib/core/api/client.dart
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
EOF

echo "Writing lib/core/services/connectivity_service.dart..."
cat << 'EOF' > lib/core/services/connectivity_service.dart
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
EOF

echo "Writing lib/core/models/pending_action.dart..."
cat << 'EOF' > lib/core/models/pending_action.dart
import 'cart.dart';

// ---------------------------------------------------------------------------
// Action types
// ---------------------------------------------------------------------------
enum PendingActionType { shiftOpen, order, shiftClose, voidOrder, cashMovement }

// ---------------------------------------------------------------------------
// Base class
// ---------------------------------------------------------------------------
abstract class PendingAction {
  final String localId; 
  final PendingActionType type;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError; 

  const PendingAction({
    required this.localId,
    required this.type,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  PendingAction withIncrementedRetry(String error);
  PendingAction withResetRetry();
  Map<String, dynamic> toJson();

  factory PendingAction.fromJson(Map<String, dynamic> j) {
    final type = PendingActionType.values.byName(j['type'] as String);
    return switch (type) {
      PendingActionType.shiftOpen => PendingShiftOpen.fromJson(j),
      PendingActionType.order => PendingOrder.fromJson(j),
      PendingActionType.shiftClose => PendingShiftClose.fromJson(j),
      PendingActionType.voidOrder => PendingVoidOrder.fromJson(j),
      PendingActionType.cashMovement => PendingCashMovement.fromJson(j),
    };
  }
}

// ---------------------------------------------------------------------------
// Shift open
// ---------------------------------------------------------------------------
class PendingShiftOpen extends PendingAction {
  final String branchId;
  final String shiftId; 
  final int openingCash;
  final DateTime openedAt;

  const PendingShiftOpen({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    super.lastError,
    required this.branchId,
    required this.shiftId,
    required this.openingCash,
    required this.openedAt,
  }) : super(type: PendingActionType.shiftOpen);

  @override
  PendingShiftOpen withIncrementedRetry(String error) => PendingShiftOpen(
        localId: localId, createdAt: createdAt, branchId: branchId,
        shiftId: shiftId, openingCash: openingCash, openedAt: openedAt,
        retryCount: retryCount + 1, lastError: error,
      );

  @override
  PendingShiftOpen withResetRetry() => PendingShiftOpen(
        localId: localId, createdAt: createdAt, branchId: branchId,
        shiftId: shiftId, openingCash: openingCash, openedAt: openedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        'local_id': localId, 'type': type.name, 'created_at': createdAt.toUtc().toIso8601String(),
        'retry_count': retryCount, 'last_error': lastError, 'branch_id': branchId,
        'shift_id': shiftId, 'opening_cash': openingCash, 'opened_at': openedAt.toUtc().toIso8601String(),
      };

  factory PendingShiftOpen.fromJson(Map<String, dynamic> j) => PendingShiftOpen(
        localId: j['local_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        retryCount: (j['retry_count'] as int?) ?? 0,
        lastError: j['last_error'] as String?,
        branchId: j['branch_id'] as String,
        shiftId: j['shift_id'] as String,
        openingCash: j['opening_cash'] as int,
        openedAt: DateTime.parse(j['opened_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Order
// ---------------------------------------------------------------------------
class PendingOrder extends PendingAction {
  final String branchId;
  final String shiftId;
  final String paymentMethod;
  final String? customerName;
  final String? discountType;
  final int? discountValue;
  final String? discountId; 
  final int? amountTendered; 
  final int? tipAmount; 
  final String? tipPaymentMethod;
  final List<PaymentSplit>? paymentSplits; 
  final List<CartItem> items;
  final DateTime orderedAt;

  const PendingOrder({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    super.lastError,
    required this.branchId,
    required this.shiftId,
    required this.paymentMethod,
    this.customerName,
    this.discountType,
    this.discountValue,
    this.discountId,
    this.amountTendered,
    this.tipAmount,
    this.tipPaymentMethod,
    this.paymentSplits,
    required this.items,
    required this.orderedAt,
  }) : super(type: PendingActionType.order);

  @override
  PendingOrder withIncrementedRetry(String error) => PendingOrder(
        localId: localId, createdAt: createdAt, branchId: branchId, shiftId: shiftId,
        paymentMethod: paymentMethod, customerName: customerName, discountType: discountType,
        discountValue: discountValue, discountId: discountId, amountTendered: amountTendered,
        tipAmount: tipAmount, tipPaymentMethod: tipPaymentMethod, paymentSplits: paymentSplits,
        items: items, orderedAt: orderedAt, retryCount: retryCount + 1, lastError: error,
      );

  @override
  PendingOrder withResetRetry() => PendingOrder(
        localId: localId, createdAt: createdAt, branchId: branchId, shiftId: shiftId,
        paymentMethod: paymentMethod, customerName: customerName, discountType: discountType,
        discountValue: discountValue, discountId: discountId, amountTendered: amountTendered,
        tipAmount: tipAmount, tipPaymentMethod: tipPaymentMethod, paymentSplits: paymentSplits,
        items: items, orderedAt: orderedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        'local_id': localId, 'type': type.name, 'created_at': createdAt.toUtc().toIso8601String(),
        'retry_count': retryCount, 'last_error': lastError, 'branch_id': branchId, 'shift_id': shiftId,
        'payment_method': paymentMethod, 'customer_name': customerName, 'discount_type': discountType,
        'discount_value': discountValue, 'discount_id': discountId, 'amount_tendered': amountTendered,
        'tip_amount': tipAmount, 'tip_payment_method': tipPaymentMethod,
        if (paymentSplits != null) 'payment_splits': paymentSplits!.map((s) => s.toApiJson()).toList(),
        'ordered_at': orderedAt.toUtc().toIso8601String(),
        'items': items.map((i) => i.toStorageJson()).toList(),
      };

  factory PendingOrder.fromJson(Map<String, dynamic> j) => PendingOrder(
        localId: j['local_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        retryCount: (j['retry_count'] as int?) ?? 0,
        lastError: j['last_error'] as String?,
        branchId: (j['branch_id'] as String?) ?? '',
        shiftId: j['shift_id'] as String,
        paymentMethod: j['payment_method'] as String,
        customerName: j['customer_name'] as String?,
        discountType: j['discount_type'] as String?,
        discountValue: j['discount_value'] as int?,
        discountId: j['discount_id'] as String?,
        amountTendered: j['amount_tendered'] as int?,
        tipAmount: j['tip_amount'] as int?,
        tipPaymentMethod: j['tip_payment_method'] as String?,
        paymentSplits: (j['payment_splits'] as List?)
            ?.map((s) => PaymentSplit(method: s['method'], amount: s['amount']))
            .toList(),
        orderedAt: DateTime.parse((j['ordered_at'] as String?) ?? j['created_at'] as String),
        items: (j['items'] as List).map((i) => CartItem.fromStorageJson(i as Map<String, dynamic>)).toList(),
      );
}

// ---------------------------------------------------------------------------
// Shift close
// ---------------------------------------------------------------------------
class PendingShiftClose extends PendingAction {
  final String branchId;
  final String shiftId;
  final int closingCash;
  final String? cashNote;
  final List<Map<String, dynamic>> inventoryCounts;
  final DateTime closedAt;

  const PendingShiftClose({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    super.lastError,
    required this.branchId,
    required this.shiftId,
    required this.closingCash,
    this.cashNote,
    required this.inventoryCounts,
    required this.closedAt,
  }) : super(type: PendingActionType.shiftClose);

  @override
  PendingShiftClose withIncrementedRetry(String error) => PendingShiftClose(
        localId: localId, createdAt: createdAt, branchId: branchId, shiftId: shiftId,
        closingCash: closingCash, cashNote: cashNote, inventoryCounts: inventoryCounts,
        closedAt: closedAt, retryCount: retryCount + 1, lastError: error,
      );

  @override
  PendingShiftClose withResetRetry() => PendingShiftClose(
        localId: localId, createdAt: createdAt, branchId: branchId, shiftId: shiftId,
        closingCash: closingCash, cashNote: cashNote, inventoryCounts: inventoryCounts, closedAt: closedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        'local_id': localId, 'type': type.name, 'created_at': createdAt.toUtc().toIso8601String(),
        'retry_count': retryCount, 'last_error': lastError, 'branch_id': branchId, 'shift_id': shiftId,
        'closing_cash': closingCash, 'cash_note': cashNote, 'inventory_counts': inventoryCounts,
        'closed_at': closedAt.toUtc().toIso8601String(),
      };

  factory PendingShiftClose.fromJson(Map<String, dynamic> j) =>
      PendingShiftClose(
        localId: j['local_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        retryCount: (j['retry_count'] as int?) ?? 0,
        lastError: j['last_error'] as String?,
        branchId: j['branch_id'] as String,
        shiftId: j['shift_id'] as String,
        closingCash: j['closing_cash'] as int,
        cashNote: j['cash_note'] as String?,
        inventoryCounts: (j['inventory_counts'] as List).cast<Map<String, dynamic>>(),
        closedAt: DateTime.parse(j['closed_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Void order
// ---------------------------------------------------------------------------
class PendingVoidOrder extends PendingAction {
  final String orderId;
  final String reason;
  final bool restoreInventory;
  final DateTime voidedAt;

  const PendingVoidOrder({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    super.lastError,
    required this.orderId,
    required this.reason,
    required this.restoreInventory,
    required this.voidedAt,
  }) : super(type: PendingActionType.voidOrder);

  @override
  PendingVoidOrder withIncrementedRetry(String error) => PendingVoidOrder(
        localId: localId, createdAt: createdAt, orderId: orderId, reason: reason,
        restoreInventory: restoreInventory, voidedAt: voidedAt, retryCount: retryCount + 1, lastError: error,
      );

  @override
  PendingVoidOrder withResetRetry() => PendingVoidOrder(
        localId: localId, createdAt: createdAt, orderId: orderId, reason: reason,
        restoreInventory: restoreInventory, voidedAt: voidedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        'local_id': localId, 'type': type.name, 'created_at': createdAt.toUtc().toIso8601String(),
        'retry_count': retryCount, 'last_error': lastError, 'order_id': orderId, 'reason': reason,
        'restore_inventory': restoreInventory, 'voided_at': voidedAt.toUtc().toIso8601String(),
      };

  factory PendingVoidOrder.fromJson(Map<String, dynamic> j) => PendingVoidOrder(
        localId: j['local_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        retryCount: (j['retry_count'] as int?) ?? 0,
        lastError: j['last_error'] as String?,
        orderId: j['order_id'] as String,
        reason: j['reason'] as String,
        restoreInventory: (j['restore_inventory'] as bool?) ?? false,
        voidedAt: DateTime.parse(j['voided_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Cash Movement (Task 2.3)
// ---------------------------------------------------------------------------
class PendingCashMovement extends PendingAction {
  final String shiftId;
  final int amount;
  final String note;

  const PendingCashMovement({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    super.lastError,
    required this.shiftId,
    required this.amount,
    required this.note,
  }) : super(type: PendingActionType.cashMovement);

  @override
  PendingCashMovement withIncrementedRetry(String error) => PendingCashMovement(
        localId: localId, createdAt: createdAt, shiftId: shiftId, amount: amount,
        note: note, retryCount: retryCount + 1, lastError: error,
      );

  @override
  PendingCashMovement withResetRetry() => PendingCashMovement(
        localId: localId, createdAt: createdAt, shiftId: shiftId, amount: amount, note: note,
      );

  @override
  Map<String, dynamic> toJson() => {
        'local_id': localId, 'type': type.name, 'created_at': createdAt.toUtc().toIso8601String(),
        'retry_count': retryCount, 'last_error': lastError, 'shift_id': shiftId, 'amount': amount, 'note': note,
      };

  factory PendingCashMovement.fromJson(Map<String, dynamic> j) => PendingCashMovement(
        localId: j['local_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        retryCount: (j['retry_count'] as int?) ?? 0,
        lastError: j['last_error'] as String?,
        shiftId: j['shift_id'] as String,
        amount: j['amount'] as int,
        note: j['note'] as String,
      );
}
EOF

echo "Writing lib/core/services/offline_queue.dart..."
cat << 'EOF' > lib/core/services/offline_queue.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/order_api.dart';
import '../api/shift_api.dart';
import '../api/client.dart';
import '../models/order.dart';
import '../models/pending_action.dart';
import '../models/shift.dart';
import '../storage/storage_service.dart';
import 'connectivity_service.dart';

const _kMaxRetries = 5;

class OfflineQueueState {
  final List<PendingAction> queue;
  final bool isSyncing;

  const OfflineQueueState({
    this.queue = const [],
    this.isSyncing = false,
  });

  int get orderCount => queue.whereType<PendingOrder>().length;
  int get shiftOpenCount => queue.whereType<PendingShiftOpen>().length;
  int get shiftCloseCount => queue.whereType<PendingShiftClose>().length;
  int get voidCount => queue.whereType<PendingVoidOrder>().length;
  int get cashCount => queue.whereType<PendingCashMovement>().length;
  int get totalCount => queue.length;
  int get stuckCount => queue.where((a) => a.retryCount >= _kMaxRetries).length;
  bool get hasStuck => stuckCount > 0;
  bool get isEmpty => queue.isEmpty;

  OfflineQueueState copyWith({
    List<PendingAction>? queue,
    bool? isSyncing,
  }) =>
      OfflineQueueState(
        queue: queue ?? this.queue,
        isSyncing: isSyncing ?? this.isSyncing,
      );
}

class OfflineQueueNotifier extends Notifier<OfflineQueueState> {
  void Function(Order order, String localId)? onOrderSynced;
  void Function(Shift)? onShiftOpenSynced;
  void Function(Shift)? onShiftCloseSynced;
  void Function(Order)? onVoidSynced;

  StreamSubscription<bool>? _connectivitySub;

  @override
  OfflineQueueState build() {
    ref.onDispose(() => _connectivitySub?.cancel());
    return const OfflineQueueState();
  }

  Future<void> init() async {
    _loadFromStorage();
    _connectivitySub = ConnectivityService.instance.stream.listen((online) {
      if (online && !state.isEmpty) syncAll();
    });
    if (ConnectivityService.instance.isOnline && !state.isEmpty) {
      await syncAll();
    }
  }

  void _loadFromStorage() {
    final raw = ref.read(storageServiceProvider).loadPendingActions();
    state = state.copyWith(queue: raw.map(PendingAction.fromJson).toList());
  }

  Future<void> _persist() async {
    await ref.read(storageServiceProvider)
        .savePendingActions(state.queue.map((a) => a.toJson()).toList());
  }

  Future<void> enqueueShiftOpen(PendingShiftOpen action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> enqueueOrder(PendingOrder action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> enqueueShiftClose(PendingShiftClose action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> enqueueVoid(PendingVoidOrder action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> enqueueCashMovement(PendingCashMovement action) async {
    state = state.copyWith(queue: [...state.queue, action]);
    await _persist();
    if (ConnectivityService.instance.isOnline) syncAll();
  }

  Future<void> syncAll() async {
    if (state.isSyncing || state.isEmpty) return;
    state = state.copyWith(isSyncing: true);

    final shiftApi = ref.read(shiftApiProvider);
    final orderApi = ref.read(orderApiProvider);

    final toProcess = List<PendingAction>.of(state.queue);
    final succeeded = <String>{};
    final blockedShifts = <String>{};

    for (final action in toProcess) {
      if (action.retryCount >= _kMaxRetries) continue;

      if (action is! PendingVoidOrder) {
        String? targetShiftId;
        if (action is PendingShiftOpen) targetShiftId = action.shiftId;
        if (action is PendingOrder) targetShiftId = action.shiftId;
        if (action is PendingShiftClose) targetShiftId = action.shiftId;
        if (action is PendingCashMovement) targetShiftId = action.shiftId;
        
        if (targetShiftId != null && blockedShifts.contains(targetShiftId)) continue;
      }

      try {
        switch (action) {
          case PendingShiftOpen():
            final shift = await shiftApi.openWithId(
              branchId: action.branchId, shiftId: action.shiftId,
              openingCash: action.openingCash, openedAt: action.openedAt,
            );
            succeeded.add(action.localId);
            onShiftOpenSynced?.call(shift);

          case PendingOrder():
            final order = await orderApi.create(
              branchId: action.branchId, shiftId: action.shiftId,
              paymentMethod: action.paymentMethod, items: action.items,
              customerName: action.customerName, discountType: action.discountType,
              discountValue: action.discountValue, discountId: action.discountId,
              amountTendered: action.amountTendered, tipAmount: action.tipAmount,
              tipPaymentMethod: action.tipPaymentMethod, paymentSplits: action.paymentSplits,
              idempotencyKey: action.localId, createdAt: action.orderedAt,
            );
            succeeded.add(action.localId);
            onOrderSynced?.call(order, action.localId);

          case PendingShiftClose():
            final shift = await shiftApi.close(
              action.shiftId, closingCash: action.closingCash,
              note: action.cashNote, inventoryCounts: action.inventoryCounts, closedAt: action.closedAt,
            );
            succeeded.add(action.localId);
            onShiftCloseSynced?.call(shift);

          case PendingVoidOrder():
            final order = await orderApi.voidOrder(
              action.orderId, reason: action.reason,
              restoreInventory: action.restoreInventory, voidedAt: action.voidedAt,
            );
            succeeded.add(action.localId);
            onVoidSynced?.call(order);

          case PendingCashMovement():
            await shiftApi.addCashMovement(action.shiftId, action.amount, action.note);
            succeeded.add(action.localId);
        }
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 409) {
          succeeded.add(action.localId);
          continue;
        }

        final errMessage = friendlyError(e);

        final idx = state.queue.indexWhere((a) => a.localId == action.localId);
        if (idx >= 0) {
          final updated = List<PendingAction>.of(state.queue);
          updated[idx] = updated[idx].withIncrementedRetry(errMessage);
          state = state.copyWith(queue: updated);
        }
        
        if (action is PendingShiftOpen) blockedShifts.add(action.shiftId);
        if (action is PendingShiftClose) blockedShifts.add(action.shiftId);
      }
    }

    state = state.copyWith(
      queue: state.queue.where((a) => !succeeded.contains(a.localId)).toList(),
      isSyncing: false,
    );
    await _persist();
  }

  Future<void> discard(String localId) async {
    state = state.copyWith(queue: state.queue.where((a) => a.localId != localId).toList());
    await _persist();
  }

  Future<void> resetRetry(String localId) async {
    state = state.copyWith(
      queue: state.queue.map((a) => a.localId == localId ? a.withResetRetry() : a).toList(),
    );
    await _persist();
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueNotifier, OfflineQueueState>(OfflineQueueNotifier.new);
EOF

echo "Writing lib/core/storage/storage_service.dart..."
cat << 'EOF' > lib/core/storage/storage_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;
  StorageService(this._prefs);

  String? get token => _prefs.getString('auth_token');
  Future<void> saveToken(String t) => _prefs.setString('auth_token', t);
  Future<void> removeToken() => _prefs.remove('auth_token');

  Future<void> saveUser(Map<String, dynamic> j) => _prefs.setString('cached_user', jsonEncode(j));
  Map<String, dynamic>? loadUser() {
    final raw = _prefs.getString('cached_user');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { 
      _prefs.remove('cached_user'); return null; 
    }
  }
  Future<void> removeUser() => _prefs.remove('cached_user');

  Future<void> saveBranch(String id, Map<String, dynamic> j) => _prefs.setString('branch_$id', jsonEncode(j));
  Map<String, dynamic>? loadBranch(String id) {
    final raw = _prefs.getString('branch_$id');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { 
      _prefs.remove('branch_$id'); return null; 
    }
  }

  Future<void> saveShift(String branchId, Map<String, dynamic> j) => _prefs.setString('shift_$branchId', jsonEncode(j));
  Map<String, dynamic>? loadShift(String branchId) {
    final raw = _prefs.getString('shift_$branchId');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { 
      _prefs.remove('shift_$branchId'); return null; 
    }
  }
  Future<void> removeShift(String branchId) => _prefs.remove('shift_$branchId');

  Future<void> saveMenu(String orgId, Map<String, dynamic> j) async {
    await _prefs.setString('menu_v2_$orgId', jsonEncode(j));
    await _prefs.setString('menu_cached_at_$orgId', DateTime.now().toIso8601String());
  }
  Map<String, dynamic>? loadMenu(String orgId) {
    final raw = _prefs.getString('menu_v2_$orgId');
    if (raw == null) return null;
    try { return jsonDecode(raw) as Map<String, dynamic>; } catch (_) { 
      _prefs.remove('menu_v2_$orgId'); return null; 
    }
  }
  DateTime? menuCachedAt(String orgId) {
    final raw = _prefs.getString('menu_cached_at_$orgId');
    if (raw == null) return null;
    try { return DateTime.parse(raw); } catch (_) { return null; }
  }

  Future<void> saveDiscounts(String orgId, List<Map<String, dynamic>> discounts) =>
      _prefs.setString('discounts_$orgId', jsonEncode(discounts));

  List<Map<String, dynamic>> loadDiscounts(String orgId) {
    final raw = _prefs.getString('discounts_$orgId');
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { 
      _prefs.remove('discounts_$orgId'); return []; 
    }
  }

  Future<void> saveOrders(String shiftId, List<Map<String, dynamic>> orders) =>
      _prefs.setString('orders_$shiftId', jsonEncode(orders));

  List<Map<String, dynamic>>? loadOrders(String shiftId) {
    final raw = _prefs.getString('orders_$shiftId');
    if (raw == null) return null;
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { 
      _prefs.remove('orders_$shiftId'); return null; 
    }
  }

  static const _pendingKey = 'offline_pending_actions_v2';

  Future<void> savePendingActions(List<Map<String, dynamic>> actions) =>
      _prefs.setString(_pendingKey, jsonEncode(actions));

  List<Map<String, dynamic>> loadPendingActions() {
    final raw = _prefs.getString(_pendingKey);
    if (raw == null) return [];
    try { return (jsonDecode(raw) as List).cast<Map<String, dynamic>>(); } catch (_) { 
      _prefs.remove(_pendingKey); return []; 
    }
  }

  Future<void> clearAuth() async {
    await removeToken();
    await removeUser();
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});
EOF

echo "Batch 1 complete."