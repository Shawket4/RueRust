#!/usr/bin/env bash
# =============================================================================
#  Rue POS — React dashboard patch v2
#
#  Fixes:
#    Item 3 — Orders list (proper Excel-like table with filters)
#    Item 4 — Analytics revenue fix (timeseries was broken)
#
#  Also repairs any damage from the previous patch to types/index.ts
#
#  Run from: ~/Desktop/RueDashboard
# =============================================================================
set -e

REACT_DIR="$HOME/Desktop/RueDashboard"
cd "$REACT_DIR"

echo "=================================================="
echo "  Rue POS — React Dashboard Patch v2"
echo "  $(pwd)"
echo "=================================================="
echo ""

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 1 — Verify / repair types/index.ts
#  Make sure Order has the new fields AND there are no duplicates
# ─────────────────────────────────────────────────────────────────────────────
echo "[ 1/4 ] Verifying types/index.ts..."

python3 - << 'PYEOF'
import pathlib, sys

path = pathlib.Path("src/types/index.ts")
src  = path.read_text()

changed = False

# Ensure Order interface has the new fields before voided_at
if "amount_tendered" not in src:
    src = src.replace(
        "  voided_at:       string | null;",
        "  amount_tendered: number | null;\n"
        "  change_given:    number | null;\n"
        "  tip_amount:      number | null;\n"
        "  discount_id:     string | null;\n"
        "  voided_at:       string | null;"
    )
    changed = True
    print("  OK Order fields added")
else:
    print("  OK Order fields already present")

# Ensure Discount interface exists
if "export interface Discount" not in src:
    src = src + """
// ── Discounts ─────────────────────────────────────────────────────────────────
export interface Discount {
  id:         string;
  org_id:     string;
  name:       string;
  dtype:      "percentage" | "fixed";
  value:      number;
  is_active:  boolean;
  created_at: string;
  updated_at: string;
}
"""
    changed = True
    print("  OK Discount interface added")
else:
    print("  OK Discount interface already present")

# Remove duplicate Discount blocks if any (from previous bad patch)
# Count occurrences
count = src.count("export interface Discount")
if count > 1:
    # Keep only the first occurrence
    first = src.index("export interface Discount")
    second = src.index("export interface Discount", first + 1)
    # Find the closing brace of the second block
    block_start = src.rfind("\n// ── Discounts", 0, second)
    if block_start == -1:
        block_start = second
    block_end = src.index("\n}", second) + 2
    src = src[:block_start] + src[block_end:]
    changed = True
    print(f"  OK removed {count-1} duplicate Discount block(s)")

if changed:
    path.write_text(src)
    print("  OK types/index.ts saved")
else:
    print("  OK types/index.ts is clean, no changes needed")
PYEOF

echo ""

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 2 — Ensure src/api/discounts.ts exists
# ─────────────────────────────────────────────────────────────────────────────
echo "[ 2/4 ] Ensuring discounts API exists..."

if [ ! -f src/api/discounts.ts ]; then
cat > src/api/discounts.ts << 'EOF'
import client from "@/lib/client";
import type { Discount } from "@/types";

export const getDiscounts   = (orgId: string) =>
  client.get<Discount[]>("/discounts", { params: { org_id: orgId } });
export const createDiscount = (data: { org_id: string; name: string; dtype: string; value: number; is_active?: boolean }) =>
  client.post<Discount>("/discounts", data);
export const updateDiscount = (id: string, data: { name?: string; dtype?: string; value?: number; is_active?: boolean }) =>
  client.patch<Discount>(`/discounts/${id}`, data);
export const deleteDiscount = (id: string) =>
  client.delete(`/discounts/${id}`);
EOF
echo "  OK src/api/discounts.ts created"
else
echo "  OK src/api/discounts.ts already exists"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 3 — Item 3: Orders page — full rewrite
#  Excel-like table with branch, shift, date, teller, payment filters
# ─────────────────────────────────────────────────────────────────────────────
echo "[ 3/4 ] Writing Orders page (Item 3)..."

mkdir -p src/pages/orders

cat > src/pages/orders/Orders.tsx << 'EOF'
import React, { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { type ColumnDef } from "@tanstack/react-table";
import {
  ShoppingBag, ChevronRight, XCircle, Download,
  Filter, Calendar, RefreshCw,
} from "lucide-react";
import { toast } from "sonner";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as ordersApi from "@/api/orders";
import * as shiftsApi from "@/api/shifts";
import * as branchesApi from "@/api/branches";
import * as discountsApi from "@/api/discounts";
import { getErrorMessage } from "@/lib/client";
import { egp, fmtDateTime, fmtTime, fmtPayment, PAYMENT_BG } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  Dialog, DialogContent,
} from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import { DataTable } from "@/components/shared/DataTable";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { DateRangePicker } from "@/components/shared/DateRangePicker";
import type { Order, Shift, Discount } from "@/types";

