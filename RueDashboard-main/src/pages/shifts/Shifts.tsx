import React, { useState, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  Clock,
  Plus,
  Printer,
  X,
  ArrowDownLeft,
  ArrowUpRight,
  AlertCircle,
  DollarSign,
  FileText,
  CheckCircle,
  TrendingUp,
  Banknote,
  Timer,
  User,
  ChevronDown,
  Zap,
} from "lucide-react";
import { type ColumnDef } from "@tanstack/react-table";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as shiftsApi from "@/api/shifts";
import * as branchesApi from "@/api/branches";
import type { Shift, ShiftReport } from "@/types";
import {
  egp,
  fmtDateTime,
  fmtDuration,
  fmtPayment,
  PAYMENT_COLORS,
  SHIFT_STATUS_COLORS,
  SHIFT_STATUS_LABELS,
} from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { ScrollArea } from "@/components/ui/scroll-area";
import { DataTable } from "@/components/shared/DataTable";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";

// ── Helpers ───────────────────────────────────────────────────────────────────

function statusVariant(status: string): string {
  switch (status) {
    case "open":
      return "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-700";
    case "closed":
      return "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300 border border-slate-200 dark:border-slate-600";
    case "force_closed":
      return "bg-orange-100 text-orange-800 dark:bg-orange-900/40 dark:text-orange-300 border border-orange-200 dark:border-orange-700";
    default:
      return "bg-muted text-muted-foreground";
  }
}

function discrepancyColor(d: number) {
  if (d === 0) return "text-emerald-600";
  return d > 0 ? "text-amber-600" : "text-red-600";
}

// ── Print styles (injected into popup window) ─────────────────────────────────
const PRINT_STYLES = `
  @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;500;600;700;800&display=swap');
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Cairo', sans-serif;
    background: #fff;
    color: #111827;
    font-size: 12px;
    padding: 24px;
    max-width: 420px;
    margin: 0 auto;
  }
  .header { text-align: center; margin-bottom: 20px; padding-bottom: 16px; border-bottom: 2px solid #111827; }
  .header .brand { font-size: 22px; font-weight: 800; letter-spacing: -0.5px; }
  .header .sub { font-size: 10px; text-transform: uppercase; letter-spacing: 0.15em; color: #6B7280; margin-top: 2px; }
  .header .meta { font-size: 11px; color: #6B7280; margin-top: 8px; }
  .section { margin-bottom: 16px; }
  .section-title {
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: 0.15em;
    color: #9CA3AF;
    font-weight: 700;
    margin-bottom: 8px;
    padding-bottom: 4px;
    border-bottom: 1px solid #E5E7EB;
  }
  .row { display: flex; justify-content: space-between; align-items: center; padding: 4px 0; }
  .row .label { color: #6B7280; font-size: 11px; }
  .row .value { font-weight: 600; font-size: 12px; }
  .row.bold .label { color: #111827; font-weight: 700; }
  .row.bold .value { font-size: 14px; font-weight: 800; }
  .row.total { border-top: 2px solid #111827; margin-top: 6px; padding-top: 8px; }
  .row.total .value { font-size: 16px; font-weight: 800; }
  .payment-row { display: flex; justify-content: space-between; padding: 5px 0; border-bottom: 1px dashed #E5E7EB; }
  .payment-row:last-child { border-bottom: none; }
  .payment-method { font-weight: 600; font-size: 11px; }
  .payment-orders { font-size: 10px; color: #9CA3AF; margin-left: 4px; }
  .movement { display: flex; justify-content: space-between; padding: 4px 0; }
  .movement .note { font-size: 11px; font-weight: 500; }
  .movement .who { font-size: 10px; color: #9CA3AF; }
  .movement .amt { font-weight: 700; font-size: 12px; }
  .in { color: #16A34A; }
  .out { color: #DC2626; }
  .discrepancy-box {
    margin-top: 8px;
    padding: 8px 12px;
    border-radius: 6px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .discrepancy-box.over { background: #FEF3C7; color: #92400E; }
  .discrepancy-box.short { background: #FEE2E2; color: #991B1B; }
  .discrepancy-box.exact { background: #D1FAE5; color: #065F46; }
  .status-pill {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 9999px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .status-open { background: #D1FAE5; color: #065F46; }
  .status-closed { background: #F3F4F6; color: #374151; }
  .status-force { background: #FEF3C7; color: #92400E; }
  .footer {
    margin-top: 20px;
    padding-top: 12px;
    border-top: 1px dashed #E5E7EB;
    text-align: center;
    font-size: 10px;
    color: #9CA3AF;
  }
  .divider { border: none; border-top: 1px dashed #E5E7EB; margin: 12px 0; }
  @media print {
    body { padding: 0; }
    @page { margin: 15mm; size: A4; }
  }
`;

