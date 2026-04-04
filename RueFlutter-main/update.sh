#!/usr/bin/env bash
# patch_order_screen.sh
# Usage: ./patch_order_screen.sh path/to/order_screen.dart
#
# Edge-case fixes applied to CheckoutSheet._place() and build():
#   1. Cash tendered < order total → block with error
#   2. Cash mode with no tendered → block with error
#   3. Tip > (tendered - total) → block with error
#   4. Split total validation now accounts for tip
#   5. No payment method selected → block with error
#   6. Empty cart → block with error
#   7. Double-tap guard: early return if _loading already true
#   8. discountType forwarded as raw string (already correct for API layer)

set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 path/to/order_screen.dart" >&2
  exit 1
fi
if [[ ! -f "$TARGET" ]]; then
  echo "Error: file not found: $TARGET" >&2
  exit 1
fi

python3 - "$TARGET" <<'PYEOF'
import sys, shutil, pathlib, datetime

path = pathlib.Path(sys.argv[1])
src  = path.read_text(encoding="utf-8")
original = src
patches_applied = []

# ─────────────────────────────────────────────────────────────────────────────
# PATCH 1 — Replace the entire _place() validation block (up to setState loading)
# Inserts: double-tap guard, empty cart, no payment, cash coverage, tip sanity,
#          and fixes split+tip validation.
# ─────────────────────────────────────────────────────────────────────────────
OLD1 = (
    "    if (shift == null) {\n"
    "      setState(() => _error = 'No open shift');\n"
    "      return;\n"
    "    }\n"
    "\n"
    "    // Validate split amounts sum to total if split mode\n"
    "    List<PaymentSplit>? splits;\n"
    "    if (_isSplit) {\n"
    "      splits = _buildSplits();\n"
    "      if (splits.isEmpty) {\n"
    "        setState(() => _error = 'Add at least one payment');\n"
    "        return;\n"
    "      }\n"
    "      final splitTotal = splits.fold(0, (s, p) => s + p.amount);\n"
    "      if (splitTotal != cart.total) {\n"
    "        setState(() => _error =\n"
    "            'Split total ${egp(splitTotal)} must equal order total ${egp(cart.total)}');\n"
    "        return;\n"
    "      }\n"
    "    }\n"
    "\n"
    "    final int? tendered = _showTendered && !_isSplit\n"
    "        ? (double.tryParse(_tenderedCtrl.text) != null\n"
    "            ? (double.parse(_tenderedCtrl.text) * 100).round()\n"
    "            : null)\n"
    "        : null;\n"
    "\n"
    "    final int? tip = _showTendered && !_isSplit\n"
    "        ? (double.tryParse(_tipCtrl.text) != null &&\n"
    "                double.parse(_tipCtrl.text) > 0\n"
    "            ? (double.parse(_tipCtrl.text) * 100).round()\n"
    "            : null)\n"
    "        : null;\n"
    "\n"
    "    setState(() {\n"
    "      _loading = true;\n"
    "      _error = null;\n"
    "    });\n"
)

NEW1 = (
    "    // Guard: prevent double-tap\n"
    "    if (_loading) return;\n"
    "\n"
    "    // Guard: empty cart\n"
    "    if (cart.isEmpty) {\n"
    "      setState(() => _error = 'Cart is empty');\n"
    "      return;\n"
    "    }\n"
    "\n"
    "    if (shift == null) {\n"
    "      setState(() => _error = 'No open shift');\n"
    "      return;\n"
    "    }\n"
    "\n"
    "    // Guard: payment method required (non-split)\n"
    "    if (!_isSplit && (cart.payment.isEmpty)) {\n"
    "      setState(() => _error = 'Select a payment method');\n"
    "      return;\n"
    "    }\n"
    "\n"
    "    // Parse cash tendered & tip up-front so validation can use them\n"
    "    final int? tendered = _showTendered && !_isSplit\n"
    "        ? (double.tryParse(_tenderedCtrl.text) != null\n"
    "            ? (double.parse(_tenderedCtrl.text) * 100).round()\n"
    "            : null)\n"
    "        : null;\n"
    "\n"
    "    final int? tip = _showTendered && !_isSplit\n"
    "        ? (double.tryParse(_tipCtrl.text) != null &&\n"
    "                double.parse(_tipCtrl.text) > 0\n"
    "            ? (double.parse(_tipCtrl.text) * 100).round()\n"
    "            : null)\n"
    "        : null;\n"
    "\n"
    "    // Cash-mode validations\n"
    "    if (_showTendered && !_isSplit) {\n"
    "      if (tendered == null || tendered == 0) {\n"
    "        setState(() => _error = 'Enter the cash amount tendered');\n"
    "        return;\n"
    "      }\n"
    "      if (tendered < cart.total) {\n"
    "        setState(() => _error =\n"
    "            'Tendered ${egp(tendered)} is less than total ${egp(cart.total)}');\n"
    "        return;\n"
    "      }\n"
    "      final tipAmt = tip ?? 0;\n"
    "      if (tipAmt > (tendered - cart.total)) {\n"
    "        setState(() => _error =\n"
    "            'Tip ${egp(tipAmt)} exceeds change ${egp(tendered - cart.total)}');\n"
    "        return;\n"
    "      }\n"
    "    }\n"
    "\n"
    "    // Validate split amounts sum to total + tip if split mode\n"
    "    List<PaymentSplit>? splits;\n"
    "    if (_isSplit) {\n"
    "      if (_activeSplitMethods.isEmpty) {\n"
    "        setState(() => _error = 'Select at least one payment method');\n"
    "        return;\n"
    "      }\n"
    "      splits = _buildSplits();\n"
    "      if (splits.isEmpty) {\n"
    "        setState(() => _error = 'Enter amounts for selected payment methods');\n"
    "        return;\n"
    "      }\n"
    "      final splitTip = ((double.tryParse(_tipCtrl.text) ?? 0) * 100).round();\n"
    "      final splitTotal = splits.fold(0, (s, p) => s + p.amount);\n"
    "      final expectedTotal = cart.total + splitTip;\n"
    "      if (splitTotal != expectedTotal) {\n"
    "        setState(() => _error =\n"
    "            'Split total ${egp(splitTotal)} must equal order total ${egp(expectedTotal)}');\n"
    "        return;\n"
    "      }\n"
    "    }\n"
    "\n"
    "    setState(() {\n"
    "      _loading = true;\n"
    "      _error = null;\n"
    "    });\n"
)

if OLD1 in src:
    src = src.replace(OLD1, NEW1, 1)
    patches_applied.append("1 - added double-tap guard, empty cart, no payment, cash coverage, tip sanity, split+tip validation")
else:
    print("  WARN patch 1: validation block not found - skipping")

# ─────────────────────────────────────────────────────────────────────────────
# Write output
# ─────────────────────────────────────────────────────────────────────────────
if src == original:
    print("No changes made - all patch targets were missing.")
    sys.exit(0)

backup = path.with_suffix(f".dart.bak_{datetime.datetime.now():%Y%m%d_%H%M%S}")
shutil.copy2(path, backup)
path.write_text(src, encoding="utf-8")

print(f"Backup : {backup}")
print(f"Patched: {path}")
print(f"Applied {len(patches_applied)} patch(es):")
for p in patches_applied:
    print(f"  + {p}")
PYEOF