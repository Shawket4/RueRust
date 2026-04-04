class Discount {
  final String  id;
  final String  orgId;
  final String  name;
  final String  dtype;   // "percentage" | "fixed"
  final int     value;   // integer % or piastres
  final bool    isActive;

  const Discount({
    required this.id,
    required this.orgId,
    required this.name,
    required this.dtype,
    required this.value,
    required this.isActive,
  });

  factory Discount.fromJson(Map<String, dynamic> j) => Discount(
    id:       j['id']        as String,
    orgId:    j['org_id']    as String,
    name:     j['name']      as String,
    dtype:    j['dtype']     as String,
    value:    j['value']     as int,
    isActive: j['is_active'] as bool,
  );

  /// Human-readable label, e.g. "Staff (10%)" or "Promo (EGP 5)"
  String get label {
    if (dtype == 'percentage') return '$name ($value%)';
    final egp = (value / 100).toStringAsFixed(value % 100 == 0 ? 0 : 2);
    return '$name (EGP $egp off)';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'name': name,
    'dtype': dtype, 'value': value, 'is_active': isActive,
  };
}