function buildPrintHTML(report: ShiftReport, branchName?: string): string {
  const {
    shift,
    payment_summary,
    cash_movements,
    cash_movements_in,
    cash_movements_out,
    cash_movements_net,
    total_payments,
    total_returns,
    net_payments,
  } = report;
  const discrepancy = shift.cash_discrepancy ?? 0;
  const statusClass =
    shift.status === "open"
      ? "status-open"
      : shift.status === "closed"
        ? "status-closed"
        : "status-force";
  const statusLabel =
    shift.status === "open"
      ? "Open"
      : shift.status === "closed"
        ? "Closed"
        : "Force Closed";
  const now = new Date().toLocaleString("en-EG", {
    dateStyle: "medium",
    timeStyle: "short",
  });

  // Expected cash calculation
  const cashSales =
    payment_summary.find((p) => p.payment_method === "cash")?.total ?? 0;
  const talabatCash =
    payment_summary.find((p) => p.payment_method === "talabat_cash")?.total ??
    0;
  const expectedCash =
    shift.closing_cash_system ??
    shift.opening_cash +
      cashSales +
      talabatCash +
      cash_movements_in -
      cash_movements_out;

  const discrepancyBoxClass =
    discrepancy === 0 ? "exact" : discrepancy > 0 ? "over" : "short";
  const discrepancyLabel =
    discrepancy === 0
      ? "✓ Exact Match"
      : discrepancy > 0
        ? `Over by ${egp(Math.abs(discrepancy))}`
        : `Short by ${egp(Math.abs(discrepancy))}`;

  const paymentRows = payment_summary
    .map(
      (p) =>
        `<div class="payment-row">
      <span class="payment-method">${fmtPayment(p.payment_method)} <span class="payment-orders">(${p.order_count} orders)</span></span>
      <span class="value">${egp(p.total)}</span>
    </div>`,
    )
    .join("");

  const movementRows = cash_movements
    .map(
      (m) =>
        `<div class="movement">
      <div>
        <div class="note">${m.note}</div>
        <div class="who">${m.moved_by_name} · ${new Date(m.created_at).toLocaleString("en-EG", { dateStyle: "short", timeStyle: "short" })}</div>
      </div>
      <div class="amt ${m.amount >= 0 ? "in" : "out"}">${m.amount >= 0 ? "+" : ""}${egp(m.amount)}</div>
    </div>`,
    )
    .join("");

  return `<!DOCTYPE html>
<html><head>
  <meta charset="UTF-8">
  <title>Shift Report — ${shift.teller_name}</title>
  <style>${PRINT_STYLES}</style>
</head><body>
  <div class="header">
    <div class="brand">${branchName ?? "The Rue"}</div>
    <div class="sub">Shift Report</div>
    <div class="meta">
      Teller: <strong>${shift.teller_name}</strong> &nbsp;·&nbsp;
      <span class="status-pill ${statusClass}">${statusLabel}</span>
    </div>
    <div class="meta">Printed: ${now}</div>
  </div>

  <div class="section">
    <div class="section-title">Shift Details</div>
    <div class="row"><span class="label">Opened</span><span class="value">${new Date(shift.opened_at).toLocaleString("en-EG", { dateStyle: "medium", timeStyle: "short" })}</span></div>
    ${shift.closed_at ? `<div class="row"><span class="label">Closed</span><span class="value">${new Date(shift.closed_at).toLocaleString("en-EG", { dateStyle: "medium", timeStyle: "short" })}</span></div>` : ""}
    <div class="row"><span class="label">Duration</span><span class="value">${fmtDuration(shift.opened_at, shift.closed_at ?? undefined)}</span></div>
    <div class="row"><span class="label">Opening Cash</span><span class="value">${egp(shift.opening_cash)}</span></div>
  </div>

  <hr class="divider" />

  <div class="section">
    <div class="section-title">Payment Breakdown</div>
    ${paymentRows || '<div class="row"><span class="label">No payments recorded</span></div>'}
    <div class="row bold total">
      <span class="label">Total Revenue</span>
      <span class="value">${egp(total_payments)}</span>
    </div>
    ${
      total_returns > 0
        ? `
    <div class="row"><span class="label" style="color:#DC2626">Voided Orders</span><span class="value" style="color:#DC2626">− ${egp(total_returns)}</span></div>
    <div class="row bold"><span class="label">Net Payments</span><span class="value">${egp(net_payments)}</span></div>`
        : ""
    }
  </div>

  <hr class="divider" />

  <div class="section">
    <div class="section-title">Cash Summary</div>
    <div class="row"><span class="label">Opening Cash</span><span class="value">${egp(shift.opening_cash)}</span></div>
    <div class="row"><span class="label">Cash Sales</span><span class="value">${egp(cashSales)}</span></div>
    ${talabatCash > 0 ? `<div class="row"><span class="label">Talabat Cash</span><span class="value">${egp(talabatCash)}</span></div>` : ""}
    ${cash_movements_in > 0 ? `<div class="row"><span class="label in">+ Movements In</span><span class="value in">${egp(cash_movements_in)}</span></div>` : ""}
    ${cash_movements_out > 0 ? `<div class="row"><span class="label out">− Movements Out</span><span class="value out">${egp(cash_movements_out)}</span></div>` : ""}
    <div class="row bold" style="border-top:1px solid #E5E7EB;margin-top:6px;padding-top:8px;">
      <span class="label">Expected Cash</span>
      <span class="value">${egp(expectedCash)}</span>
    </div>
    ${shift.closing_cash_declared != null ? `<div class="row bold"><span class="label">Declared Cash</span><span class="value">${egp(shift.closing_cash_declared)}</span></div>` : ""}
    ${
      shift.closing_cash_declared != null
        ? `
    <div class="discrepancy-box ${discrepancyBoxClass}">
      <span style="font-weight:700;font-size:12px;">${discrepancyLabel}</span>
    </div>`
        : ""
    }
  </div>

  ${
    cash_movements.length > 0
      ? `
  <hr class="divider" />
  <div class="section">
    <div class="section-title">Cash Movements</div>
    ${movementRows}
    <div class="row bold" style="border-top:1px solid #E5E7EB;margin-top:6px;padding-top:8px;">
      <span class="label">Net Movements</span>
      <span class="value ${cash_movements_net >= 0 ? "in" : "out"}">${cash_movements_net >= 0 ? "+" : ""}${egp(cash_movements_net)}</span>
    </div>
  </div>`
      : ""
  }

  <div class="footer">
    <div>This is an official shift report generated by Rue POS</div>
    <div style="margin-top:4px;">${new Date(report.printed_at).toLocaleString("en-EG", { dateStyle: "long", timeStyle: "medium" })}</div>
  </div>
</body></html>`;
}

