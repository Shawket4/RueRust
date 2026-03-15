class Shift {
  final String    id;
  final String    branchId;
  final String    tellerId;
  final String    tellerName;
  final String    status;
  final int       openingCash;
  final int?      closingCashDeclared;
  final int?      closingCashSystem;
  final int?      cashDiscrepancy;
  final DateTime  openedAt;
  final DateTime? closedAt;

  const Shift({
    required this.id,
    required this.branchId,
    required this.tellerId,
    required this.tellerName,
    required this.status,
    required this.openingCash,
    this.closingCashDeclared,
    this.closingCashSystem,
    this.cashDiscrepancy,
    required this.openedAt,
    this.closedAt,
  });

  bool get isOpen => status == 'open';

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
    id:                  j['id'],
    branchId:            j['branch_id'],
    tellerId:            j['teller_id'],
    tellerName:          j['teller_name'],
    status:              j['status'],
    openingCash:         j['opening_cash'],
    closingCashDeclared: j['closing_cash_declared'],
    closingCashSystem:   j['closing_cash_system'],
    cashDiscrepancy:     j['cash_discrepancy'],
    openedAt:            DateTime.parse(j['opened_at']),
    closedAt:            j['closed_at'] != null ? DateTime.parse(j['closed_at']) : null,
  );
}

class ShiftPreFill {
  final bool   hasOpenShift;
  final Shift? openShift;
  final int    suggestedOpeningCash;

  const ShiftPreFill({
    required this.hasOpenShift,
    this.openShift,
    required this.suggestedOpeningCash,
  });

  factory ShiftPreFill.fromJson(Map<String, dynamic> j) => ShiftPreFill(
    hasOpenShift:         j['has_open_shift'],
    openShift:            j['open_shift'] != null ? Shift.fromJson(j['open_shift']) : null,
    suggestedOpeningCash: j['suggested_opening_cash'],
  );
}
