import 'dart:convert';
import 'cart.dart';

// ---------------------------------------------------------------------------
// Action types
// ---------------------------------------------------------------------------
enum PendingActionType { shiftOpen, order, shiftClose, voidOrder }

// ---------------------------------------------------------------------------
// Base class
// ---------------------------------------------------------------------------
abstract class PendingAction {
  final String localId; // UUID — used as idempotency key
  final PendingActionType type;
  final DateTime createdAt;
  final int retryCount;

  const PendingAction({
    required this.localId,
    required this.type,
    required this.createdAt,
    this.retryCount = 0,
  });

  PendingAction withIncrementedRetry();
  PendingAction withResetRetry();
  Map<String, dynamic> toJson();

  factory PendingAction.fromJson(Map<String, dynamic> j) {
    final type = PendingActionType.values.byName(j['type'] as String);
    return switch (type) {
      PendingActionType.shiftOpen => PendingShiftOpen.fromJson(j),
      PendingActionType.order => PendingOrder.fromJson(j),
      PendingActionType.shiftClose => PendingShiftClose.fromJson(j),
      PendingActionType.voidOrder => PendingVoidOrder.fromJson(j),
    };
  }
}

// ---------------------------------------------------------------------------
// Shift open
// ---------------------------------------------------------------------------
class PendingShiftOpen extends PendingAction {
  final String branchId;
  final String shiftId; // client-generated UUID — becomes the real ID
  final int openingCash;
  final DateTime openedAt;

  const PendingShiftOpen({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    required this.branchId,
    required this.shiftId,
    required this.openingCash,
    required this.openedAt,
  }) : super(type: PendingActionType.shiftOpen);

  @override
  PendingShiftOpen withIncrementedRetry() => PendingShiftOpen(
        localId: localId,
        createdAt: createdAt,
        branchId: branchId,
        shiftId: shiftId,
        openingCash: openingCash,
        openedAt: openedAt,
        retryCount: retryCount + 1,
      );

  @override
  PendingShiftOpen withResetRetry() => PendingShiftOpen(
        localId: localId,
        createdAt: createdAt,
        branchId: branchId,
        shiftId: shiftId,
        openingCash: openingCash,
        openedAt: openedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'branch_id': branchId,
        'shift_id': shiftId,
        'opening_cash': openingCash,
        'opened_at': openedAt.toIso8601String(),
      };

  factory PendingShiftOpen.fromJson(Map<String, dynamic> j) => PendingShiftOpen(
        localId: j['local_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        retryCount: (j['retry_count'] as int?) ?? 0,
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
  final List<CartItem> items;
  final DateTime orderedAt;

  const PendingOrder({
    required super.localId,
    required super.createdAt,
    super.retryCount,
    required this.branchId,
    required this.shiftId,
    required this.paymentMethod,
    this.customerName,
    this.discountType,
    this.discountValue,
    required this.items,
    required this.orderedAt,
  }) : super(type: PendingActionType.order);

  @override
  PendingOrder withIncrementedRetry() => PendingOrder(
        localId: localId,
        createdAt: createdAt,
        branchId: branchId,
        shiftId: shiftId,
        paymentMethod: paymentMethod,
        customerName: customerName,
        discountType: discountType,
        discountValue: discountValue,
        items: items,
        orderedAt: orderedAt,
        retryCount: retryCount + 1,
      );

  @override
  PendingOrder withResetRetry() => PendingOrder(
        localId: localId,
        createdAt: createdAt,
        branchId: branchId,
        shiftId: shiftId,
        paymentMethod: paymentMethod,
        customerName: customerName,
        discountType: discountType,
        discountValue: discountValue,
        items: items,
        orderedAt: orderedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'branch_id': branchId,
        'shift_id': shiftId,
        'payment_method': paymentMethod,
        'customer_name': customerName,
        'discount_type': discountType,
        'discount_value': discountValue,
        'ordered_at': orderedAt.toIso8601String(),
        'items': items.map((i) => i.toStorageJson()).toList(),
      };

  factory PendingOrder.fromJson(Map<String, dynamic> j) => PendingOrder(
        localId: j['local_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        retryCount: (j['retry_count'] as int?) ?? 0,
        branchId: (j['branch_id'] as String?) ?? '',
        shiftId: j['shift_id'] as String,
        paymentMethod: j['payment_method'] as String,
        customerName: j['customer_name'] as String?,
        discountType: j['discount_type'] as String?,
        discountValue: j['discount_value'] as int?,
        orderedAt: DateTime.parse(
            (j['ordered_at'] as String?) ?? j['created_at'] as String),
        items: (j['items'] as List)
            .map((i) => CartItem.fromStorageJson(i as Map<String, dynamic>))
            .toList(),
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
    required this.branchId,
    required this.shiftId,
    required this.closingCash,
    this.cashNote,
    required this.inventoryCounts,
    required this.closedAt,
  }) : super(type: PendingActionType.shiftClose);

  @override
  PendingShiftClose withIncrementedRetry() => PendingShiftClose(
        localId: localId,
        createdAt: createdAt,
        branchId: branchId,
        shiftId: shiftId,
        closingCash: closingCash,
        cashNote: cashNote,
        inventoryCounts: inventoryCounts,
        closedAt: closedAt,
        retryCount: retryCount + 1,
      );

  @override
  PendingShiftClose withResetRetry() => PendingShiftClose(
        localId: localId,
        createdAt: createdAt,
        branchId: branchId,
        shiftId: shiftId,
        closingCash: closingCash,
        cashNote: cashNote,
        inventoryCounts: inventoryCounts,
        closedAt: closedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'branch_id': branchId,
        'shift_id': shiftId,
        'closing_cash': closingCash,
        'cash_note': cashNote,
        'inventory_counts': inventoryCounts,
        'closed_at': closedAt.toIso8601String(),
      };

  factory PendingShiftClose.fromJson(Map<String, dynamic> j) =>
      PendingShiftClose(
        localId: j['local_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        retryCount: (j['retry_count'] as int?) ?? 0,
        branchId: j['branch_id'] as String,
        shiftId: j['shift_id'] as String,
        closingCash: j['closing_cash'] as int,
        cashNote: j['cash_note'] as String?,
        inventoryCounts:
            (j['inventory_counts'] as List).cast<Map<String, dynamic>>(),
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
    required this.orderId,
    required this.reason,
    required this.restoreInventory,
    required this.voidedAt,
  }) : super(type: PendingActionType.voidOrder);

  @override
  PendingVoidOrder withIncrementedRetry() => PendingVoidOrder(
        localId: localId,
        createdAt: createdAt,
        orderId: orderId,
        reason: reason,
        restoreInventory: restoreInventory,
        voidedAt: voidedAt,
        retryCount: retryCount + 1,
      );

  @override
  PendingVoidOrder withResetRetry() => PendingVoidOrder(
        localId: localId,
        createdAt: createdAt,
        orderId: orderId,
        reason: reason,
        restoreInventory: restoreInventory,
        voidedAt: voidedAt,
      );

  @override
  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'order_id': orderId,
        'reason': reason,
        'restore_inventory': restoreInventory,
        'voided_at': voidedAt.toIso8601String(),
      };

  factory PendingVoidOrder.fromJson(Map<String, dynamic> j) => PendingVoidOrder(
        localId: j['local_id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        retryCount: (j['retry_count'] as int?) ?? 0,
        orderId: j['order_id'] as String,
        reason: j['reason'] as String,
        restoreInventory: (j['restore_inventory'] as bool?) ?? false,
        voidedAt: DateTime.parse(j['voided_at'] as String),
      );
}
