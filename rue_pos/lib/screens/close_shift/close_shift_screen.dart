import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../api/inventory_api.dart';
import '../../models/inventory.dart';
import '../../utils/formatting.dart';
import '../../widgets/rue_button.dart';

class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key});

  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  final _cashController = TextEditingController();
  final _noteController = TextEditingController();
  List<InventoryItem> _inventoryItems = [];
  final Map<String, TextEditingController> _countControllers = {};
  bool _loadingInventory = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final shift =
        context.read<ShiftProvider>().currentShift;
    if (shift == null) return;
    try {
      final items = await inventoryApi.getItems(shift.branchId);
      setState(() {
        _inventoryItems = items;
        for (final item in items) {
          _countControllers[item.id] =
              TextEditingController(text: item.currentStock.toString());
        }
        _loadingInventory = false;
      });
    } catch (_) {
      setState(() => _loadingInventory = false);
    }
  }

  Future<void> _close() async {
    final raw = double.tryParse(_cashController.text);
    if (raw == null) {
      setState(() => _error = 'Enter a valid closing cash amount');
      return;
    }

    final piastres = (raw * 100).round();
    final counts = _countControllers.entries.map((e) {
      return {
        'inventory_item_id': e.key,
        'actual_stock': double.tryParse(e.value.text) ?? 0,
      };
    }).toList();

    setState(() { _submitting = true; _error = null; });

    final shift = context.read<ShiftProvider>().currentShift!;
    await context.read<ShiftProvider>().closeShift(
          shift.id,
          closingCash: piastres,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          inventoryCounts: counts,
        );

    if (mounted) {
      final err = context.read<ShiftProvider>().error;
      if (err != null) {
        setState(() { _error = err; _submitting = false; });
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftProvider>().currentShift;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF111827)),
          onPressed: () => context.go('/home'),
        ),
        title: Text('Close Shift',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827))),
      ),
      body: shift == null
          ? const Center(child: Text('No open shift'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shift summary card
                      _ShiftSummaryCard(shift: shift),
                      const SizedBox(height: 24),

                      // Closing cash
                      _SectionCard(
                        title: 'Closing Cash',
                        child: Column(
                          children: [
                            TextField(
                              controller: _cashController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'))
                              ],
                              style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827)),
                              decoration: InputDecoration(
                                prefixText: 'EGP ',
                                prefixStyle: GoogleFonts.inter(
                                    fontSize: 18,
                                    color: const Color(0xFF6B7280)),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1a56db), width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _noteController,
                              style: GoogleFonts.inter(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Note (optional)',
                                hintStyle: GoogleFonts.inter(
                                    color: const Color(0xFF9CA3AF)),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF1a56db), width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Inventory counts
                      _SectionCard(
                        title: 'Inventory Count',
                        child: _loadingInventory
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF1a56db)),
                                ),
                              )
                            : _inventoryItems.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text('No inventory items',
                                        style: GoogleFonts.inter(
                                            color:
                                                const Color(0xFF9CA3AF))),
                                  )
                                : Column(
                                    children:
                                        _inventoryItems.map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(item.name,
                                                      style: GoogleFonts
                                                          .inter(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: const Color(
                                                                  0xFF111827))),
                                                  Text(
                                                      'System: ${item.currentStock} ${item.unit}',
                                                      style: GoogleFonts
                                                          .inter(
                                                              fontSize: 12,
                                                              color: const Color(
                                                                  0xFF6B7280))),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 120,
                                              child: TextField(
                                                controller:
                                                    _countControllers[
                                                        item.id],
                                                keyboardType: const TextInputType
                                                    .numberWithOptions(
                                                    decimal: true),
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                decoration: InputDecoration(
                                                  suffixText: item.unit,
                                                  border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  10)),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(10),
                                                    borderSide:
                                                        const BorderSide(
                                                            color: Color(
                                                                0xFF1a56db),
                                                            width: 2),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                      ),
                      const SizedBox(height: 16),

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error!,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFFDC2626))),
                        ),
                        const SizedBox(height: 12),
                      ],

                      RueButton(
                        label: 'Close Shift',
                        loading: _submitting,
                        onTap: _close,
                        width: double.infinity,
                        color: const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ShiftSummaryCard extends StatelessWidget {
  final shift;
  const _ShiftSummaryCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shift Summary',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 12),
          _Row('Teller', shift.tellerName),
          _Row('Opening Cash', formatEGP(shift.openingCash)),
          _Row('Opened At', shift.openedAt.toLocal().toString().substring(0, 16)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF6B7280))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(title,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827))),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
