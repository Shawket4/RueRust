#!/usr/bin/env python3
"""
fix_reports.py
Fixes correlated-subquery bugs in src/reports/handlers.rs:
  1. branch_sales_timeseries  – adds column aliases + LEFT JOIN order_payments
  2. shift_summary            – same fix + fixes missing comma before total_discount
  3. org_branch_comparison    – same fix + uses COUNT(DISTINCT o.id)

Usage:
    python fix_reports.py                          # fixes ./src/reports/handlers.rs in place
    python fix_reports.py path/to/handlers.rs      # fixes a specific file
"""

import re
import sys
from pathlib import Path

# ── helpers ──────────────────────────────────────────────────────────────────

def replace_block(source: str, old: str, new: str, label: str) -> str:
    if old not in source:
        print(f"  [WARN] Could not find block for '{label}' – skipping.")
        return source
    result = source.replace(old, new, 1)
    print(f"  [OK]   Fixed '{label}'.")
    return result


# ══════════════════════════════════════════════════════════════════════════════
# 1.  branch_sales_timeseries
# ══════════════════════════════════════════════════════════════════════════════

OLD_TIMESERIES = r"""            COUNT(*)        FILTER (WHERE status != 'voided')::bigint  AS orders,
            COALESCE(SUM(total_amount)    FILTER (WHERE status != 'voided'), 0)::bigint AS revenue,
            COUNT(*)        FILTER (WHERE status = 'voided')::bigint   AS voided,
            COALESCE(SUM(discount_amount) FILTER (WHERE status != 'voided'), 0)::bigint AS discount,
            COALESCE(SUM(tax_amount)      FILTER (WHERE status != 'voided'), 0)::bigint AS tax,
                        COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'cash'), 0),
            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'card'), 0),
            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'digital_wallet'), 0),
            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'mixed'), 0),
            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'talabat_online'), 0),
            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oi ON oi.id = op.order_id WHERE oi.branch_id = $1 AND oi.status != 'voided' AND ($2::timestamptz IS NULL OR oi.created_at >= $2) AND ($3::timestamptz IS NULL OR oi.created_at <= $3) AND op.method = 'talabat_cash'), 0)
        FROM orders
        WHERE branch_id = $1
          AND ($2::timestamptz IS NULL OR created_at >= $2)
          AND ($3::timestamptz IS NULL OR created_at <= $3)
        GROUP BY date_trunc('{trunc}', created_at AT TIME ZONE 'Africa/Cairo')
        ORDER BY 1 ASC"""

NEW_TIMESERIES = r"""            COUNT(o.id)   FILTER (WHERE o.status != 'voided')::bigint  AS orders,
            COALESCE(SUM(o.total_amount)    FILTER (WHERE o.status != 'voided'), 0)::bigint AS revenue,
            COUNT(o.id)   FILTER (WHERE o.status  = 'voided')::bigint  AS voided,
            COALESCE(SUM(o.discount_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint AS discount,
            COALESCE(SUM(o.tax_amount)      FILTER (WHERE o.status != 'voided'), 0)::bigint AS tax,
            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'cash'),           0)::bigint AS cash_revenue,
            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'card'),           0)::bigint AS card_revenue,
            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'digital_wallet'), 0)::bigint AS digital_wallet_revenue,
            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'mixed'),          0)::bigint AS mixed_revenue,
            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'talabat_online'), 0)::bigint AS talabat_online_revenue,
            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'talabat_cash'),   0)::bigint AS talabat_cash_revenue
        FROM orders o
        LEFT JOIN order_payments op ON op.order_id = o.id
        WHERE o.branch_id = $1
          AND ($2::timestamptz IS NULL OR o.created_at >= $2)
          AND ($3::timestamptz IS NULL OR o.created_at <= $3)
        GROUP BY date_trunc('{trunc}', o.created_at AT TIME ZONE 'Africa/Cairo')
        ORDER BY 1 ASC"""

# also fix the to_char reference (uses bare `created_at`, needs `o.created_at`)
OLD_TIMESERIES_TOCHAR = "date_trunc('{trunc}', created_at AT TIME ZONE 'Africa/Cairo'),\n            'YYYY-MM-DD\"T\"HH24:MI:SS'\n            ) AS period,"
NEW_TIMESERIES_TOCHAR = "date_trunc('{trunc}', o.created_at AT TIME ZONE 'Africa/Cairo'),\n            'YYYY-MM-DD\"T\"HH24:MI:SS'\n            ) AS period,"


# ══════════════════════════════════════════════════════════════════════════════
# 2.  shift_summary
# ══════════════════════════════════════════════════════════════════════════════

OLD_SHIFT_SUMMARY_PAYMENTS = (
    "            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint                                            AS total_revenue,\n"
    "                        COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'cash'), 0)::bigint           AS cash_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'card'), 0)::bigint           AS card_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'digital_wallet'), 0)::bigint AS digital_wallet_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'mixed'), 0)::bigint          AS mixed_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'talabat_online'), 0)::bigint  AS talabat_online_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'talabat_cash'), 0)::bigint   AS talabat_cash_revenue\n"
    "            COALESCE(SUM(o.discount_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_discount,\n"
    "            COALESCE(SUM(o.tax_amount)      FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_tax\n"
    "        FROM shifts s\n"
    "        JOIN branches b ON b.id = s.branch_id\n"
    "        JOIN users    u ON u.id = s.teller_id\n"
    "        LEFT JOIN orders o ON o.shift_id = s.id\n"
    "        WHERE s.id = $1\n"
    "        GROUP BY s.id, b.name, u.name"
)

