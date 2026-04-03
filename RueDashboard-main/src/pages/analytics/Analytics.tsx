import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import {
  BarChart2,
  TrendingUp,
  Users,
  Package,
  Coffee,
  Clock,
} from "lucide-react";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as reportsApi from "@/api/reports";
import * as branchesApi from "@/api/branches";
import {
  egp,
  fmtDate,
  fmtPayment,
  formatPeriod,
  PAYMENT_COLORS,
  pct,
} from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import { StatCard } from "@/components/shared/StatCard";
import { PageHeader } from "@/components/shared/PageHeader";
import { DateRangePicker } from "@/components/shared/DateRangePicker";
import { DataTable } from "@/components/shared/DataTable";
import { type ColumnDef } from "@tanstack/react-table";
import type { TellerStats, ItemSales, BranchComparison } from "@/types";

const GRANULARITIES = [
  { value: "hourly", label: "Hourly" },
  { value: "daily", label: "Daily" },
  { value: "monthly", label: "Monthly" },
];

function ChartTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-popover border border-border rounded-xl shadow-lg p-3 text-sm">
      <p className="font-semibold mb-2 text-xs text-muted-foreground">
        {label}
      </p>
      {payload.map((p: any) => (
        <div
          key={p.dataKey}
          className="flex items-center justify-between gap-4"
        >
          <div className="flex items-center gap-1.5">
            <span
              className="w-2 h-2 rounded-full"
              style={{ background: p.color }}
            />
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
  const user = useAuthStore((s) => s.user);
  const orgId = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const branchId = useAppStore((s) => s.selectedBranchId) ?? "";

  const [tab, setTab] = useState("overview");
  const [selBranch, setSelBranch] = useState(branchId);
  const [from, setFrom] = useState<string | null>(null);
  const [to, setTo] = useState<string | null>(null);
  const [granularity, setGranularity] = useState("daily");

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn: () => branchesApi.getBranches(orgId).then((r) => r.data),
    enabled: !!orgId,
  });

  const activeBranch = branches.find((b) => b.id === selBranch) ?? branches[0];

  React.useEffect(() => {
    if (branches.length > 0 && !selBranch) setSelBranch(branches[0].id);
  }, [branches, selBranch]);

  const params = { from: from ?? undefined, to: to ?? undefined };

  const { data: sales, isLoading: salesLoading } = useQuery({
    queryKey: ["branch-sales", activeBranch?.id, from, to],
    queryFn: () =>
      reportsApi.getBranchSales(activeBranch!.id, params).then((r) => r.data),
    enabled: !!activeBranch?.id,
  });

  const { data: timeseries = [], isLoading: tsLoading } = useQuery({
    queryKey: ["timeseries", activeBranch?.id, from, to, granularity],
    queryFn: () =>
      reportsApi
        .getBranchTimeseries(activeBranch!.id, { ...params, granularity })
        .then((r) => r.data),
    enabled: !!activeBranch?.id && tab === "revenue",
  });

  const { data: tellers = [], isLoading: tellersLoading } = useQuery({
    queryKey: ["tellers", activeBranch?.id, from, to],
    queryFn: () =>
      reportsApi.getBranchTellers(activeBranch!.id, params).then((r) => r.data),
    enabled: !!activeBranch?.id && tab === "tellers",
  });

  const { data: addons = [] } = useQuery({
    queryKey: ["addon-sales", activeBranch?.id, from, to],
    queryFn: () =>
      reportsApi
        .getBranchAddonSales(activeBranch!.id, params)
        .then((r) => r.data),
    enabled: !!activeBranch?.id && (tab === "items" || tab === "overview"),
  });

  const { data: comparison, isLoading: compLoading } = useQuery({
    queryKey: ["org-comparison", orgId, from, to],
    queryFn: () =>
      reportsApi.getOrgComparison(orgId, params).then((r) => r.data),
    enabled: !!orgId && tab === "branches",
  });

  const { data: stock, isLoading: stockLoading } = useQuery({
    queryKey: ["branch-stock", activeBranch?.id],
    queryFn: () =>
      reportsApi.getBranchStock(activeBranch!.id).then((r) => r.data),
    enabled: !!activeBranch?.id && tab === "inventory",
  });

  // Payment pie — only methods with revenue > 0
  const paymentPie = sales
    ? [
        { name: "Cash", value: sales.cash_revenue, color: PAYMENT_COLORS.cash },
        { name: "Card", value: sales.card_revenue, color: PAYMENT_COLORS.card },
        {
          name: "Digital Wallet",
          value: sales.digital_wallet_revenue,
          color: PAYMENT_COLORS.digital_wallet,
        },
        {
          name: "Mixed",
          value: sales.mixed_revenue,
          color: PAYMENT_COLORS.mixed,
        },
        {
          name: "Talabat Online",
          value: sales.talabat_online_revenue,
          color: PAYMENT_COLORS.talabat_online,
        },
        {
          name: "Talabat Cash",
          value: sales.talabat_cash_revenue,
          color: PAYMENT_COLORS.talabat_cash,
        },
      ].filter((d) => d.value > 0)
    : [];

  // Timeseries: format period label
  const tsData = timeseries.map((p) => ({
    ...p,
    period: formatPeriod(p.period, granularity),
  }));

  const Loader = () => (
    <div className="space-y-3">
      {Array.from({ length: 4 }).map((_, i) => (
        <Skeleton key={i} className="h-14 rounded-xl" />
      ))}
    </div>
  );

  // ── Column defs ─────────────────────────────────────────────────────────────
  const tellerCols: ColumnDef<TellerStats, any>[] = [
    {
      accessorKey: "teller_name",
      header: "Teller",
      cell: ({ row }) => (
        <span className="font-semibold">{row.original.teller_name}</span>
      ),
    },
    {
      accessorKey: "orders",
      header: "Orders",
      cell: ({ row }) => (
        <span className="tabular-nums">{row.original.orders}</span>
      ),
    },
    {
      accessorKey: "revenue",
      header: "Revenue",
      cell: ({ row }) => (
        <span className="font-semibold tabular-nums">
          {egp(row.original.revenue)}
        </span>
      ),
    },
    {
      accessorKey: "avg_order_value",
      header: "Avg Order",
      cell: ({ row }) => (
        <span className="tabular-nums">
          {egp(row.original.avg_order_value)}
        </span>
      ),
    },
    {
      accessorKey: "voided",
      header: "Voided",
      cell: ({ row }) => (
        <span
          className={
            row.original.voided > 0
              ? "text-destructive font-semibold"
              : "text-muted-foreground"
          }
        >
          {row.original.voided}
        </span>
      ),
    },
    {
      accessorKey: "shifts",
      header: "Shifts",
      cell: ({ row }) => (
        <span className="tabular-nums">{row.original.shifts}</span>
      ),
    },
  ];

  const branchCols: ColumnDef<BranchComparison, any>[] = [
    {
      accessorKey: "branch_name",
      header: "Branch",
      cell: ({ row }) => (
        <span className="font-semibold">{row.original.branch_name}</span>
      ),
    },
    {
      accessorKey: "total_orders",
      header: "Orders",
      cell: ({ row }) => (
        <span className="tabular-nums">{row.original.total_orders}</span>
      ),
    },
    {
      accessorKey: "total_revenue",
      header: "Revenue",
      cell: ({ row }) => (
        <span className="font-bold tabular-nums">
          {egp(row.original.total_revenue)}
        </span>
      ),
    },
    {
      accessorKey: "cash_revenue",
      header: "Cash",
      cell: ({ row }) => (
        <span className="tabular-nums text-xs">
          {egp(row.original.cash_revenue)}
        </span>
      ),
    },
    {
      accessorKey: "card_revenue",
      header: "Card",
      cell: ({ row }) => (
        <span className="tabular-nums text-xs">
          {egp(row.original.card_revenue)}
        </span>
      ),
    },
    {
      id: "talabat",
      header: "Talabat",
      cell: ({ row }) => (
        <span className="tabular-nums text-xs">
          {egp(
            row.original.talabat_online_revenue +
              row.original.talabat_cash_revenue,
          )}
        </span>
      ),
    },
    {
      accessorKey: "avg_order_value",
      header: "AOV",
      cell: ({ row }) => (
        <span className="tabular-nums text-xs">
          {egp(row.original.avg_order_value)}
        </span>
      ),
    },
    {
      accessorKey: "void_rate_pct",
      header: "Void %",
      cell: ({ row }) => (
        <span
          className={`tabular-nums text-xs ${row.original.void_rate_pct > 5 ? "text-destructive font-semibold" : "text-muted-foreground"}`}
        >
          {row.original.void_rate_pct.toFixed(1)}%
        </span>
      ),
    },
  ];

  const itemCols: ColumnDef<ItemSales, any>[] = [
    {
      accessorKey: "item_name",
      header: "Item",
      cell: ({ row }) => (
        <span className="font-semibold">{row.original.item_name}</span>
      ),
    },
    {
      accessorKey: "quantity_sold",
      header: "Qty Sold",
      cell: ({ row }) => (
        <span className="tabular-nums">{row.original.quantity_sold}</span>
      ),
    },
    {
      accessorKey: "revenue",
      header: "Revenue",
      cell: ({ row }) => (
        <span className="font-semibold tabular-nums">
          {egp(row.original.revenue)}
        </span>
      ),
    },
    {
      id: "share",
      header: "Share",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground">
          {pct(row.original.revenue, sales?.total_revenue ?? 0)}
        </span>
      ),
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
              <SelectTrigger className="w-44 h-9">
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
          )
        }
      />

      {/* Date range */}
      <div className="mb-6">
        <DateRangePicker
          from={from}
          to={to}
          onChange={(f, t) => {
            setFrom(f);
            setTo(t);
          }}
        />
      </div>

      <Tabs value={tab} onValueChange={setTab}>
        <TabsList className="mb-6 flex-wrap h-auto gap-1">
          <TabsTrigger value="overview">
            <BarChart2 size={13} /> Overview
          </TabsTrigger>
          <TabsTrigger value="revenue">
            <TrendingUp size={13} /> Revenue
          </TabsTrigger>
          <TabsTrigger value="items">
            <Coffee size={13} /> Items
          </TabsTrigger>
          <TabsTrigger value="tellers">
            <Users size={13} /> Tellers
          </TabsTrigger>
          <TabsTrigger value="branches">
            <BarChart2 size={13} /> Branches
          </TabsTrigger>
          <TabsTrigger value="inventory">
            <Package size={13} /> Inventory
          </TabsTrigger>
        </TabsList>

        {/* ── Overview ─────────────────────────────────────────────────────── */}
        <TabsContent value="overview" className="space-y-6">
          {salesLoading ? (
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-28 rounded-2xl" />
              ))}
            </div>
          ) : sales ? (
            <>
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <StatCard
                  title="Total Revenue"
                  value={egp(sales.total_revenue)}
                  sub={`${sales.total_orders} orders`}
                  icon={TrendingUp}
                />
                <StatCard
                  title="Total Discounts"
                  value={egp(sales.total_discount)}
                  sub="Applied discounts"
                  icon={BarChart2}
                  iconColor="bg-amber-500"
                />
                <StatCard
                  title="Tax Collected"
                  value={egp(sales.total_tax)}
                  icon={Coffee}
                  iconColor="bg-purple-500"
                />
                <StatCard
                  title="Voided Orders"
                  value={sales.voided_orders}
                  sub={`${pct(sales.voided_orders, sales.total_orders + sales.voided_orders)} void rate`}
                  icon={Clock}
                  iconColor="bg-red-500"
                />
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                {/* Payment pie */}
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">
                    Revenue by Payment Method
                  </p>
                  {paymentPie.length > 0 ? (
                    <ResponsiveContainer width="100%" height={220}>
                      <PieChart>
                        <Pie
                          data={paymentPie}
                          dataKey="value"
                          nameKey="name"
                          cx="50%"
                          cy="50%"
                          outerRadius={80}
                          innerRadius={48}
                        >
                          {paymentPie.map((entry, i) => (
                            <Cell key={i} fill={entry.color} />
                          ))}
                        </Pie>
                        <Tooltip formatter={(v: number) => egp(v)} />
                        <Legend
                          formatter={(v) => (
                            <span className="text-xs">{v}</span>
                          )}
                        />
                      </PieChart>
                    </ResponsiveContainer>
                  ) : (
                    <p className="text-center text-muted-foreground text-sm py-10">
                      No data
                    </p>
                  )}
                </div>

                {/* Top 5 items */}
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Top Items</p>
                  <div className="space-y-3">
                    {sales.top_items.slice(0, 5).map((item, i) => {
                      const share =
                        sales.total_revenue > 0
                          ? (item.revenue / sales.total_revenue) * 100
                          : 0;
                      return (
                        <div key={item.menu_item_id}>
                          <div className="flex items-center justify-between mb-1">
                            <div className="flex items-center gap-2">
                              <span className="text-xs text-muted-foreground w-4">
                                #{i + 1}
                              </span>
                              <span className="text-sm font-medium">
                                {item.item_name}
                              </span>
                            </div>
                            <div className="flex items-center gap-2">
                              <span className="text-xs text-muted-foreground">
                                {item.quantity_sold}x
                              </span>
                              <span className="text-sm font-bold tabular-nums">
                                {egp(item.revenue)}
                              </span>
                            </div>
                          </div>
                          <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                            <div
                              className="h-full brand-gradient rounded-full"
                              style={{ width: `${share}%` }}
                            />
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
              <Button
                key={g.value}
                variant={granularity === g.value ? "default" : "outline"}
                size="sm"
                onClick={() => setGranularity(g.value)}
              >
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
                      {(
                        [
                          "cash",
                          "card",
                          "talabat_online",
                          "talabat_cash",
                        ] as const
                      ).map((m) => (
                        <linearGradient
                          key={m}
                          id={`grad-${m}`}
                          x1="0"
                          y1="0"
                          x2="0"
                          y2="1"
                        >
                          <stop
                            offset="5%"
                            stopColor={PAYMENT_COLORS[m]}
                            stopOpacity={0.3}
                          />
                          <stop
                            offset="95%"
                            stopColor={PAYMENT_COLORS[m]}
                            stopOpacity={0}
                          />
                        </linearGradient>
                      ))}
                    </defs>
                    <CartesianGrid
                      strokeDasharray="3 3"
                      stroke="hsl(var(--border))"
                    />
                    <XAxis dataKey="period" tick={{ fontSize: 11 }} />
                    <YAxis
                      tickFormatter={(v) => `${(v / 100).toFixed(0)}`}
                      tick={{ fontSize: 11 }}
                    />
                    <Tooltip content={<ChartTooltip />} />
                    <Legend
                      formatter={(v) => (
                        <span className="text-xs">
                          {fmtPayment(v.replace("_revenue", ""))}
                        </span>
                      )}
                    />
                    <Area
                      type="monotone"
                      dataKey="cash_revenue"
                      name="Cash"
                      stroke={PAYMENT_COLORS.cash}
                      fill="url(#grad-cash)"
                      strokeWidth={2}
                    />
                    <Area
                      type="monotone"
                      dataKey="card_revenue"
                      name="Card"
                      stroke={PAYMENT_COLORS.card}
                      fill="url(#grad-card)"
                      strokeWidth={2}
                    />
                    <Area
                      type="monotone"
                      dataKey="talabat_online_revenue"
                      name="Talabat Online"
                      stroke={PAYMENT_COLORS.talabat_online}
                      fill="url(#grad-talabat_online)"
                      strokeWidth={2}
                    />
                    <Area
                      type="monotone"
                      dataKey="talabat_cash_revenue"
                      name="Talabat Cash"
                      stroke={PAYMENT_COLORS.talabat_cash}
                      fill="url(#grad-talabat_cash)"
                      strokeWidth={2}
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </div>

              {/* Orders bar chart */}
              <div className="rounded-2xl border p-5">
                <p className="text-sm font-bold mb-4">Orders Over Time</p>
                <ResponsiveContainer width="100%" height={200}>
                  <BarChart data={tsData}>
                    <CartesianGrid
                      strokeDasharray="3 3"
                      stroke="hsl(var(--border))"
                    />
                    <XAxis dataKey="period" tick={{ fontSize: 11 }} />
                    <YAxis tick={{ fontSize: 11 }} />
                    <Tooltip content={<ChartTooltip />} />
                    <Bar
                      dataKey="orders"
                      name="Orders"
                      fill="hsl(var(--primary))"
                      radius={[4, 4, 0, 0]}
                    />
                    <Bar
                      dataKey="voided"
                      name="Voided"
                      fill="hsl(var(--destructive))"
                      radius={[4, 4, 0, 0]}
                    />
                  </BarChart>
                </ResponsiveContainer>
              </div>

              {/* Discount timeseries */}
              {tsData.some((p) => p.discount > 0) && (
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Discounts Over Time</p>
                  <ResponsiveContainer width="100%" height={180}>
                    <BarChart data={tsData}>
                      <CartesianGrid
                        strokeDasharray="3 3"
                        stroke="hsl(var(--border))"
                      />
                      <XAxis dataKey="period" tick={{ fontSize: 11 }} />
                      <YAxis
                        tickFormatter={(v) => `${(v / 100).toFixed(0)}`}
                        tick={{ fontSize: 11 }}
                      />
                      <Tooltip content={<ChartTooltip />} />
                      <Bar
                        dataKey="discount"
                        name="Discounts"
                        fill="hsl(38 80% 50%)"
                        radius={[4, 4, 0, 0]}
                      />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
            </>
          )}
        </TabsContent>

        {/* ── Items ────────────────────────────────────────────────────────── */}
        <TabsContent value="items" className="space-y-4">
          {salesLoading ? (
            <Loader />
          ) : (
            sales && (
              <>
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Top Items by Revenue</p>
                  <DataTable
                    data={sales.top_items}
                    columns={itemCols}
                    searchPlaceholder="Search items…"
                    pageSize={10}
                  />
                </div>

                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">By Category</p>
                  <div className="space-y-3">
                    {sales.by_category.map((cat) => {
                      const share =
                        sales.total_revenue > 0
                          ? (cat.revenue / sales.total_revenue) * 100
                          : 0;
                      return (
                        <div key={cat.category_id ?? "uncategorised"}>
                          <div className="flex items-center justify-between mb-1">
                            <span className="text-sm font-medium">
                              {cat.category_name ?? "Uncategorised"}
                            </span>
                            <div className="flex items-center gap-3">
                              <span className="text-xs text-muted-foreground">
                                {cat.quantity_sold} sold
                              </span>
                              <span className="font-bold tabular-nums text-sm">
                                {egp(cat.revenue)}
                              </span>
                            </div>
                          </div>
                          <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                            <div
                              className="h-full brand-gradient rounded-full"
                              style={{ width: `${share}%` }}
                            />
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
                        <div
                          key={a.addon_item_id}
                          className="flex items-center justify-between py-2 border-b border-border/50 last:border-0"
                        >
                          <div>
                            <span className="text-sm font-medium">
                              {a.addon_name}
                            </span>
                            <Badge variant="info" className="ml-2 text-[10px]">
                              {a.addon_type.replace("_", " ")}
                            </Badge>
                          </div>
                          <div className="flex items-center gap-3">
                            <span className="text-xs text-muted-foreground">
                              {a.quantity_sold}x
                            </span>
                            <span className="font-semibold tabular-nums text-sm">
                              {egp(a.revenue)}
                            </span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </>
            )
          )}
        </TabsContent>

        {/* ── Tellers ──────────────────────────────────────────────────────── */}
        <TabsContent value="tellers" className="space-y-4">
          {tellersLoading ? (
            <Loader />
          ) : (
            <>
              {tellers.length > 0 && (
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Revenue by Teller</p>
                  <ResponsiveContainer width="100%" height={220}>
                    <BarChart data={tellers.slice(0, 8)} layout="vertical">
                      <CartesianGrid
                        strokeDasharray="3 3"
                        stroke="hsl(var(--border))"
                        horizontal={false}
                      />
                      <XAxis
                        type="number"
                        tickFormatter={(v) => `${(v / 100).toFixed(0)}`}
                        tick={{ fontSize: 11 }}
                      />
                      <YAxis
                        type="category"
                        dataKey="teller_name"
                        tick={{ fontSize: 11 }}
                        width={90}
                      />
                      <Tooltip content={<ChartTooltip />} />
                      <Bar
                        dataKey="revenue"
                        name="revenue"
                        fill="hsl(var(--primary))"
                        radius={[0, 4, 4, 0]}
                      />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
              <DataTable
                data={tellers}
                columns={tellerCols}
                searchPlaceholder="Search tellers…"
              />
            </>
          )}
        </TabsContent>

        {/* ── Branch comparison ─────────────────────────────────────────────── */}
        <TabsContent value="branches" className="space-y-4">
          {compLoading ? (
            <Loader />
          ) : (
            comparison && (
              <>
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Revenue by Branch</p>
                  <ResponsiveContainer width="100%" height={220}>
                    <BarChart data={comparison.branches}>
                      <CartesianGrid
                        strokeDasharray="3 3"
                        stroke="hsl(var(--border))"
                      />
                      <XAxis dataKey="branch_name" tick={{ fontSize: 11 }} />
                      <YAxis
                        tickFormatter={(v) => `${(v / 100).toFixed(0)}`}
                        tick={{ fontSize: 11 }}
                      />
                      <Tooltip content={<ChartTooltip />} />
                      <Bar
                        dataKey="cash_revenue"
                        name="cash"
                        fill={PAYMENT_COLORS.cash}
                        stackId="a"
                      />
                      <Bar
                        dataKey="card_revenue"
                        name="card"
                        fill={PAYMENT_COLORS.card}
                        stackId="a"
                      />
                      <Bar
                        dataKey="talabat_online_revenue"
                        name="talabat_online"
                        fill={PAYMENT_COLORS.talabat_online}
                        stackId="a"
                      />
                      <Bar
                        dataKey="talabat_cash_revenue"
                        name="talabat_cash"
                        fill={PAYMENT_COLORS.talabat_cash}
                        stackId="a"
                        radius={[4, 4, 0, 0]}
                      />
                      <Legend
                        formatter={(v) => (
                          <span className="text-xs">{fmtPayment(v)}</span>
                        )}
                      />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
                <DataTable
                  data={comparison.branches}
                  columns={branchCols}
                  searchPlaceholder="Search branches…"
                />
              </>
            )
          )}
        </TabsContent>

        {/* ── Inventory ─────────────────────────────────────────────────────── */}
        <TabsContent value="inventory" className="space-y-4">
          {stockLoading ? (
            <Loader />
          ) : (
            stock && (
              <>
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                  <StatCard title="Total Items" value={stock.items.length} />
                  <StatCard
                    title="Low Stock"
                    value={stock.items.filter((i) => i.below_reorder).length}
                    iconColor="bg-amber-500"
                  />
                  <StatCard
                    title="OK Stock"
                    value={stock.items.filter((i) => !i.below_reorder).length}
                  />
                  <StatCard
                    title="Reorder Threshold"
                    value={`${stock.items.filter((i) => i.below_reorder).length} items`}
                    iconColor="bg-muted"
                  />
                </div>
                <div className="rounded-2xl border overflow-hidden">
                  <div className="p-4 border-b bg-muted/30">
                    <p className="font-bold text-sm">Stock Levels</p>
                  </div>
                  <div className="divide-y divide-border/50">
                    {stock.items
                      .sort(
                        (a, b) =>
                          Number(b.below_reorder) - Number(a.below_reorder),
                      )
                      .map((item) => {
                        const pctVal = Math.min(
                          100,
                          (item.current_stock /
                            Math.max(item.reorder_threshold * 2, 1)) *
                            100,
                        );
                        return (
                          <div
                            key={item.branch_inventory_id}
                            className="flex items-center gap-4 px-4 py-3"
                          >
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center gap-2 mb-1">
                                <span className="text-sm font-medium">
                                  {item.ingredient_name}
                                </span>
                                {item.below_reorder && (
                                  <Badge
                                    variant="warning"
                                    className="text-[10px] h-4"
                                  >
                                    Low
                                  </Badge>
                                )}
                              </div>
                              <div className="flex items-center gap-2">
                                <div className="flex-1 h-1.5 bg-muted rounded-full overflow-hidden">
                                  <div
                                    className={`h-full rounded-full ${item.below_reorder ? "bg-amber-500" : "brand-gradient"}`}
                                    style={{ width: `${pctVal}%` }}
                                  />
                                </div>
                                <span className="text-xs text-muted-foreground whitespace-nowrap">
                                  {item.current_stock} /{" "}
                                  {item.reorder_threshold} {item.unit}
                                </span>
                              </div>
                            </div>
                          </div>
                        );
                      })}
                  </div>
                </div>
              </>
            )
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
