#!/usr/bin/env python3
"""
Patches src/orders/handlers.rs:
1. Injects pg_advisory_xact_lock before the MAX(order_number) query
2. Adds restore_inventory field + logic to VoidOrderRequest / void_order handler
"""
import sys, re

path = sys.argv[1]
with open(path, 'r') as f:
    src = f.read()

original = src

# ── Fix #2: advisory lock ─────────────────────────────────────────────────
if 'pg_advisory_xact_lock' not in src:
    lines = src.split('\n')
    new_lines = []
    injected = False
    for i, line in enumerate(lines):
        if not injected and 'MAX(order_number)' in line:
            indent = ' ' * (len(line) - len(line.lstrip()))
            new_lines.append(indent + '// Serialize order creation per shift — prevents duplicate order_number')
            new_lines.append(indent + 'sqlx::query!("SELECT pg_advisory_xact_lock(hashtext($1::text))", shift_id.to_string())')
            new_lines.append(indent + '    .execute(&mut *tx)')
            new_lines.append(indent + '    .await?;')
            new_lines.append('')
            injected = True
        new_lines.append(line)
    if injected:
        src = '\n'.join(new_lines)
        print("  patched: advisory lock injected before MAX(order_number)")
    else:
        print("  WARN: MAX(order_number) not found — add advisory lock manually")
else:
    print("  skip: advisory lock already present")

# ── Fix #9: restore_inventory in VoidOrderRequest ────────────────────────
if 'restore_inventory' not in src:
    # Add field to VoidOrderRequest struct
    if 'VoidOrderRequest' in src:
        idx = src.find('VoidOrderRequest')
        brace_start = src.find('{', idx)
        brace_end = src.find('}', brace_start)
        if brace_end > brace_start:
            src = src[:brace_end] + '\n    pub restore_inventory: Option<bool>,' + src[brace_end:]
            print("  patched: restore_inventory added to VoidOrderRequest")
        else:
            print("  WARN: could not find VoidOrderRequest closing brace")
    else:
        print("  WARN: VoidOrderRequest not found")

    # Inject restore logic before tx.commit() in void_order
    void_fn_idx = src.find('async fn void_order')
    if void_fn_idx == -1:
        void_fn_idx = src.find('pub async fn void_order')

    if void_fn_idx > 0:
        commit_idx = src.find('tx.commit().await?;', void_fn_idx)
        if commit_idx > 0:
            restore_block = '''
    // Optionally restore inventory when voiding
    if payload.restore_inventory.unwrap_or(false) {
        let logs = sqlx::query!(
            "SELECT inventory_item_id, quantity_deducted FROM inventory_deduction_logs WHERE order_id = $1",
            *id
        )
        .fetch_all(&mut *tx)
        .await?;

        for log in &logs {
            sqlx::query!(
                "UPDATE inventory_items SET current_stock = current_stock + $1 WHERE id = $2",
                log.quantity_deducted, log.inventory_item_id
            )
            .execute(&mut *tx)
            .await?;
        }
        tracing::info!("Restored inventory for voided order {} ({} entries)", id, logs.len());
    }

'''
            src = src[:commit_idx] + restore_block + src[commit_idx:]
            print("  patched: restore_inventory logic injected in void_order")
        else:
            print("  WARN: tx.commit() not found in void_order")
    else:
        print("  WARN: void_order function not found")
else:
    print("  skip: restore_inventory already present")

if src != original:
    with open(path, 'w') as f:
        f.write(src)
    print("  saved:", path)
else:
    print("  no changes made")