NEW_SHIFT_SUMMARY_PAYMENTS = (
    "            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'cash'),           0)::bigint AS cash_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'card'),           0)::bigint AS card_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'digital_wallet'), 0)::bigint AS digital_wallet_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'mixed'),          0)::bigint AS mixed_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'talabat_online'), 0)::bigint AS talabat_online_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'talabat_cash'),   0)::bigint AS talabat_cash_revenue,\n"
    "            COALESCE(SUM(o.discount_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_discount,\n"
    "            COALESCE(SUM(o.tax_amount)      FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_tax\n"
    "        FROM shifts s\n"
    "        JOIN branches b ON b.id = s.branch_id\n"
    "        JOIN users    u ON u.id = s.teller_id\n"
    "        LEFT JOIN orders o          ON o.shift_id  = s.id\n"
    "        LEFT JOIN order_payments op ON op.order_id = o.id\n"
    "        WHERE s.id = $1\n"
    "        GROUP BY s.id, b.name, u.name"
)


# ══════════════════════════════════════════════════════════════════════════════
# 3.  org_branch_comparison
# ══════════════════════════════════════════════════════════════════════════════

OLD_ORG_COMPARISON = (
    "            COUNT(o.id) FILTER (WHERE o.status != 'voided')::bigint AS total_orders,\n"
    "            COUNT(o.id) FILTER (WHERE o.status = 'voided')::bigint  AS voided_orders,\n"
    "            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided'),                                            0)::bigint AS total_revenue,\n"
    "                        COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'cash'), 0)::bigint           AS cash_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'card'), 0)::bigint           AS card_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'digital_wallet'), 0)::bigint AS digital_wallet_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'mixed'), 0)::bigint          AS mixed_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'talabat_online'), 0)::bigint  AS talabat_online_revenue,\n"
    "            COALESCE((SELECT SUM(op.amount) FROM order_payments op JOIN orders oo ON oo.id = op.order_id WHERE oo.shift_id = s.id AND oo.status != 'voided' AND op.method = 'talabat_cash'), 0)::bigint   AS talabat_cash_revenue\n"
    "        FROM branches b\n"
    "        LEFT JOIN orders o ON o.branch_id = b.id\n"
    "          AND ($2::timestamptz IS NULL OR o.created_at >= $2)\n"
    "          AND ($3::timestamptz IS NULL OR o.created_at <= $3)\n"
    "        WHERE b.org_id = $1 AND b.deleted_at IS NULL\n"
    "        GROUP BY b.id, b.name\n"
    "        ORDER BY total_revenue DESC"
)

NEW_ORG_COMPARISON = (
    "            COUNT(DISTINCT o.id) FILTER (WHERE o.status != 'voided')::bigint AS total_orders,\n"
    "            COUNT(DISTINCT o.id) FILTER (WHERE o.status  = 'voided')::bigint AS voided_orders,\n"
    "            COALESCE(SUM(o.total_amount) FILTER (WHERE o.status != 'voided'), 0)::bigint AS total_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'cash'),           0)::bigint AS cash_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'card'),           0)::bigint AS card_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'digital_wallet'), 0)::bigint AS digital_wallet_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'mixed'),          0)::bigint AS mixed_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'talabat_online'), 0)::bigint AS talabat_online_revenue,\n"
    "            COALESCE(SUM(op.amount) FILTER (WHERE o.status != 'voided' AND op.method = 'talabat_cash'),   0)::bigint AS talabat_cash_revenue\n"
    "        FROM branches b\n"
    "        LEFT JOIN orders o          ON o.branch_id = b.id\n"
    "          AND ($2::timestamptz IS NULL OR o.created_at >= $2)\n"
    "          AND ($3::timestamptz IS NULL OR o.created_at <= $3)\n"
    "        LEFT JOIN order_payments op ON op.order_id  = o.id\n"
    "        WHERE b.org_id = $1 AND b.deleted_at IS NULL\n"
    "        GROUP BY b.id, b.name\n"
    "        ORDER BY total_revenue DESC"
)


# ══════════════════════════════════════════════════════════════════════════════
# main
# ══════════════════════════════════════════════════════════════════════════════

def main():
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("src/reports/handlers.rs")

    if not target.exists():
        print(f"ERROR: file not found: {target}")
        sys.exit(1)

    source = target.read_text(encoding="utf-8")
    backup = target.with_suffix(".rs.bak")
    backup.write_text(source, encoding="utf-8")
    print(f"Backup written to {backup}")

    print("\nApplying fixes...")

    # 1. timeseries – to_char table alias
    source = replace_block(source, OLD_TIMESERIES_TOCHAR, NEW_TIMESERIES_TOCHAR,
                           "branch_sales_timeseries → to_char alias")

    # 1. timeseries – payment columns + FROM clause
    source = replace_block(source, OLD_TIMESERIES, NEW_TIMESERIES,
                           "branch_sales_timeseries → payment columns + LEFT JOIN")

    # 2. shift_summary
    source = replace_block(source, OLD_SHIFT_SUMMARY_PAYMENTS, NEW_SHIFT_SUMMARY_PAYMENTS,
                           "shift_summary → payment columns + missing comma + LEFT JOIN")

    # 3. org_branch_comparison
    source = replace_block(source, OLD_ORG_COMPARISON, NEW_ORG_COMPARISON,
                           "org_branch_comparison → payment columns + DISTINCT + LEFT JOIN")

    target.write_text(source, encoding="utf-8")
    print(f"\nDone. Written to {target}")


if __name__ == "__main__":
    main()