// ── Shift Report Drawer ───────────────────────────────────────────────────────
function ShiftReportView({
  shiftId,
  onClose,
  branchName,
}: {
  shiftId: string;
  onClose: () => void;
  branchName?: string;
}) {
  const { data: report, isLoading } = useQuery({
    queryKey: ["shift-report", shiftId],
    queryFn: () => shiftsApi.getShiftReport(shiftId).then((r) => r.data),
  });

  const handlePrint = () => {
    if (!report) return;
    const html = buildPrintHTML(report, branchName);
    const w = window.open("", "_blank");
    if (!w) return;
    w.document.write(html);
    w.document.close();
    w.focus();
    setTimeout(() => {
      w.print();
      w.close();
    }, 600);
  };

  if (isLoading)
    return (
      <div className="p-6 space-y-3">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton key={i} className="h-8 rounded-xl" />
        ))}
      </div>
    );

  if (!report)
    return (
      <EmptyState icon={FileText} title="Report unavailable" className="h-64" />
    );

  const {
    shift,
    payment_summary,
    cash_movements,
    cash_movements_in,
    cash_movements_out,
    cash_movements_net,
    total_payments,
    total_returns,
    net_payments,
  } = report;
  const discrepancy = shift.cash_discrepancy ?? 0;

  const cashSales =
    payment_summary.find((p) => p.payment_method === "cash")?.total ?? 0;
  const talabatCash =
    payment_summary.find((p) => p.payment_method === "talabat_cash")?.total ??
    0;
  const expectedCash =
    shift.closing_cash_system ??
    shift.opening_cash +
      cashSales +
      talabatCash +
      cash_movements_in -
      cash_movements_out;

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between px-5 py-4 border-b flex-shrink-0 bg-card">
        <div>
          <h2 className="font-bold text-base">Shift Report</h2>
          <p className="text-xs text-muted-foreground mt-0.5">
            {shift.teller_name} · {fmtDateTime(shift.opened_at)}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={handlePrint}>
            <Printer size={13} /> Print
          </Button>
          <Button variant="ghost" size="icon-sm" onClick={onClose}>
            <X size={15} />
          </Button>
        </div>
      </div>

      <ScrollArea className="flex-1">
        <div className="p-4 space-y-4">
          {/* Status + duration hero */}
          <div className="rounded-2xl border bg-card p-4">
            <div className="flex items-center justify-between mb-3">
              <span
                className={`text-xs font-bold px-3 py-1 rounded-full ${statusVariant(shift.status)}`}
              >
                {SHIFT_STATUS_LABELS[shift.status] ?? shift.status}
              </span>
              <span className="text-xs text-muted-foreground font-mono">
                {fmtDuration(shift.opened_at, shift.closed_at ?? undefined)}
              </span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <p className="text-[10px] uppercase tracking-widest text-muted-foreground font-semibold">
                  Opened
                </p>
                <p className="text-sm font-semibold mt-0.5">
                  {fmtDateTime(shift.opened_at)}
                </p>
              </div>
              <div>
                <p className="text-[10px] uppercase tracking-widest text-muted-foreground font-semibold">
                  Closed
                </p>
                <p className="text-sm font-semibold mt-0.5">
                  {shift.closed_at ? (
                    fmtDateTime(shift.closed_at)
                  ) : (
                    <span className="text-emerald-600">Still open</span>
                  )}
                </p>
              </div>
            </div>
          </div>

          {/* Revenue summary */}
          <div className="grid grid-cols-2 gap-3">
            <div className="rounded-2xl border bg-card p-4">
              <p className="text-[10px] uppercase tracking-widest text-muted-foreground font-semibold">
                Total Revenue
              </p>
              <p className="text-xl font-extrabold tabular-nums text-primary mt-1">
                {egp(total_payments)}
              </p>
            </div>
            <div className="rounded-2xl border bg-card p-4">
              <p className="text-[10px] uppercase tracking-widest text-muted-foreground font-semibold">
                Opening Cash
              </p>
              <p className="text-xl font-extrabold tabular-nums mt-1">
                {egp(shift.opening_cash)}
              </p>
            </div>
            {total_returns > 0 && (
              <div className="rounded-2xl border bg-card p-4">
                <p className="text-[10px] uppercase tracking-widest text-muted-foreground font-semibold">
                  Voided
                </p>
                <p className="text-xl font-extrabold tabular-nums text-red-600 mt-1">
                  −{egp(total_returns)}
                </p>
              </div>
            )}
            {total_returns > 0 && (
              <div className="rounded-2xl border bg-card p-4">
                <p className="text-[10px] uppercase tracking-widest text-muted-foreground font-semibold">
                  Net Payments
                </p>
                <p className="text-xl font-extrabold tabular-nums text-emerald-600 mt-1">
                  {egp(net_payments)}
                </p>
              </div>
            )}
          </div>

          {/* Payment breakdown */}
          <div className="rounded-2xl border bg-card overflow-hidden">
            <div className="px-4 py-3 border-b bg-muted/30">
              <p className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground">
                Payment Breakdown
              </p>
            </div>
            <div className="divide-y divide-border/50">
              {payment_summary.length === 0 ? (
                <p className="text-sm text-muted-foreground text-center py-6">
                  No payments recorded
                </p>
              ) : (
                payment_summary.map((row) => {
                  const color = PAYMENT_COLORS[row.payment_method] ?? "#888";
                  const pct =
                    total_payments > 0 ? (row.total / total_payments) * 100 : 0;
                  return (
                    <div key={row.payment_method} className="px-4 py-3">
                      <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center gap-2">
                          <span
                            className="w-2.5 h-2.5 rounded-full flex-shrink-0"
                            style={{ background: color }}
                          />
                          <span className="text-sm font-semibold">
                            {fmtPayment(row.payment_method)}
                          </span>
                          <span className="text-[10px] text-muted-foreground bg-muted px-1.5 py-0.5 rounded-full">
                            {row.order_count}
                          </span>
                        </div>
                        <span className="font-bold tabular-nums text-sm">
                          {egp(row.total)}
                        </span>
                      </div>
                      <div className="flex items-center gap-2">
                        <div className="flex-1 h-1.5 bg-muted rounded-full overflow-hidden">
                          <div
                            className="h-full rounded-full"
                            style={{ width: `${pct}%`, background: color }}
                          />
                        </div>
                        <span className="text-[10px] text-muted-foreground w-8 text-right">
                          {pct.toFixed(0)}%
                        </span>
                      </div>
                    </div>
                  );
                })
              )}
              <div className="px-4 py-3 bg-muted/30 flex justify-between">
                <span className="font-bold text-sm">Total</span>
                <span className="font-bold tabular-nums text-sm">
                  {egp(total_payments)}
                </span>
              </div>
            </div>
          </div>

          {/* Cash summary */}
          <div className="rounded-2xl border bg-card overflow-hidden">
            <div className="px-4 py-3 border-b bg-muted/30">
              <p className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground">
                Cash Summary
              </p>
            </div>
            <div className="p-4 space-y-2.5">
              {[
                {
                  label: "Opening Cash",
                  value: egp(shift.opening_cash),
                  icon: Banknote,
                  cls: "",
                },
                {
                  label: "Cash Sales",
                  value: egp(cashSales),
                  icon: TrendingUp,
                  cls: "",
                },
                ...(talabatCash > 0
                  ? [
                      {
                        label: "Talabat Cash",
                        value: egp(talabatCash),
                        icon: TrendingUp,
                        cls: "",
                      },
                    ]
                  : []),
                ...(cash_movements_in > 0
                  ? [
                      {
                        label: "Movements In",
                        value: `+ ${egp(cash_movements_in)}`,
                        icon: ArrowDownLeft,
                        cls: "text-emerald-600",
                      },
                    ]
                  : []),
                ...(cash_movements_out > 0
                  ? [
                      {
                        label: "Movements Out",
                        value: `− ${egp(cash_movements_out)}`,
                        icon: ArrowUpRight,
                        cls: "text-red-500",
                      },
                    ]
                  : []),
              ].map(({ label, value, icon: Icon, cls }) => (
                <div key={label} className="flex items-center justify-between">
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Icon size={13} />
                    {label}
                  </div>
                  <span className={`font-semibold tabular-nums text-sm ${cls}`}>
                    {value}
                  </span>
                </div>
              ))}
              <Separator />
              <div className="flex items-center justify-between">
                <span className="font-bold text-sm">Expected Cash</span>
                <span className="font-extrabold tabular-nums text-sm">
                  {egp(expectedCash)}
                </span>
              </div>
              {shift.closing_cash_declared != null && (
                <div className="flex items-center justify-between">
                  <span className="font-bold text-sm">Declared Cash</span>
                  <span className="font-extrabold tabular-nums text-sm">
                    {egp(shift.closing_cash_declared)}
                  </span>
                </div>
              )}
              {shift.closing_cash_declared != null && (
                <div
                  className={`flex items-center justify-between rounded-xl px-3 py-2.5 mt-1 ${
                    discrepancy === 0
                      ? "bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800"
                      : discrepancy < 0
                        ? "bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800"
                        : "bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800"
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <AlertCircle
                      size={13}
                      className={discrepancyColor(discrepancy)}
                    />
                    <span
                      className={`font-bold text-sm ${discrepancyColor(discrepancy)}`}
                    >
                      {discrepancy === 0
                        ? "Exact Match ✓"
                        : discrepancy > 0
                          ? "Over"
                          : "Short"}
                    </span>
                  </div>
                  {discrepancy !== 0 && (
                    <span
                      className={`font-extrabold tabular-nums ${discrepancyColor(discrepancy)}`}
                    >
                      {discrepancy > 0 ? "+" : ""}
                      {egp(discrepancy)}
                    </span>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Cash movements */}
          {cash_movements.length > 0 && (
            <div className="rounded-2xl border bg-card overflow-hidden">
              <div className="px-4 py-3 border-b bg-muted/30">
                <p className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground">
                  Cash Movements
                </p>
              </div>
              <div className="divide-y divide-border/50">
                {cash_movements.map((m, i) => (
                  <div
                    key={i}
                    className="flex items-center justify-between px-4 py-3 gap-3"
                  >
                    <div
                      className={`w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0 ${m.amount >= 0 ? "bg-emerald-100 dark:bg-emerald-900/40" : "bg-red-100 dark:bg-red-900/40"}`}
                    >
                      {m.amount >= 0 ? (
                        <ArrowDownLeft size={13} className="text-emerald-600" />
                      ) : (
                        <ArrowUpRight size={13} className="text-red-500" />
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold truncate">{m.note}</p>
                      <p className="text-xs text-muted-foreground">
                        {m.moved_by_name} · {fmtDateTime(m.created_at)}
                      </p>
                    </div>
                    <span
                      className={`font-bold tabular-nums text-sm flex-shrink-0 ${m.amount >= 0 ? "text-emerald-600" : "text-red-500"}`}
                    >
                      {m.amount >= 0 ? "+" : ""}
                      {egp(m.amount)}
                    </span>
                  </div>
                ))}
                <div className="flex justify-between px-4 py-3 bg-muted/30">
                  <span className="font-bold text-sm">Net Movements</span>
                  <span
                    className={`font-bold tabular-nums text-sm ${cash_movements_net >= 0 ? "text-emerald-600" : "text-red-500"}`}
                  >
                    {cash_movements_net >= 0 ? "+" : ""}
                    {egp(cash_movements_net)}
                  </span>
                </div>
              </div>
            </div>
          )}

          {/* Notes */}
          {shift.notes && (
            <div className="rounded-2xl border bg-muted/30 px-4 py-3">
              <p className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground mb-1">
                Notes
              </p>
              <p className="text-sm">{shift.notes}</p>
            </div>
          )}

          {shift.force_close_reason && (
            <div className="rounded-2xl border border-orange-200 bg-orange-50 dark:bg-orange-950/20 px-4 py-3">
              <p className="text-[10px] font-bold uppercase tracking-widest text-orange-600 mb-1">
                Force Close Reason
              </p>
              <p className="text-sm text-orange-800 dark:text-orange-200">
                {shift.force_close_reason}
              </p>
            </div>
          )}

          <p className="text-center text-[10px] text-muted-foreground pb-2">
            Report generated {fmtDateTime(report.printed_at)}
          </p>
        </div>
      </ScrollArea>
    </div>
  );
}

// ── Shift row card (mobile) ───────────────────────────────────────────────────
function ShiftCard({
  shift,
  onReport,
  onCash,
  onClose,
}: {
  shift: Shift;
  onReport: () => void;
  onCash: () => void;
  onClose: () => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const isOpen = shift.status === "open";

  return (
    <div
      className={`rounded-2xl border bg-card overflow-hidden transition-all ${isOpen ? "border-emerald-200 dark:border-emerald-800 shadow-sm shadow-emerald-100 dark:shadow-none" : ""}`}
    >
      {/* Main row */}
      <div
        className="flex items-center gap-3 px-4 py-3 cursor-pointer"
        onClick={() => setExpanded((v) => !v)}
      >
        {/* Status dot */}
        <div
          className={`w-2.5 h-2.5 rounded-full flex-shrink-0 ${isOpen ? "bg-emerald-500 animate-pulse" : shift.status === "force_closed" ? "bg-orange-400" : "bg-slate-400"}`}
        />

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="font-bold text-sm">{shift.teller_name}</span>
            <span
              className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${statusVariant(shift.status)}`}
            >
              {SHIFT_STATUS_LABELS[shift.status] ?? shift.status}
            </span>
          </div>
          <p className="text-xs text-muted-foreground mt-0.5 truncate">
            {fmtDateTime(shift.opened_at)} ·{" "}
            {fmtDuration(shift.opened_at, shift.closed_at ?? undefined)}
          </p>
        </div>

        <div className="text-right flex-shrink-0">
          <p className="text-sm font-extrabold tabular-nums">
            {egp(shift.opening_cash)}
          </p>
          <p className="text-[10px] text-muted-foreground">opening</p>
        </div>

        <ChevronDown
          size={14}
          className={`text-muted-foreground transition-transform flex-shrink-0 ${expanded ? "rotate-180" : ""}`}
        />
      </div>

      {/* Expanded details */}
      {expanded && (
        <div className="border-t bg-muted/20 px-4 py-3 space-y-3">
          <div className="grid grid-cols-2 gap-3 text-sm">
            {shift.closing_cash_declared != null && (
              <div>
                <p className="text-[10px] text-muted-foreground uppercase tracking-wide font-semibold">
                  Declared
                </p>
                <p className="font-bold tabular-nums">
                  {egp(shift.closing_cash_declared)}
                </p>
              </div>
            )}
            {shift.closing_cash_system != null && (
              <div>
                <p className="text-[10px] text-muted-foreground uppercase tracking-wide font-semibold">
                  Expected
                </p>
                <p className="font-bold tabular-nums">
                  {egp(shift.closing_cash_system)}
                </p>
              </div>
            )}
            {shift.cash_discrepancy != null && shift.cash_discrepancy !== 0 && (
              <div>
                <p className="text-[10px] text-muted-foreground uppercase tracking-wide font-semibold">
                  Discrepancy
                </p>
                <p
                  className={`font-bold tabular-nums ${discrepancyColor(shift.cash_discrepancy)}`}
                >
                  {shift.cash_discrepancy > 0 ? "+" : ""}
                  {egp(shift.cash_discrepancy)}
                </p>
              </div>
            )}
            {shift.closed_at && (
              <div>
                <p className="text-[10px] text-muted-foreground uppercase tracking-wide font-semibold">
                  Closed At
                </p>
                <p className="font-semibold">{fmtDateTime(shift.closed_at)}</p>
              </div>
            )}
          </div>

          <div className="flex items-center gap-2 flex-wrap pt-1">
            <Button
              size="sm"
              variant="outline"
              className="h-8 text-xs"
              onClick={onReport}
            >
              <FileText size={12} /> Report
            </Button>
            {isOpen && (
              <>
                <Button
                  size="sm"
                  variant="outline"
                  className="h-8 text-xs"
                  onClick={onCash}
                >
                  <DollarSign size={12} /> Cash
                </Button>
                <Button size="sm" className="h-8 text-xs" onClick={onClose}>
                  <CheckCircle size={12} /> Close
                </Button>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────
export default function Shifts() {
  const user = useAuthStore((s) => s.user);
  const orgId = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const branchId = useAppStore((s) => s.selectedBranchId) ?? "";
  const qc = useQueryClient();

  const [selBranch, setSelBranch] = useState(branchId);
  const [reportShiftId, setReportShiftId] = useState<string | null>(null);

  const [openDialog, setOpenDialog] = useState(false);
  const [closeDialog, setCloseDialog] = useState(false);
  const [cashDialog, setCashDialog] = useState(false);
  const [forceDialog, setForceDialog] = useState(false);
  const [selShift, setSelShift] = useState<Shift | null>(null);

  const [openForm, setOpenForm] = useState({ opening_cash: "" });
  const [closeForm, setCloseForm] = useState({
    closing_cash_declared: "",
    notes: "",
  });
  const [cashForm, setCashForm] = useState({
    amount: "",
    note: "",
    direction: "in",
  });
  const [forceForm, setForceForm] = useState({ reason: "" });

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn: () => branchesApi.getBranches(orgId).then((r) => r.data),
    enabled: !!orgId,
  });

  React.useEffect(() => {
    if (branches.length > 0 && !selBranch) setSelBranch(branches[0].id);
  }, [branches, selBranch]);

  const activeBranch = branches.find((b) => b.id === selBranch) ?? branches[0];

  const { data: preFill } = useQuery({
    queryKey: ["shift-prefill", activeBranch?.id],
    queryFn: () =>
      shiftsApi.getCurrentShift(activeBranch!.id).then((r) => r.data),
    enabled: !!activeBranch?.id,
  });

  const { data: shifts = [], isLoading } = useQuery({
    queryKey: ["shifts", activeBranch?.id],
    queryFn: () =>
      shiftsApi.getBranchShifts(activeBranch!.id).then((r) => r.data),
    enabled: !!activeBranch?.id,
  });

  const openMutation = useMutation({
    mutationFn: () =>
      shiftsApi.openShift(activeBranch!.id, {
        opening_cash: Math.round(parseFloat(openForm.opening_cash) * 100),
      }),
    onSuccess: () => {
      toast.success("Shift opened");
      qc.invalidateQueries({ queryKey: ["shifts"] });
      qc.invalidateQueries({ queryKey: ["shift-prefill"] });
      setOpenDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const closeMutation = useMutation({
    mutationFn: () =>
      shiftsApi.closeShift(selShift!.id, {
        closing_cash_declared: Math.round(
          parseFloat(closeForm.closing_cash_declared) * 100,
        ),
        notes: closeForm.notes || null,
      }),
    onSuccess: () => {
      toast.success("Shift closed");
      qc.invalidateQueries({ queryKey: ["shifts"] });
      qc.invalidateQueries({ queryKey: ["shift-prefill"] });
      setCloseDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const cashMutation = useMutation({
    mutationFn: () => {
      const raw = parseFloat(cashForm.amount) * 100;
      const signed =
        cashForm.direction === "out" ? -Math.abs(raw) : Math.abs(raw);
      return shiftsApi.addCashMovement(selShift!.id, {
        amount: signed,
        note: cashForm.note,
      });
    },
    onSuccess: () => {
      toast.success("Cash movement recorded");
      qc.invalidateQueries({ queryKey: ["shifts"] });
      setCashDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const forceMutation = useMutation({
    mutationFn: () =>
      shiftsApi.forceCloseShift(selShift!.id, { reason: forceForm.reason }),
    onSuccess: () => {
      toast.success("Shift force closed");
      qc.invalidateQueries({ queryKey: ["shifts"] });
      qc.invalidateQueries({ queryKey: ["shift-prefill"] });
      setForceDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const openShift = preFill?.open_shift;
  const hasOpen = preFill?.has_open_shift;
  const suggested = preFill?.suggested_opening_cash ?? 0;

  // Desktop table columns
  const columns: ColumnDef<Shift, any>[] = [
    {
      accessorKey: "teller_name",
      header: "Teller",
      cell: ({ row }) => (
        <div className="flex items-center gap-2">
          <div
            className={`w-2 h-2 rounded-full flex-shrink-0 ${row.original.status === "open" ? "bg-emerald-500 animate-pulse" : "bg-slate-300"}`}
          />
          <span className="font-semibold text-sm">
            {row.original.teller_name}
          </span>
        </div>
      ),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => (
        <span
          className={`text-[11px] font-bold px-2.5 py-1 rounded-full ${statusVariant(row.original.status)}`}
        >
          {SHIFT_STATUS_LABELS[row.original.status] ?? row.original.status}
        </span>
      ),
    },
    {
      accessorKey: "opened_at",
      header: "Opened",
      cell: ({ row }) => (
        <span className="text-xs tabular-nums">
          {fmtDateTime(row.original.opened_at)}
        </span>
      ),
    },
    {
      accessorKey: "closed_at",
      header: "Closed",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground tabular-nums">
          {row.original.closed_at ? fmtDateTime(row.original.closed_at) : "—"}
        </span>
      ),
    },
    {
      id: "duration",
      header: "Duration",
      cell: ({ row }) => (
        <span className="text-xs font-mono tabular-nums">
          {fmtDuration(
            row.original.opened_at,
            row.original.closed_at ?? undefined,
          )}
        </span>
      ),
    },
    {
      accessorKey: "opening_cash",
      header: "Opening",
      cell: ({ row }) => (
        <span className="text-sm font-semibold tabular-nums">
          {egp(row.original.opening_cash)}
        </span>
      ),
    },
    {
      accessorKey: "closing_cash_declared",
      header: "Declared",
      cell: ({ row }) => {
        const v = row.original.closing_cash_declared;
        return v != null ? (
          <span className="text-sm font-semibold tabular-nums">{egp(v)}</span>
        ) : (
          <span className="text-muted-foreground text-xs">—</span>
        );
      },
    },
    {
      accessorKey: "cash_discrepancy",
      header: "Discrepancy",
      cell: ({ row }) => {
        const d = row.original.cash_discrepancy;
        if (d == null)
          return <span className="text-muted-foreground text-xs">—</span>;
        if (d === 0)
          return (
            <span className="text-xs font-semibold text-emerald-600">
              Exact ✓
            </span>
          );
        return (
          <span
            className={`text-sm font-bold tabular-nums ${discrepancyColor(d)}`}
          >
            {d > 0 ? "+" : ""}
            {egp(d)}
          </span>
        );
      },
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <div
          className="flex items-center gap-1 justify-end"
          onClick={(e) => e.stopPropagation()}
        >
          <Button
            variant="ghost"
            size="sm"
            className="h-7 text-xs"
            onClick={() => setReportShiftId(row.original.id)}
          >
            <FileText size={12} /> Report
          </Button>
          {row.original.status === "open" && (
            <>
              <Button
                variant="ghost"
                size="sm"
                className="h-7 text-xs"
                onClick={() => {
                  setSelShift(row.original);
                  setCashDialog(true);
                }}
              >
                <DollarSign size={12} /> Cash
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className="h-7 text-xs"
                onClick={() => {
                  setSelShift(row.original);
                  setCloseDialog(true);
                }}
              >
                <CheckCircle size={12} /> Close
              </Button>
            </>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader
        title="Shifts"
        sub={
          activeBranch
            ? `${activeBranch.name} · ${shifts.length} shifts`
            : "Select a branch"
        }
        actions={
          <div className="flex items-center gap-2">
            {branches.length > 1 && (
              <Select value={selBranch} onValueChange={setSelBranch}>
                <SelectTrigger className="w-40 h-9">
                  <SelectValue placeholder="Branch…" />
                </SelectTrigger>
                <SelectContent>
                  {branches.map((b) => (
                    <SelectItem key={b.id} value={b.id}>
                      {b.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
            {hasOpen && openShift ? (
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  setSelShift(openShift);
                  setForceDialog(true);
                }}
              >
                <Zap size={13} /> Force Close
              </Button>
            ) : (
              <Button
                size="sm"
                onClick={() => {
                  setOpenForm({ opening_cash: String(suggested / 100) });
                  setOpenDialog(true);
                }}
              >
                <Plus size={13} /> Open Shift
              </Button>
            )}
          </div>
        }
      />

      {/* Open shift banner */}
      {hasOpen && openShift && (
        <div className="mb-5 flex flex-col sm:flex-row sm:items-center gap-3 bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800 rounded-2xl px-4 py-3.5">
          <div className="flex items-center gap-3 flex-1 min-w-0">
            <div className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse flex-shrink-0" />
            <div className="min-w-0">
              <p className="text-sm font-bold text-emerald-800 dark:text-emerald-200">
                Shift is open
              </p>
              <p className="text-xs text-emerald-700 dark:text-emerald-300 truncate">
                {openShift.teller_name} · {fmtDateTime(openShift.opened_at)} ·{" "}
                {fmtDuration(openShift.opened_at)}
              </p>
            </div>
          </div>
          <div className="flex gap-2 flex-shrink-0">
            <Button
              size="sm"
              variant="outline"
              className="h-8 text-xs border-emerald-300 text-emerald-800 hover:bg-emerald-100 dark:text-emerald-200"
              onClick={() => setReportShiftId(openShift.id)}
            >
              <FileText size={12} /> Report
            </Button>
            <Button
              size="sm"
              variant="outline"
              className="h-8 text-xs border-emerald-300 text-emerald-800 hover:bg-emerald-100 dark:text-emerald-200"
              onClick={() => {
                setSelShift(openShift);
                setCashDialog(true);
              }}
            >
              <DollarSign size={12} /> Cash
            </Button>
            <Button
              size="sm"
              className="h-8 text-xs bg-emerald-600 hover:bg-emerald-700 text-white"
              onClick={() => {
                setSelShift(openShift);
                setCloseDialog(true);
              }}
            >
              <CheckCircle size={12} /> Close
            </Button>
          </div>
        </div>
      )}

      {/* Content */}
      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-16 rounded-2xl" />
          ))}
        </div>
      ) : shifts.length === 0 ? (
        <EmptyState
          icon={Clock}
          title="No shifts yet"
          sub="Open a shift to start taking orders"
        />
      ) : (
        <>
          {/* Mobile: cards */}
          <div className="flex flex-col gap-3 sm:hidden">
            {shifts.map((s) => (
              <ShiftCard
                key={s.id}
                shift={s}
                onReport={() => setReportShiftId(s.id)}
                onCash={() => {
                  setSelShift(s);
                  setCashDialog(true);
                }}
                onClose={() => {
                  setSelShift(s);
                  setCloseDialog(true);
                }}
              />
            ))}
          </div>

          {/* Desktop: table */}
          <div className="hidden sm:block">
            <DataTable
              data={shifts}
              columns={columns}
              searchPlaceholder="Search shifts…"
              pageSize={15}
            />
          </div>
        </>
      )}

      {/* ── Open shift dialog ── */}
      <Dialog open={openDialog} onOpenChange={setOpenDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Open New Shift</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            {suggested > 0 && (
              <div className="bg-primary/5 border border-primary/20 rounded-xl px-4 py-3 text-sm">
                Suggested opening cash: <strong>{egp(suggested)}</strong>
              </div>
            )}
            <div className="space-y-1.5">
              <Label>Opening Cash (EGP)</Label>
              <Input
                type="number"
                step="0.5"
                value={openForm.opening_cash}
                onChange={(e) => setOpenForm({ opening_cash: e.target.value })}
                placeholder="0.00"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpenDialog(false)}>
              Cancel
            </Button>
            <Button
              loading={openMutation.isPending}
              onClick={() => openMutation.mutate()}
            >
              Open Shift
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Close shift dialog ── */}
      <Dialog open={closeDialog} onOpenChange={setCloseDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Close Shift</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Declared Closing Cash (EGP)</Label>
              <Input
                type="number"
                step="0.5"
                value={closeForm.closing_cash_declared}
                onChange={(e) =>
                  setCloseForm((f) => ({
                    ...f,
                    closing_cash_declared: e.target.value,
                  }))
                }
                placeholder="0.00"
              />
            </div>
            <div className="space-y-1.5">
              <Label>Notes (optional)</Label>
              <Input
                value={closeForm.notes}
                onChange={(e) =>
                  setCloseForm((f) => ({ ...f, notes: e.target.value }))
                }
                placeholder="Any notes…"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCloseDialog(false)}>
              Cancel
            </Button>
            <Button
              loading={closeMutation.isPending}
              onClick={() => closeMutation.mutate()}
            >
              Close Shift
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Cash movement dialog ── */}
      <Dialog open={cashDialog} onOpenChange={setCashDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Cash Movement</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Direction</Label>
              <Select
                value={cashForm.direction}
                onValueChange={(v) =>
                  setCashForm((f) => ({ ...f, direction: v }))
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="in">Cash In — add to drawer</SelectItem>
                  <SelectItem value="out">
                    Cash Out — remove from drawer
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Amount (EGP)</Label>
              <Input
                type="number"
                step="0.5"
                value={cashForm.amount}
                onChange={(e) =>
                  setCashForm((f) => ({ ...f, amount: e.target.value }))
                }
                placeholder="0.00"
              />
            </div>
            <div className="space-y-1.5">
              <Label>Note</Label>
              <Input
                value={cashForm.note}
                onChange={(e) =>
                  setCashForm((f) => ({ ...f, note: e.target.value }))
                }
                placeholder="Reason for movement"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCashDialog(false)}>
              Cancel
            </Button>
            <Button
              loading={cashMutation.isPending}
              onClick={() => cashMutation.mutate()}
            >
              Record
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Force close dialog ── */}
      <Dialog open={forceDialog} onOpenChange={setForceDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Force Close Shift</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="bg-orange-50 dark:bg-orange-950/30 border border-orange-200 rounded-xl px-4 py-3 text-sm text-orange-800 dark:text-orange-200">
              Force closing ends the shift without a proper cash count. Use only
              when necessary.
            </div>
            <div className="space-y-1.5">
              <Label>Reason</Label>
              <Input
                value={forceForm.reason}
                onChange={(e) => setForceForm({ reason: e.target.value })}
                placeholder="Required reason…"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setForceDialog(false)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              loading={forceMutation.isPending}
              onClick={() => forceMutation.mutate()}
            >
              Force Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Shift report drawer ── */}
      <Dialog
        open={!!reportShiftId}
        onOpenChange={(o) => !o && setReportShiftId(null)}
      >
        <DialogContent sheet="right" showClose={false} className="p-0">
          {reportShiftId && (
            <ShiftReportView
              shiftId={reportShiftId}
              onClose={() => setReportShiftId(null)}
              branchName={activeBranch?.name}
            />
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
