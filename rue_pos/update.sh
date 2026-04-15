#!/usr/bin/env bash
# =============================================================
# fix_v6_duplicates.sh
# Removes duplicate field/getter declarations inserted by
# the two patch runs, and adds missing menuApiProvider import.
# Run from Flutter project root: bash fix_v6_duplicates.sh
# =============================================================
set -e

echo "=== Fix v6 duplicate declarations ==="

python3 - << 'PYEOF'
with open('lib/features/order/order_screen.dart', 'r') as f:
    src = f.read()

original_len = len(src)

# ── 1. Remove the SECOND set of duplicate field declarations ──
# The first set (lines ~876-878) is correct and used.
# The second set (lines ~881-883) is the duplicate from the second patch run.
# They look like:
#   List<OptionalField> _optionalFields       = [];   <- keep (first)
#   bool _optionalFieldsLoading = false;              <- keep (first)
#   final Set<String> _selectedOptionals = {};        <- keep (first)
#   ...
#   List<OptionalField> _optionalFields       = [];   <- remove (second)
#   bool _optionalFieldsLoading = false;              <- remove (second)
#   final Set<String> _selectedOptionals = {};        <- remove (second)

import re

# Remove duplicate field block (second occurrence of the three fields together)
# We'll do it by finding the pattern twice and removing the second occurrence

def remove_second_occurrence(text, pattern):
    first = text.find(pattern)
    if first == -1:
        return text, False
    second = text.find(pattern, first + len(pattern))
    if second == -1:
        return text, False
    return text[:second] + text[second + len(pattern):], True

# The three field declarations that got duplicated
field1 = '  List<OptionalField> _optionalFields       = [];\n'
field2 = '  bool                _optionalFieldsLoading = false;\n'
field3 = '  final Set<String>   _selectedOptionals     = {};\n'

# Also try variant spellings from the two different patches
variants_field1 = [
    '  List<OptionalField> _optionalFields       = [];\n',
    '  List<OptionalField> _optionalFields = [];\n',
]
variants_field2 = [
    '  bool                _optionalFieldsLoading = false;\n',
    '  bool _optionalFieldsLoading = false;\n',
]
variants_field3 = [
    '  final Set<String>   _selectedOptionals     = {};\n',
    '  final Set<String> _selectedOptionals = {};\n',
]

changed = False
for v1 in variants_field1:
    src, ok = remove_second_occurrence(src, v1)
    if ok:
        print(f"  ✓ Removed duplicate: _optionalFields")
        changed = True
        break

for v2 in variants_field2:
    src, ok = remove_second_occurrence(src, v2)
    if ok:
        print(f"  ✓ Removed duplicate: _optionalFieldsLoading")
        changed = True
        break

for v3 in variants_field3:
    src, ok = remove_second_occurrence(src, v3)
    if ok:
        print(f"  ✓ Removed duplicate: _selectedOptionals")
        changed = True
        break

# ── 2. Remove duplicate _optionalsTotal getter ────────────────
getter = '''  int get _optionalsTotal =>
      _optionalFields
          .where((f) => _selectedOptionals.contains(f.id))
          .fold(0, (s, f) => s + f.price);'''

src, ok = remove_second_occurrence(src, getter)
if ok:
    print("  ✓ Removed duplicate: _optionalsTotal getter")
else:
    # Try alternate formatting
    getter2 = '''  int get _optionalsTotal =>
      _optionalFields
          .where((f) => _selectedOptionals.contains(f.id))
          .fold(0, (s, f) => s + f.price);\n'''
    src, ok = remove_second_occurrence(src, getter2)
    if ok:
        print("  ✓ Removed duplicate: _optionalsTotal getter (alt)")
    else:
        print("  ~ _optionalsTotal duplicate not found by string match")

# ── 3. Fix menuApiProvider undefined — add import ─────────────
menu_api_import = "import '../../core/api/menu_api.dart';"
if menu_api_import not in src:
    # Insert after recipe_api import
    recipe_import = "import '../../core/api/recipe_api.dart';"
    if recipe_import in src:
        src = src.replace(
            recipe_import,
            recipe_import + '\n' + menu_api_import,
            1
        )
        print("  ✓ Added menu_api.dart import")
    else:
        # Insert after order_api import
        order_import = "import '../../core/api/order_api.dart';"
        if order_import in src:
            src = src.replace(
                order_import,
                order_import + '\n' + menu_api_import,
                1
            )
            print("  ✓ Added menu_api.dart import (after order_api)")
        else:
            print("  ✗ Could not find anchor for menu_api import")
else:
    print("  ✓ menu_api.dart already imported")

# ── 4. Remove unused allAddons local variable in _addToCart ──
# line: final allAddons = ref.read(menuProvider).allAddons;
# This was left over from before and is now unused
old_all_addons = '''    final allAddons   = ref.read(menuProvider).allAddons;
    final slottedTypes = widget.item.addonSlots.map((s) => s.addonType).toSet();'''
if old_all_addons in src:
    src = src.replace(old_all_addons,
        '    final slottedTypes = widget.item.addonSlots.map((s) => s.addonType).toSet();', 1)
    print("  ✓ Removed unused allAddons variable")
else:
    # Try other variant
    old2 = '    final allAddons    = ref.read(menuProvider).allAddons;\n'
    if old2 in src:
        src = src.replace(old2, '', 1)
        print("  ✓ Removed unused allAddons variable (alt)")
    else:
        print("  ~ allAddons variable not found or already removed")

# ── 5. Remove unused _emptyAddon function ────────────────────
empty_addon = '''// Safe sentinel — no orgId field, matches current AddonItem constructor
AddonItem _emptyAddon() => const AddonItem(
    id: '', name: '', addonType: '', defaultPrice: 0,
    isActive: false, displayOrder: 0);'''
if empty_addon in src:
    src = src.replace(empty_addon, '', 1)
    print("  ✓ Removed unused _emptyAddon function")
else:
    print("  ~ _emptyAddon not found or already removed")

final_len = len(src)
print(f"\n  File size: {original_len} → {final_len} chars ({original_len - final_len} removed)")

with open('lib/features/order/order_screen.dart', 'w') as f:
    f.write(src)

print("\n✓ order_screen.dart cleaned up")
PYEOF

echo ""
echo "=== Verifying remaining errors ==="
flutter analyze lib/features/order/order_screen.dart 2>&1 | grep -E "error|Error" | head -20 || echo "No errors found"
flutter analyze lib/core/providers/menu_notifier.dart 2>&1 | grep -E "error|Error" | head -10 || echo "No errors found"