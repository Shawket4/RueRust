class InventoryItem {
  final String id;
  final String name;
  final String unit;
  final double currentStock;

  const InventoryItem({
    required this.id, required this.name,
    required this.unit, required this.currentStock,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
    id:           j['id'],               // branch_inventory row id — used in close shift counts
    name:         j['ingredient_name'],   // was j['name'] — now ingredient_name in new schema
    unit:         j['unit'],
    currentStock: double.tryParse(j['current_stock'].toString()) ?? 0,
  );
}
