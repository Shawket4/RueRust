import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/menu.dart';
import '../../models/order.dart';
import '../../providers/cart_provider.dart';
import '../../utils/formatting.dart';

class ItemDetailSheet extends StatefulWidget {
  final MenuItem item;
  const ItemDetailSheet({super.key, required this.item});

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  String? _selectedSize;
  final Map<String, String> _selectedOptions = {}; // groupId -> optionItemId
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.item.sizes.isNotEmpty) {
      _selectedSize = widget.item.sizes.first.label;
    }
  }

  int get _unitPrice {
    if (_selectedSize != null) {
      return widget.item.priceForSize(_selectedSize);
    }
    return widget.item.basePrice;
  }

  int get _addonsPrice {
    int total = 0;
    for (final group in widget.item.optionGroups) {
      final selectedId = _selectedOptions[group.id];
      if (selectedId != null) {
        final opt = group.items.where((i) => i.id == selectedId).firstOrNull;
        if (opt != null) total += opt.priceModifier;
      }
    }
    return total;
  }

  int get _total => (_unitPrice + _addonsPrice) * _quantity;

  void _addToCart() {
    final addons = <CartAddon>[];
    for (final group in widget.item.optionGroups) {
      final selectedId = _selectedOptions[group.id];
      if (selectedId != null) {
        final opt = group.items.where((i) => i.id == selectedId).firstOrNull;
        if (opt != null) {
          addons.add(CartAddon(
            addonItemId: opt.id,
            drinkOptionItemId: opt.id,
            name: opt.name,
            price: opt.priceModifier,
          ));
        }
      }
    }

    context.read<CartProvider>().addItem(CartItem(
          menuItemId: widget.item.id,
          itemName: widget.item.name,
          sizeLabel: _selectedSize,
          unitPrice: _unitPrice,
          quantity: _quantity,
          addons: addons,
        ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.item.name,
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827)),
          ),
          if (widget.item.description != null) ...[
            const SizedBox(height: 6),
            Text(widget.item.description!,
                style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF6B7280))),
          ],
          const SizedBox(height: 20),

          // Sizes
          if (widget.item.sizes.isNotEmpty) ...[
            _SectionLabel('Size'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: widget.item.sizes.map((s) {
                final selected = s.label == _selectedSize;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSize = s.label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1a56db)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${s.label} — ${formatEGP(s.price)}',
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
            const SizedBox(height: 16),
          ],

          // Option groups
          for (final group in widget.item.optionGroups) ...[
            _SectionLabel(group.name + (group.isRequired ? ' *' : '')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: group.items.map((opt) {
                final selected = _selectedOptions[group.id] == opt.id;
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedOptions.remove(group.id);
                    } else {
                      _selectedOptions[group.id] = opt.id;
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1a56db)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      opt.priceModifier > 0
                          ? '${opt.name} +${formatEGP(opt.priceModifier)}'
                          : opt.name,
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
            const SizedBox(height: 16),
          ],

          // Quantity
          Row(
            children: [
              _SectionLabel('Quantity'),
              const Spacer(),
              _QtyControl(
                quantity: _quantity,
                onMinus: () => setState(
                    () => _quantity = (_quantity - 1).clamp(1, 99)),
                onPlus: () =>
                    setState(() => _quantity = (_quantity + 1).clamp(1, 99)),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Add to cart
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a56db),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Add to Order — ${formatEGP(_total)}',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6B7280),
            letterSpacing: 0.5),
      );
}

class _QtyControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyControl(
      {required this.quantity,
      required this.onMinus,
      required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Btn(icon: Icons.remove, onTap: onMinus),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$quantity',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827))),
        ),
        _Btn(icon: Icons.add, onTap: onPlus),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: const Color(0xFF374151)),
      ),
    );
  }
}
