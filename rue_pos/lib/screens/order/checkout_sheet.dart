import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/shift_provider.dart';
import '../../api/order_api.dart';
import '../../utils/formatting.dart';

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  bool _loading = false;
  String? _error;

  final _methods = ['cash', 'card', 'instapay'];

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();
    final shift = context.read<ShiftProvider>();
    final user = context.read<AuthProvider>().user!;

    if (shift.currentShift == null) {
      setState(() => _error = 'No open shift. Please open a shift first.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await orderApi.createOrder(
        branchId: shift.currentShift!.branchId,
        shiftId: shift.currentShift!.id,
        paymentMethod: cart.paymentMethod,
        items: cart.items.toList(),
        customerName: cart.customerName,
        discountType: cart.discountType,
        discountValue: cart.discountValue,
      );
      cart.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order placed!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to place order. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Checkout',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 20),

          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _SummaryRow('Subtotal', formatEGP(cart.subtotal)),
                if (cart.discountAmount > 0)
                  _SummaryRow('Discount', '- ${formatEGP(cart.discountAmount)}',
                      color: const Color(0xFF059669)),
                const Divider(height: 16),
                _SummaryRow('Total', formatEGP(cart.total), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payment method
          Text('Payment Method',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: _methods.map((m) {
              final selected = cart.paymentMethod == m;
              return GestureDetector(
                onTap: () => cart.setPaymentMethod(m),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1a56db)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    m[0].toUpperCase() + m.substring(1),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF374151)),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFFDC2626))),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a56db),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text('Place Order',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _SummaryRow(this.label, this.value,
      {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500,
                  color: const Color(0xFF374151))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w600,
                  color: color ??
                      (bold
                          ? const Color(0xFF111827)
                          : const Color(0xFF374151)))),
        ],
      ),
    );
  }
}
