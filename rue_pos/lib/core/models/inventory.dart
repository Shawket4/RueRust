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
    id:           j['id'],
    name:         j['name'],
    unit:         j['unit'],
    currentStock: double.tryParse(j['current_stock'].toString()) ?? 0,
  );
}
