class InventoryItem {
  final String id;
  final String branchId;
  final String name;
  final String unit;
  final double currentStock;
  final double reorderThreshold;

  const InventoryItem({
    required this.id,
    required this.branchId,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.reorderThreshold,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
        id: j['id'],
        branchId: j['branch_id'],
        name: j['name'],
        unit: j['unit'],
        currentStock: double.tryParse(j['current_stock'].toString()) ?? 0,
        reorderThreshold:
            double.tryParse(j['reorder_threshold'].toString()) ?? 0,
      );
}
