class PaymentSummaryItem {
  final String paymentMethod;
  final int    total;
  final int    orderCount;

  const PaymentSummaryItem({
    required this.paymentMethod,
    required this.total,
    required this.orderCount,
  });

  factory PaymentSummaryItem.fromJson(Map<String, dynamic> j) =>
      PaymentSummaryItem(
        paymentMethod: j['payment_method'] as String,
        total:         (j['total'] as num).toInt(),
        orderCount:    (j['order_count'] as num).toInt(),
      );

  String get displayLabel => switch (paymentMethod) {
    'cash'           => 'Cash',
    'card'           => 'Card',
    'digital_wallet' => 'Digital Wallet',
    'mixed'          => 'Mixed',
    'talabat_online' => 'Talabat Online',
    'talabat_cash'   => 'Talabat Cash',
    _                => paymentMethod[0].toUpperCase() +
                        paymentMethod.substring(1).replaceAll('_', ' '),
  };
}

class CashMovementItem {
  final int      amount;
  final String   note;
  final String   movedByName;
  final DateTime createdAt;

  const CashMovementItem({
    required this.amount,
    required this.note,
    required this.movedByName,
    required this.createdAt,
  });

  bool get isIn => amount > 0;

  factory CashMovementItem.fromJson(Map<String, dynamic> j) =>
      CashMovementItem(
        amount:      (j['amount'] as num).toInt(),
        note:        j['note'] as String,
        movedByName: j['moved_by_name'] as String,
        createdAt:   DateTime.parse(j['created_at'] as String),
      );
}

class ShiftReport {
  final String    shiftId;
  final String    branchId;
  final String    tellerName;
  final String    status;
  final int       openingCash;
  final int?      closingCashDeclared;
  final int?      closingCashSystem;
  final DateTime  openedAt;
  final DateTime? closedAt;

  final List<PaymentSummaryItem> paymentSummary;
  final List<CashMovementItem>   cashMovements;
  final int      totalPayments;
  final int      totalReturns;
  final int      netPayments;
  final int      cashMovementsIn;
  final int      cashMovementsOut;
  final DateTime printedAt;

  const ShiftReport({
    required this.shiftId,
    required this.branchId,
    required this.tellerName,
    required this.status,
    required this.openingCash,
    this.closingCashDeclared,
    this.closingCashSystem,
    required this.openedAt,
    this.closedAt,
    required this.paymentSummary,
    required this.cashMovements,
    required this.totalPayments,
    required this.totalReturns,
    required this.netPayments,
    required this.cashMovementsIn,
    required this.cashMovementsOut,
    required this.printedAt,
  });

  bool get isOpen => status == 'open';

  factory ShiftReport.fromJson(Map<String, dynamic> j) {
    final shift = j['shift'] as Map<String, dynamic>;
    return ShiftReport(
      shiftId:             shift['id'] as String,
      branchId:            shift['branch_id'] as String,
      tellerName:          shift['teller_name'] as String,
      status:              shift['status'] as String,
      openingCash:         (shift['opening_cash'] as num).toInt(),
      closingCashDeclared: shift['closing_cash_declared'] != null
          ? (shift['closing_cash_declared'] as num).toInt() : null,
      closingCashSystem:   shift['closing_cash_system'] != null
          ? (shift['closing_cash_system'] as num).toInt() : null,
      openedAt:  DateTime.parse(shift['opened_at'] as String),
      closedAt:  shift['closed_at'] != null
          ? DateTime.parse(shift['closed_at'] as String) : null,
      paymentSummary: (j['payment_summary'] as List)
          .map((e) => PaymentSummaryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      cashMovements: (j['cash_movements'] as List)
          .map((e) => CashMovementItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalPayments:    (j['total_payments']     as num).toInt(),
      totalReturns:     (j['total_returns']      as num).toInt(),
      netPayments:      (j['net_payments']       as num).toInt(),
      cashMovementsIn:  (j['cash_movements_in']  as num).toInt(),
      cashMovementsOut: (j['cash_movements_out'] as num).toInt(),
      printedAt: DateTime.parse(j['printed_at'] as String),
    );
  }
}