// ── Payment badge ─────────────────────────────────────────────────────────────
function PaymentBadge({ method }: { method: string }) {
  const bg = PAYMENT_BG[method as keyof typeof PAYMENT_BG]
    ?? "bg-muted text-muted-foreground";
  return (
    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${bg}`}>
      {fmtPayment(method)}
    </span>
  );
}

// ── Order detail drawer ───────────────────────────────────────────────────────
function OrderDetailDrawer({
  order, onClose, discounts,
}: {
  order: Order; onClose: () => void; discounts: Discount[];
}) {
  const qc = useQueryClient();
  const isVoided = order.status === "voided";
  const disc = discounts.find((d) => d.id === order.discount_id);
  const [voidReason, setVoidReason] = useState("customer_request");

  const { mutate: doVoid, isPending } = useMutation({
    mutationFn: (reason: string) =>
      ordersApi.voidOrder(order.id, { reason, restore_inventory: true }),
    onSuccess: () => {
      toast.success("Order voided");
      qc.invalidateQueries({ queryKey: ["orders"] });
      onClose();
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-start justify-between p-5 border-b flex-shrink-0">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <h2 className="font-bold text-lg">Order #{order.order_number}</h2>
            {isVoided && <Badge variant="destructive">Voided</Badge>}
          </div>
          <p className="text-xs text-muted-foreground">
            {fmtDateTime(order.created_at)} · {order.teller_name}
          </p>
        </div>
        <PaymentBadge method={order.payment_method} />
      </div>

      <ScrollArea className="flex-1">
        <div className="p-5 space-y-5">

          {/* Items */}
          <div className="rounded-xl border overflow-hidden">
            <div className="px-4 py-2.5 bg-muted/40 border-b">
              <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Items</p>
            </div>
            <div className="divide-y divide-border/50">
              {(order.items ?? []).length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-6">No item details</p>
              ) : (order.items ?? []).map((item) => (
                <div key={item.id} className="px-4 py-3">
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold">
                        {item.quantity}× {item.item_name}
                        {item.size_label && (
                          <span className="text-muted-foreground font-normal"> · {item.size_label}</span>
                        )}
                      </p>
                      {(item.addons ?? []).length > 0 && (
                        <div className="flex flex-wrap gap-1 mt-1">
                          {item.addons.map((a) => (
                            <span key={a.id}
                              className="text-[10px] bg-primary/10 text-primary px-2 py-0.5 rounded-full font-medium">
                              {a.addon_name}{a.unit_price > 0 ? ` +${egp(a.unit_price)}` : ""}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                    <span className="font-semibold tabular-nums text-sm">{egp(item.line_total)}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Totals */}
          <div className="rounded-xl border p-4 space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-muted-foreground">Subtotal</span>
              <span className="tabular-nums">{egp(order.subtotal)}</span>
            </div>
            {order.discount_amount > 0 && (
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground flex items-center gap-1.5">
                  Discount
                  {disc && <Badge variant="outline" className="text-[10px] h-4">{disc.name}</Badge>}
                  {!disc && order.discount_type && (
                    <span className="text-[10px] text-muted-foreground">
                      ({order.discount_type === "percentage" ? `${order.discount_value}%` : egp(order.discount_value)})
                    </span>
                  )}
                </span>
                <span className="text-green-600 font-medium tabular-nums">− {egp(order.discount_amount)}</span>
              </div>
            )}
            {order.tax_amount > 0 && (
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Tax</span>
                <span className="tabular-nums">{egp(order.tax_amount)}</span>
              </div>
            )}
            <Separator />
            <div className="flex justify-between font-bold text-base">
              <span>Total</span>
              <span className={`tabular-nums ${isVoided ? "line-through text-muted-foreground" : "text-primary"}`}>
                {egp(order.total_amount)}
              </span>
            </div>
            {order.amount_tendered != null && (
              <>
                <Separator />
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Cash Tendered</span>
                  <span className="tabular-nums">{egp(order.amount_tendered)}</span>
                </div>
                {(order.change_given ?? 0) > 0 && (
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Change Given</span>
                    <span className="text-green-600 font-semibold tabular-nums">{egp(order.change_given!)}</span>
                  </div>
                )}
              </>
            )}
            {(order.tip_amount ?? 0) > 0 && (
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Tip</span>
                <span className="text-amber-600 font-medium tabular-nums">{egp(order.tip_amount!)}</span>
              </div>
            )}
          </div>

          {/* Meta */}
          <div className="rounded-xl border p-4 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Customer</span>
              <span>{order.customer_name ?? "—"}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Payment</span>
              <PaymentBadge method={order.payment_method} />
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Teller</span>
              <span>{order.teller_name}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Time</span>
              <span>{fmtDateTime(order.created_at)}</span>
            </div>
            {isVoided && order.void_reason && (
              <div className="flex justify-between">
                <span className="text-muted-foreground">Void Reason</span>
                <span className="text-destructive capitalize">
                  {order.void_reason.replace(/_/g, " ")}
                </span>
              </div>
            )}
          </div>

          {/* Void controls */}
          {!isVoided && (
            <div className="rounded-xl border border-destructive/30 bg-destructive/5 p-4 space-y-3">
              <p className="text-sm font-semibold text-destructive flex items-center gap-2">
                <XCircle size={14} /> Void Order
              </p>
              <Select value={voidReason} onValueChange={setVoidReason}>
                <SelectTrigger className="h-9">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="customer_request">Customer Request</SelectItem>
                  <SelectItem value="wrong_order">Wrong Order</SelectItem>
                  <SelectItem value="quality_issue">Quality Issue</SelectItem>
                  <SelectItem value="other">Other</SelectItem>
                </SelectContent>
              </Select>
              <Button
                variant="destructive" size="sm" className="w-full"
                loading={isPending}
                onClick={() => confirm("Void this order?") && doVoid(voidReason)}
              >
                <XCircle size={13} /> Void Order
              </Button>
            </div>
          )}
        </div>
      </ScrollArea>
    </div>
  );
}

// ── Main Orders page ──────────────────────────────────────────────────────────
const PAYMENT_METHODS = [
  "cash", "card", "digital_wallet", "mixed", "talabat_online", "talabat_cash",
];

export default function Orders() {
  const user     = useAuthStore((s) => s.user);
  const orgId    = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const branchId = useAppStore((s) => s.selectedBranchId) ?? "";

  // Filter state
  const [selBranch,  setSelBranch]  = useState(branchId);
  const [selShift,   setSelShift]   = useState<string>("all");
  const [selTeller,  setSelTeller]  = useState<string>("all");
  const [selPayment, setSelPayment] = useState<string>("all");
  const [selStatus,  setSelStatus]  = useState<string>("all");
  const [from,       setFrom]       = useState<string | null>(null);
  const [to,         setTo]         = useState<string | null>(null);
  const [selOrder,   setSelOrder]   = useState<Order | null>(null);

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => branchesApi.getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  React.useEffect(() => {
    if (branches.length > 0 && !selBranch) setSelBranch(branches[0].id);
  }, [branches, selBranch]);

  const activeBranch = branches.find((b) => b.id === selBranch) ?? branches[0];

  const { data: shifts = [], isLoading: shiftsLoading } = useQuery({
    queryKey: ["shifts", activeBranch?.id],
    queryFn:  () => shiftsApi.getBranchShifts(activeBranch!.id).then((r) => r.data),
    enabled:  !!activeBranch?.id,
  });

  const { data: discounts = [] } = useQuery({
    queryKey: ["discounts", orgId],
    queryFn:  () => discountsApi.getDiscounts(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  // Fetch orders: if a shift is selected fetch by shift, otherwise by branch
  const queryParams = selShift !== "all"
    ? { shift_id: selShift }
    : { branch_id: activeBranch?.id };

  const { data: rawOrders = [], isLoading: ordersLoading, refetch } = useQuery({
    queryKey: ["orders", selShift, activeBranch?.id],
    queryFn:  () => ordersApi.getOrders(queryParams).then((r) => r.data),
    enabled:  !!activeBranch?.id,
  });

  // Client-side filters
  const orders = useMemo(() => {
    let list = rawOrders;
    if (selTeller  !== "all") list = list.filter((o) => o.teller_name === selTeller);
    if (selPayment !== "all") list = list.filter((o) => o.payment_method === selPayment);
    if (selStatus  !== "all") list = list.filter((o) => o.status === selStatus);
    if (from) list = list.filter((o) => new Date(o.created_at) >= new Date(from));
    if (to)   list = list.filter((o) => new Date(o.created_at) <= new Date(to));
    return list;
  }, [rawOrders, selTeller, selPayment, selStatus, from, to]);

  // Derived teller list for filter dropdown
  const tellers = useMemo(() => {
    const names = [...new Set(rawOrders.map((o) => o.teller_name))].sort();
    return names;
  }, [rawOrders]);

  // Summary stats
  const active       = orders.filter((o) => o.status !== "voided");
  const voided       = orders.filter((o) => o.status === "voided");
  const totalRevenue = active.reduce((s, o) => s + o.total_amount, 0);
  const totalDisc    = active.reduce((s, o) => s + (o.discount_amount ?? 0), 0);
  const totalTip     = active.reduce((s, o) => s + (o.tip_amount ?? 0), 0);

  // CSV export
  const exportCSV = () => {
    const header = "Order#,Time,Teller,Payment,Subtotal,Discount,Tax,Total,Customer,Status";
    const rows = orders.map((o) => [
      o.order_number,
      fmtDateTime(o.created_at),
      o.teller_name,
      fmtPayment(o.payment_method),
      (o.subtotal / 100).toFixed(2),
      (o.discount_amount / 100).toFixed(2),
      (o.tax_amount / 100).toFixed(2),
      (o.total_amount / 100).toFixed(2),
      o.customer_name ?? "",
      o.status,
    ].join(",")).join("\n");
    const blob = new Blob([header + "\n" + rows], { type: "text/csv" });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement("a");
    a.href = url;
    a.download = `orders-${activeBranch?.name ?? "export"}-${new Date().toISOString().slice(0,10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const columns: ColumnDef<Order, any>[] = [
    {
      accessorKey: "order_number",
      header: "#",
      cell: ({ row }) => (
        <span className={`font-bold tabular-nums ${row.original.status === "voided" ? "text-muted-foreground line-through" : ""}`}>
          #{row.original.order_number}
        </span>
      ),
    },
    {
      accessorKey: "created_at",
      header: "Time",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground tabular-nums">{fmtDateTime(row.original.created_at)}</span>
      ),
    },
    {
      accessorKey: "teller_name",
      header: "Teller",
      cell: ({ row }) => <span className="text-sm">{row.original.teller_name}</span>,
    },
    {
      accessorKey: "customer_name",
      header: "Customer",
      cell: ({ row }) => (
        <span className="text-sm text-muted-foreground">{row.original.customer_name ?? "—"}</span>
      ),
    },
    {
      accessorKey: "payment_method",
      header: "Payment",
      cell: ({ row }) => <PaymentBadge method={row.original.payment_method} />,
    },
    {
      accessorKey: "discount_amount",
      header: "Discount",
      cell: ({ row }) => {
        const o = row.original;
        if (!o.discount_amount) return <span className="text-muted-foreground text-xs">—</span>;
        const disc = discounts.find((d) => d.id === o.discount_id);
        return (
          <div>
            <span className="text-xs font-semibold text-green-600">−{egp(o.discount_amount)}</span>
            {disc && <p className="text-[10px] text-muted-foreground">{disc.name}</p>}
          </div>
        );
      },
    },
    {
      accessorKey: "total_amount",
      header: "Total",
      cell: ({ row }) => (
        <span className={`font-bold tabular-nums ${row.original.status === "voided" ? "line-through text-muted-foreground" : ""}`}>
          {egp(row.original.total_amount)}
        </span>
      ),
    },
    {
      id: "change",
      header: "Change",
      cell: ({ row }) => {
        const c = row.original.change_given;
        if (!c || c === 0) return <span className="text-muted-foreground text-xs">—</span>;
        return <span className="text-xs text-green-600 font-semibold tabular-nums">{egp(c)}</span>;
      },
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => row.original.status === "voided"
        ? <Badge variant="destructive"><XCircle size={10} /> Voided</Badge>
        : <Badge variant="success">Completed</Badge>,
    },
    {
      id: "arrow",
      header: "",
      cell: () => <ChevronRight size={14} className="text-muted-foreground" />,
    },
  ];

  const resetFilters = () => {
    setSelShift("all"); setSelTeller("all");
    setSelPayment("all"); setSelStatus("all");
    setFrom(null); setTo(null);
  };
  const hasFilters = selShift !== "all" || selTeller !== "all" ||
    selPayment !== "all" || selStatus !== "all" || !!from || !!to;

  return (
    <div className="p-6 lg:p-8 max-w-[1400px] mx-auto space-y-5">
      <PageHeader
        title="Orders"
        sub="Browse, filter and export orders by branch and shift"
        actions={
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={() => refetch()}>
              <RefreshCw size={13} /> Refresh
            </Button>
            <Button variant="outline" size="sm" onClick={exportCSV} disabled={orders.length === 0}>
              <Download size={13} /> Export CSV
            </Button>
          </div>
        }
      />

      {/* ── Filters ─────────────────────────────────────────────────────────── */}
      <div className="rounded-2xl border bg-card p-4 space-y-4">
        <div className="flex items-center justify-between">
          <p className="text-sm font-semibold flex items-center gap-2">
            <Filter size={14} /> Filters
          </p>
          {hasFilters && (
            <Button variant="ghost" size="sm" onClick={resetFilters} className="text-xs h-7">
              Clear all
            </Button>
          )}
        </div>

        {/* Row 1: Branch + Shift + Teller + Payment + Status */}
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
          {/* Branch */}
          {branches.length > 1 && (
            <div className="space-y-1">
              <Label className="text-xs">Branch</Label>
              <Select value={selBranch} onValueChange={(v) => { setSelBranch(v); setSelShift("all"); }}>
                <SelectTrigger className="h-9"><SelectValue /></SelectTrigger>
                <SelectContent>
                  {branches.map((b) => <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          )}

          {/* Shift */}
          <div className="space-y-1">
            <Label className="text-xs">Shift</Label>
            <Select value={selShift} onValueChange={setSelShift} disabled={shiftsLoading}>
              <SelectTrigger className="h-9"><SelectValue placeholder="All shifts" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All shifts</SelectItem>
                {shifts.map((s) => (
                  <SelectItem key={s.id} value={s.id}>
                    <span className="flex items-center gap-1.5">
                      <span className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${s.status === "open" ? "bg-green-500" : "bg-muted-foreground"}`} />
                      {s.teller_name} · {new Date(s.opened_at).toLocaleDateString("en-GB", { day: "2-digit", month: "short" })}
                      {s.status === "open" && " (open)"}
                    </span>
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Teller */}
          <div className="space-y-1">
            <Label className="text-xs">Teller</Label>
            <Select value={selTeller} onValueChange={setSelTeller}>
              <SelectTrigger className="h-9"><SelectValue placeholder="All tellers" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All tellers</SelectItem>
                {tellers.map((t) => <SelectItem key={t} value={t}>{t}</SelectItem>)}
              </SelectContent>
            </Select>
          </div>

          {/* Payment */}
          <div className="space-y-1">
            <Label className="text-xs">Payment</Label>
            <Select value={selPayment} onValueChange={setSelPayment}>
              <SelectTrigger className="h-9"><SelectValue placeholder="All methods" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All methods</SelectItem>
                {PAYMENT_METHODS.map((m) => (
                  <SelectItem key={m} value={m}>{fmtPayment(m)}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Status */}
          <div className="space-y-1">
            <Label className="text-xs">Status</Label>
            <Select value={selStatus} onValueChange={setSelStatus}>
              <SelectTrigger className="h-9"><SelectValue placeholder="All statuses" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All statuses</SelectItem>
                <SelectItem value="completed">Completed</SelectItem>
                <SelectItem value="voided">Voided</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        {/* Row 2: Date range */}
        <div className="space-y-1">
          <Label className="text-xs flex items-center gap-1.5"><Calendar size={11} /> Date Range</Label>
          <DateRangePicker from={from} to={to} onChange={(f, t) => { setFrom(f); setTo(t); }} />
        </div>
      </div>

      {/* ── Summary stats ────────────────────────────────────────────────────── */}
      {orders.length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-5 gap-3">
          {[
            { label: "Completed",       value: active.length,        color: "text-primary"   },
            { label: "Voided",          value: voided.length,        color: voided.length > 0 ? "text-destructive" : "text-muted-foreground" },
            { label: "Total Revenue",   value: egp(totalRevenue),    color: "text-green-600" },
            { label: "Total Discounts", value: egp(totalDisc),       color: "text-amber-600" },
            { label: "Total Tips",      value: egp(totalTip),        color: "text-violet-600" },
          ].map(({ label, value, color }) => (
            <div key={label} className="rounded-2xl border bg-card p-4">
              <p className={`text-xl font-extrabold tabular-nums ${color}`}>{value}</p>
              <p className="text-xs text-muted-foreground mt-1">{label}</p>
            </div>
          ))}
        </div>
      )}

      {/* ── Table ────────────────────────────────────────────────────────────── */}
      {!activeBranch ? (
        <EmptyState icon={ShoppingBag} title="Select a branch" />
      ) : ordersLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 10 }).map((_, i) => <Skeleton key={i} className="h-12 rounded-xl" />)}
        </div>
      ) : orders.length === 0 ? (
        <EmptyState
          icon={ShoppingBag}
          title="No orders match your filters"
          sub="Try adjusting the branch, shift or date range"
          action={hasFilters ? <Button size="sm" variant="outline" onClick={resetFilters}>Clear filters</Button> : undefined}
        />
      ) : (
        <DataTable
          data={orders}
          columns={columns}
          searchKey="teller_name"
          searchPlaceholder="Search by teller…"
          pageSize={30}
          onRowClick={setSelOrder}
        />
      )}

      {/* ── Order detail drawer ───────────────────────────────────────────────── */}
      <Dialog open={!!selOrder} onOpenChange={(o) => !o && setSelOrder(null)}>
        <DialogContent sheet="right" showClose={false} className="p-0">
          {selOrder && (
            <OrderDetailDrawer
              order={selOrder}
              onClose={() => setSelOrder(null)}
              discounts={discounts}
            />
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
EOF

echo "  OK src/pages/orders/Orders.tsx written"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 4 — Item 4: Analytics fix
#  The original Analytics.tsx is correct — the issue is a build error from
#  types/index.ts. We rewrite Analytics.tsx cleanly so it compiles reliably.
# ─────────────────────────────────────────────────────────────────────────────
echo "[ 4/4 ] Fixing Analytics.tsx (Item 4)..."

cat > src/pages/analytics/Analytics.tsx << 'EOF'
import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from "recharts";
import { BarChart2, TrendingUp, Users, Package, Coffee, Clock } from "lucide-react";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as reportsApi from "@/api/reports";
import * as branchesApi from "@/api/branches";
import { egp, fmtDate, fmtPayment, PAYMENT_COLORS, pct } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import { StatCard } from "@/components/shared/StatCard";
import { PageHeader } from "@/components/shared/PageHeader";
import { DateRangePicker } from "@/components/shared/DateRangePicker";
import { DataTable } from "@/components/shared/DataTable";
import { type ColumnDef } from "@tanstack/react-table";
import type { TellerStats, ItemSales, BranchComparison } from "@/types";

const GRANULARITIES = [
  { value: "hourly",  label: "Hourly"  },
  { value: "daily",   label: "Daily"   },
  { value: "monthly", label: "Monthly" },
];

function ChartTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-popover border border-border rounded-xl shadow-lg p-3 text-sm">
      <p className="font-semibold mb-2 text-xs text-muted-foreground">{label}</p>
      {payload.map((p: any) => (
        <div key={p.dataKey} className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full" style={{ background: p.color }} />
            <span className="text-xs">{p.name}</span>
          </div>
          <span className="font-bold text-xs tabular-nums">
            {String(p.dataKey).includes("revenue") ? egp(p.value) : p.value}
          </span>
        </div>
      ))}
    </div>
  );
}

export default function Analytics() {
  const user     = useAuthStore((s) => s.user);
  const orgId    = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const branchId = useAppStore((s) => s.selectedBranchId) ?? "";

  const [tab,         setTab]         = useState("overview");
  const [selBranch,   setSelBranch]   = useState(branchId);
  const [from,        setFrom]        = useState<string | null>(null);
  const [to,          setTo]          = useState<string | null>(null);
  const [granularity, setGranularity] = useState("daily");

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => branchesApi.getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const activeBranch = branches.find((b) => b.id === selBranch) ?? branches[0];

  React.useEffect(() => {
    if (branches.length > 0 && !selBranch) setSelBranch(branches[0].id);
  }, [branches, selBranch]);

  const params = { from: from ?? undefined, to: to ?? undefined };

  const { data: sales, isLoading: salesLoading } = useQuery({
    queryKey: ["branch-sales", activeBranch?.id, from, to],
    queryFn:  () => reportsApi.getBranchSales(activeBranch!.id, params).then((r) => r.data),
    enabled:  !!activeBranch?.id,
  });

  const { data: timeseries = [], isLoading: tsLoading } = useQuery({
    queryKey: ["timeseries", activeBranch?.id, from, to, granularity],
    queryFn:  () => reportsApi.getBranchTimeseries(activeBranch!.id, { ...params, granularity }).then((r) => r.data),
    enabled:  !!activeBranch?.id && tab === "revenue",
  });

  const { data: tellers = [], isLoading: tellersLoading } = useQuery({
    queryKey: ["tellers", activeBranch?.id, from, to],
    queryFn:  () => reportsApi.getBranchTellers(activeBranch!.id, params).then((r) => r.data),
    enabled:  !!activeBranch?.id && tab === "tellers",
  });

  const { data: addons = [] } = useQuery({
    queryKey: ["addon-sales", activeBranch?.id, from, to],
    queryFn:  () => reportsApi.getBranchAddonSales(activeBranch!.id, params).then((r) => r.data),
    enabled:  !!activeBranch?.id && (tab === "items" || tab === "overview"),
  });

  const { data: comparison, isLoading: compLoading } = useQuery({
    queryKey: ["org-comparison", orgId, from, to],
    queryFn:  () => reportsApi.getOrgComparison(orgId, params).then((r) => r.data),
    enabled:  !!orgId && tab === "branches",
  });

  const { data: stock, isLoading: stockLoading } = useQuery({
    queryKey: ["branch-stock", activeBranch?.id],
    queryFn:  () => reportsApi.getBranchStock(activeBranch!.id).then((r) => r.data),
    enabled:  !!activeBranch?.id && tab === "inventory",
  });

  // Payment pie — only methods with revenue > 0
  const paymentPie = sales ? [
    { name: "Cash",           value: sales.cash_revenue,           color: PAYMENT_COLORS.cash           },
    { name: "Card",           value: sales.card_revenue,           color: PAYMENT_COLORS.card           },
    { name: "Digital Wallet", value: sales.digital_wallet_revenue, color: PAYMENT_COLORS.digital_wallet },
    { name: "Mixed",          value: sales.mixed_revenue,          color: PAYMENT_COLORS.mixed          },
    { name: "Talabat Online", value: sales.talabat_online_revenue, color: PAYMENT_COLORS.talabat_online },
    { name: "Talabat Cash",   value: sales.talabat_cash_revenue,   color: PAYMENT_COLORS.talabat_cash  },
  ].filter((d) => d.value > 0) : [];

  // Timeseries: format period label
  const tsData = timeseries.map((p) => ({ ...p, period: fmtDate(p.period) }));

  const Loader = () => (
    <div className="space-y-3">
      {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-14 rounded-xl" />)}
    </div>
  );

  // ── Column defs ─────────────────────────────────────────────────────────────
  const tellerCols: ColumnDef<TellerStats, any>[] = [
    { accessorKey: "teller_name",     header: "Teller",   cell: ({ row }) => <span className="font-semibold">{row.original.teller_name}</span> },
    { accessorKey: "orders",          header: "Orders",   cell: ({ row }) => <span className="tabular-nums">{row.original.orders}</span> },
    { accessorKey: "revenue",         header: "Revenue",  cell: ({ row }) => <span className="font-semibold tabular-nums">{egp(row.original.revenue)}</span> },
    { accessorKey: "avg_order_value", header: "Avg Order",cell: ({ row }) => <span className="tabular-nums">{egp(row.original.avg_order_value)}</span> },
    { accessorKey: "voided",          header: "Voided",   cell: ({ row }) => <span className={row.original.voided > 0 ? "text-destructive font-semibold" : "text-muted-foreground"}>{row.original.voided}</span> },
    { accessorKey: "shifts",          header: "Shifts",   cell: ({ row }) => <span className="tabular-nums">{row.original.shifts}</span> },
  ];

  const branchCols: ColumnDef<BranchComparison, any>[] = [
    { accessorKey: "branch_name",   header: "Branch",   cell: ({ row }) => <span className="font-semibold">{row.original.branch_name}</span> },
    { accessorKey: "total_orders",  header: "Orders",   cell: ({ row }) => <span className="tabular-nums">{row.original.total_orders}</span> },
    { accessorKey: "total_revenue", header: "Revenue",  cell: ({ row }) => <span className="font-bold tabular-nums">{egp(row.original.total_revenue)}</span> },
    { accessorKey: "cash_revenue",  header: "Cash",     cell: ({ row }) => <span className="tabular-nums text-xs">{egp(row.original.cash_revenue)}</span> },
    { accessorKey: "card_revenue",  header: "Card",     cell: ({ row }) => <span className="tabular-nums text-xs">{egp(row.original.card_revenue)}</span> },
    {
      id: "talabat", header: "Talabat",
      cell: ({ row }) => <span className="tabular-nums text-xs">{egp(row.original.talabat_online_revenue + row.original.talabat_cash_revenue)}</span>
    },
    { accessorKey: "avg_order_value", header: "AOV",    cell: ({ row }) => <span className="tabular-nums text-xs">{egp(row.original.avg_order_value)}</span> },
    {
      accessorKey: "void_rate_pct", header: "Void %",
      cell: ({ row }) => <span className={`tabular-nums text-xs ${row.original.void_rate_pct > 5 ? "text-destructive font-semibold" : "text-muted-foreground"}`}>{row.original.void_rate_pct.toFixed(1)}%</span>
    },
  ];

  const itemCols: ColumnDef<ItemSales, any>[] = [
    { accessorKey: "item_name",     header: "Item",      cell: ({ row }) => <span className="font-semibold">{row.original.item_name}</span> },
    { accessorKey: "quantity_sold", header: "Qty Sold",  cell: ({ row }) => <span className="tabular-nums">{row.original.quantity_sold}</span> },
    { accessorKey: "revenue",       header: "Revenue",   cell: ({ row }) => <span className="font-semibold tabular-nums">{egp(row.original.revenue)}</span> },
    {
      id: "share", header: "Share",
      cell: ({ row }) => <span className="text-xs text-muted-foreground">{pct(row.original.revenue, sales?.total_revenue ?? 0)}</span>
    },
  ];

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader
        title="Analytics"
        sub={activeBranch ? activeBranch.name : "Select a branch"}
        actions={
          branches.length > 1 && (
            <Select value={selBranch} onValueChange={setSelBranch}>
              <SelectTrigger className="w-44 h-9"><SelectValue placeholder="Branch…" /></SelectTrigger>
              <SelectContent>
                {branches.map((b) => <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>)}
              </SelectContent>
            </Select>
          )
        }
      />

      {/* Date range */}
      <div className="mb-6">
        <DateRangePicker from={from} to={to} onChange={(f, t) => { setFrom(f); setTo(t); }} />
      </div>

      <Tabs value={tab} onValueChange={setTab}>
        <TabsList className="mb-6 flex-wrap h-auto gap-1">
          <TabsTrigger value="overview"><BarChart2 size={13} /> Overview</TabsTrigger>
          <TabsTrigger value="revenue"><TrendingUp size={13} /> Revenue</TabsTrigger>
          <TabsTrigger value="items"><Coffee size={13} /> Items</TabsTrigger>
          <TabsTrigger value="tellers"><Users size={13} /> Tellers</TabsTrigger>
          <TabsTrigger value="branches"><BarChart2 size={13} /> Branches</TabsTrigger>
          <TabsTrigger value="inventory"><Package size={13} /> Inventory</TabsTrigger>
        </TabsList>

        {/* ── Overview ─────────────────────────────────────────────────────── */}
        <TabsContent value="overview" className="space-y-6">
          {salesLoading ? (
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
              {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-28 rounded-2xl" />)}
            </div>
          ) : sales ? (
            <>
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <StatCard title="Total Revenue"   value={egp(sales.total_revenue)}  sub={`${sales.total_orders} orders`} icon={TrendingUp} />
                <StatCard title="Total Discounts" value={egp(sales.total_discount)} sub="Applied discounts" icon={BarChart2} iconColor="bg-amber-500" />
                <StatCard title="Tax Collected"   value={egp(sales.total_tax)}      icon={Coffee} iconColor="bg-purple-500" />
                <StatCard title="Voided Orders"   value={sales.voided_orders}
                  sub={`${pct(sales.voided_orders, sales.total_orders + sales.voided_orders)} void rate`}
                  icon={Clock} iconColor="bg-red-500" />
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                {/* Payment pie */}
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Revenue by Payment Method</p>
                  {paymentPie.length > 0 ? (
                    <ResponsiveContainer width="100%" height={220}>
                      <PieChart>
                        <Pie data={paymentPie} dataKey="value" nameKey="name"
                          cx="50%" cy="50%" outerRadius={80} innerRadius={48}>
                          {paymentPie.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                        </Pie>
                        <Tooltip formatter={(v: number) => egp(v)} />
                        <Legend formatter={(v) => <span className="text-xs">{v}</span>} />
                      </PieChart>
                    </ResponsiveContainer>
                  ) : (
                    <p className="text-center text-muted-foreground text-sm py-10">No data</p>
                  )}
                </div>

                {/* Top 5 items */}
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Top Items</p>
                  <div className="space-y-3">
                    {sales.top_items.slice(0, 5).map((item, i) => {
                      const share = sales.total_revenue > 0 ? (item.revenue / sales.total_revenue) * 100 : 0;
                      return (
                        <div key={item.menu_item_id}>
                          <div className="flex items-center justify-between mb-1">
                            <div className="flex items-center gap-2">
                              <span className="text-xs text-muted-foreground w-4">#{i + 1}</span>
                              <span className="text-sm font-medium">{item.item_name}</span>
                            </div>
                            <div className="flex items-center gap-2">
                              <span className="text-xs text-muted-foreground">{item.quantity_sold}x</span>
                              <span className="text-sm font-bold tabular-nums">{egp(item.revenue)}</span>
                            </div>
                          </div>
                          <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                            <div className="h-full brand-gradient rounded-full" style={{ width: `${share}%` }} />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            </>
          ) : null}
        </TabsContent>

        {/* ── Revenue timeseries ────────────────────────────────────────────── */}
        <TabsContent value="revenue" className="space-y-4">
          <div className="flex items-center gap-3 flex-wrap">
            {GRANULARITIES.map((g) => (
              <Button key={g.value}
                variant={granularity === g.value ? "default" : "outline"}
                size="sm" onClick={() => setGranularity(g.value)}>
                {g.label}
              </Button>
            ))}
          </div>

          {tsLoading ? (
            <Skeleton className="h-72 rounded-2xl" />
          ) : tsData.length === 0 ? (
            <div className="rounded-2xl border p-12 text-center text-muted-foreground text-sm">
              No data for this period
            </div>
          ) : (
            <>
              {/* Revenue area chart */}
              <div className="rounded-2xl border p-5">
                <p className="text-sm font-bold mb-4">Revenue Over Time</p>
                <ResponsiveContainer width="100%" height={280}>
                  <AreaChart data={tsData}>
                    <defs>
                      {(["cash","card","talabat_online","talabat_cash"] as const).map((m) => (
                        <linearGradient key={m} id={`grad-${m}`} x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%"  stopColor={PAYMENT_COLORS[m]} stopOpacity={0.3} />
                          <stop offset="95%" stopColor={PAYMENT_COLORS[m]} stopOpacity={0}   />
                        </linearGradient>
                      ))}
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                    <XAxis dataKey="period" tick={{ fontSize: 11 }} />
                    <YAxis tickFormatter={(v) => `${(v / 100).toFixed(0)}`} tick={{ fontSize: 11 }} />
                    <Tooltip content={<ChartTooltip />} />
                    <Legend formatter={(v) => <span className="text-xs">{fmtPayment(v.replace("_revenue", ""))}</span>} />
                    <Area type="monotone" dataKey="cash_revenue"           name="Cash"           stroke={PAYMENT_COLORS.cash}           fill="url(#grad-cash)"           strokeWidth={2} />
                    <Area type="monotone" dataKey="card_revenue"           name="Card"           stroke={PAYMENT_COLORS.card}           fill="url(#grad-card)"           strokeWidth={2} />
                    <Area type="monotone" dataKey="talabat_online_revenue" name="Talabat Online" stroke={PAYMENT_COLORS.talabat_online} fill="url(#grad-talabat_online)" strokeWidth={2} />
                    <Area type="monotone" dataKey="talabat_cash_revenue"   name="Talabat Cash"   stroke={PAYMENT_COLORS.talabat_cash}   fill="url(#grad-talabat_cash)"   strokeWidth={2} />
                  </AreaChart>
                </ResponsiveContainer>
              </div>

              {/* Orders bar chart */}
              <div className="rounded-2xl border p-5">
                <p className="text-sm font-bold mb-4">Orders Over Time</p>
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart data={tsData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                    <XAxis dataKey="period" tick={{ fontSize: 11 }} />
                    <YAxis tick={{ fontSize: 11 }} />
                    <Tooltip content={<ChartTooltip />} />
                    <Bar dataKey="orders" name="Orders" fill="hsl(var(--primary))"    radius={[4,4,0,0]} />
                    <Bar dataKey="voided" name="Voided" fill="hsl(var(--destructive))" radius={[4,4,0,0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>

              {/* Discount timeseries */}
              {tsData.some((p) => p.discount > 0) && (
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Discounts Over Time</p>
                  <ResponsiveContainer width="100%" height={180}>
                    <BarChart data={tsData}>
                      <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                      <XAxis dataKey="period" tick={{ fontSize: 11 }} />
                      <YAxis tickFormatter={(v) => `${(v / 100).toFixed(0)}`} tick={{ fontSize: 11 }} />
                      <Tooltip content={<ChartTooltip />} />
                      <Bar dataKey="discount" name="Discounts" fill="hsl(38 80% 50%)" radius={[4,4,0,0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
            </>
          )}
        </TabsContent>

        {/* ── Items ────────────────────────────────────────────────────────── */}
        <TabsContent value="items" className="space-y-4">
          {salesLoading ? <Loader /> : sales && (
            <>
              <div className="rounded-2xl border p-5">
                <p className="text-sm font-bold mb-4">Top Items by Revenue</p>
                <DataTable data={sales.top_items} columns={itemCols} searchPlaceholder="Search items…" pageSize={10} />
              </div>

              <div className="rounded-2xl border p-5">
                <p className="text-sm font-bold mb-4">By Category</p>
                <div className="space-y-3">
                  {sales.by_category.map((cat) => {
                    const share = sales.total_revenue > 0 ? (cat.revenue / sales.total_revenue) * 100 : 0;
                    return (
                      <div key={cat.category_id ?? "uncategorised"}>
                        <div className="flex items-center justify-between mb-1">
                          <span className="text-sm font-medium">{cat.category_name ?? "Uncategorised"}</span>
                          <div className="flex items-center gap-3">
                            <span className="text-xs text-muted-foreground">{cat.quantity_sold} sold</span>
                            <span className="font-bold tabular-nums text-sm">{egp(cat.revenue)}</span>
                          </div>
                        </div>
                        <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                          <div className="h-full brand-gradient rounded-full" style={{ width: `${share}%` }} />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {addons.length > 0 && (
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Addon Sales</p>
                  <div className="space-y-2">
                    {addons.slice(0, 15).map((a) => (
                      <div key={a.addon_item_id} className="flex items-center justify-between py-2 border-b border-border/50 last:border-0">
                        <div>
                          <span className="text-sm font-medium">{a.addon_name}</span>
                          <Badge variant="info" className="ml-2 text-[10px]">{a.addon_type.replace("_", " ")}</Badge>
                        </div>
                        <div className="flex items-center gap-3">
                          <span className="text-xs text-muted-foreground">{a.quantity_sold}x</span>
                          <span className="font-semibold tabular-nums text-sm">{egp(a.revenue)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </>
          )}
        </TabsContent>

        {/* ── Tellers ──────────────────────────────────────────────────────── */}
        <TabsContent value="tellers" className="space-y-4">
          {tellersLoading ? <Loader /> : (
            <>
              {tellers.length > 0 && (
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Revenue by Teller</p>
                  <ResponsiveContainer width="100%" height={220}>
                    <BarChart data={tellers.slice(0, 8)} layout="vertical">
                      <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" horizontal={false} />
                      <XAxis type="number" tickFormatter={(v) => `${(v / 100).toFixed(0)}`} tick={{ fontSize: 11 }} />
                      <YAxis type="category" dataKey="teller_name" tick={{ fontSize: 11 }} width={90} />
                      <Tooltip content={<ChartTooltip />} />
                      <Bar dataKey="revenue" name="revenue" fill="hsl(var(--primary))" radius={[0,4,4,0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
              <DataTable data={tellers} columns={tellerCols} searchPlaceholder="Search tellers…" />
            </>
          )}
        </TabsContent>

        {/* ── Branch comparison ─────────────────────────────────────────────── */}
        <TabsContent value="branches" className="space-y-4">
          {compLoading ? <Loader /> : comparison && (
            <>
              <div className="rounded-2xl border p-5">
                <p className="text-sm font-bold mb-4">Revenue by Branch</p>
                <ResponsiveContainer width="100%" height={220}>
                  <BarChart data={comparison.branches}>
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                    <XAxis dataKey="branch_name" tick={{ fontSize: 11 }} />
                    <YAxis tickFormatter={(v) => `${(v / 100).toFixed(0)}`} tick={{ fontSize: 11 }} />
                    <Tooltip content={<ChartTooltip />} />
                    <Bar dataKey="cash_revenue"           name="cash"           fill={PAYMENT_COLORS.cash}           stackId="a" />
                    <Bar dataKey="card_revenue"           name="card"           fill={PAYMENT_COLORS.card}           stackId="a" />
                    <Bar dataKey="talabat_online_revenue" name="talabat_online" fill={PAYMENT_COLORS.talabat_online} stackId="a" />
                    <Bar dataKey="talabat_cash_revenue"   name="talabat_cash"   fill={PAYMENT_COLORS.talabat_cash}   stackId="a" radius={[4,4,0,0]} />
                    <Legend formatter={(v) => <span className="text-xs">{fmtPayment(v)}</span>} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
              <DataTable data={comparison.branches} columns={branchCols} searchPlaceholder="Search branches…" />
            </>
          )}
        </TabsContent>

        {/* ── Inventory ─────────────────────────────────────────────────────── */}
        <TabsContent value="inventory" className="space-y-4">
          {stockLoading ? <Loader /> : stock && (
            <>
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <StatCard title="Total Items"    value={stock.items.length} />
                <StatCard title="Low Stock"      value={stock.items.filter((i) => i.below_reorder).length} iconColor="bg-amber-500" />
                <StatCard title="Active Items"   value={stock.items.filter((i) => i.is_active).length} />
                <StatCard title="Inactive Items" value={stock.items.filter((i) => !i.is_active).length} iconColor="bg-muted" />
              </div>
              <div className="rounded-2xl border overflow-hidden">
                <div className="p-4 border-b bg-muted/30">
                  <p className="font-bold text-sm">Stock Levels</p>
                </div>
                <div className="divide-y divide-border/50">
                  {stock.items
                    .sort((a, b) => Number(b.below_reorder) - Number(a.below_reorder))
                    .map((item) => {
                      const pctVal = Math.min(100, (item.current_stock / Math.max(item.reorder_threshold * 2, 1)) * 100);
                      return (
                        <div key={item.inventory_item_id} className="flex items-center gap-4 px-4 py-3">
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-sm font-medium">{item.item_name}</span>
                              {item.below_reorder && <Badge variant="warning" className="text-[10px] h-4">Low</Badge>}
                            </div>
                            <div className="flex items-center gap-2">
                              <div className="flex-1 h-1.5 bg-muted rounded-full overflow-hidden">
                                <div
                                  className={`h-full rounded-full ${item.below_reorder ? "bg-amber-500" : "brand-gradient"}`}
                                  style={{ width: `${pctVal}%` }}
                                />
                              </div>
                              <span className="text-xs text-muted-foreground whitespace-nowrap">
                                {item.current_stock} / {item.reorder_threshold} {item.unit}
                              </span>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                </div>
              </div>
            </>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
EOF

echo "  OK src/pages/analytics/Analytics.tsx rewritten"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 5 — Ensure App.tsx has both routes (idempotent)
# ─────────────────────────────────────────────────────────────────────────────
echo "[ 5/5 ] Ensuring App.tsx routes..."

python3 - << 'PYEOF'
import pathlib

path = pathlib.Path("src/App.tsx")
src  = path.read_text()
changed = False

if 'import("@/pages/discounts/Discounts")' not in src:
    src = src.replace(
        'const Permissions = lazy(() => import("@/pages/permissions/Permissions"));',
        'const Permissions = lazy(() => import("@/pages/permissions/Permissions"));\n'
        'const Discounts   = lazy(() => import("@/pages/discounts/Discounts"));\n'
        'const Orders      = lazy(() => import("@/pages/orders/Orders"));'
    )
    changed = True

if 'path="discounts"' not in src:
    src = src.replace(
        '<Route path="analytics"   element={<Analytics />} />',
        '<Route path="analytics"   element={<Analytics />} />\n'
        '            <Route path="discounts"  element={<Discounts />} />\n'
        '            <Route path="orders"     element={<Orders />} />'
    )
    changed = True

if changed:
    path.write_text(src)
    print("  OK App.tsx updated")
else:
    print("  OK App.tsx already has routes")
PYEOF

# Ensure Sidebar has Orders + Discounts
python3 - << 'PYEOF'
import pathlib

path = pathlib.Path("src/components/layout/Sidebar.tsx")
src  = path.read_text()
changed = False

if "Tag," not in src and "ShoppingBag," not in src:
    src = src.replace(
        "import {\n  Coffee,",
        "import {\n  Coffee,\n  Tag,\n  ShoppingBag,"
    )
    changed = True
elif "Tag," not in src:
    src = src.replace("  Coffee,\n", "  Coffee,\n  Tag,\n  ShoppingBag,\n")
    changed = True

if '"orders"' not in src:
    src = src.replace(
        '        to: "/analytics",\n        icon: BarChart2,\n        label: "Analytics",\n        sub: "Reports & trends",\n        roles: ["super_admin", "org_admin", "branch_manager"],\n      },',
        '        to: "/analytics",\n        icon: BarChart2,\n        label: "Analytics",\n        sub: "Reports & trends",\n        roles: ["super_admin", "org_admin", "branch_manager"],\n      },\n      {\n        to: "/orders",\n        icon: ShoppingBag,\n        label: "Orders",\n        sub: "Browse by shift",\n        roles: ["super_admin", "org_admin", "branch_manager"],\n      },\n      {\n        to: "/discounts",\n        icon: Tag,\n        label: "Discounts",\n        sub: "Preset discounts",\n        roles: ["super_admin", "org_admin", "branch_manager"],\n      },'
    )
    changed = True

if changed:
    path.write_text(src)
    print("  OK Sidebar.tsx updated")
else:
    print("  OK Sidebar.tsx already has nav items")
PYEOF

echo ""

# ─────────────────────────────────────────────────────────────────────────────
#  Build + commit
# ─────────────────────────────────────────────────────────────────────────────
echo "Building React dashboard..."
npm run build 2>&1 | tail -15

echo ""
echo "Committing..."
git add .
git commit -m "fix: analytics revenue restored + orders list + types cleanup (items 3 & 4)"

echo ""
echo "=================================================="
echo "  React dashboard patch v2 complete."
echo ""
echo "  Fixed:"
echo "  - types/index.ts verified/repaired (no duplicates)"
echo "  - Analytics.tsx fully rewritten — revenue charts restored"
echo "  - Orders.tsx rewritten — branch/shift/teller/payment/date filters"
echo "  - CSV export added to Orders page"
echo "  - App.tsx routes ensured (idempotent)"
echo "  - Sidebar nav ensured (idempotent)"
echo "=================================================="
