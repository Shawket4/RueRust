import React, { useMemo } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import {
  Building2,
  Users,
  GitBranch,
  Coffee,
  TrendingUp,
  AlertTriangle,
  Clock,
  ShoppingBag,
  CheckCircle2,
  ArrowRight,
  Package,
  RefreshCw,
  Wifi,
  WifiOff,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Card as UICard } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/store/auth";
import { getOrgs } from "@/api/orgs";
import { getUsers } from "@/api/users";
import { getBranches } from "@/api/branches";
import { getCurrentShift } from "@/api/shifts";
import { getBranchStock } from "@/api/inventory";
import { getOrders } from "@/api/orders";
import {
  egp,
  fmtTime,
  fmtDuration,
  fmtPayment,
  PAYMENT_BG,
  TZ,
} from "@/utils/format";
import type { Branch, Order, BranchInventoryItem } from "@/types";

// ── Card component shorthand ──────────────────────────────────────────────────
function Card({
  children,
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "bg-card rounded-2xl border border-border shadow-sm",
        className,
      )}
      {...props}
    >
      {children}
    </div>
  );
}

// ── Greeting ──────────────────────────────────────────────────────────────────
function greet(name?: string | null): string {
  const h = parseInt(
    new Intl.DateTimeFormat("en-GB", {
      timeZone: TZ,
      hour: "numeric",
      hour12: false,
    }).format(new Date()),
  );
  const word = h < 12 ? "Morning" : h < 17 ? "Afternoon" : "Evening";
  return `Good ${word}, ${name?.split(" ")[0] ?? "there"} 👋`;
}

// ── Stat card ─────────────────────────────────────────────────────────────────
interface StatCardProps {
  icon: React.ElementType;
  label: string;
  value: string | number | undefined;
  sub?: string;
  accent?: string;
  bg?: string;
  loading?: boolean;
  to?: string;
}

function StatCard({
  icon: Icon,
  label,
  value,
  sub,
  accent = "text-primary",
  bg = "bg-primary/10",
  loading,
  to,
}: StatCardProps) {
  const inner = (
    <UICard
      className={cn(
        "p-5 h-full flex flex-col justify-between transition-all hover:shadow-md group",
        to && "cursor-pointer",
      )}
    >
      <div className="flex items-start justify-between mb-4">
        <div
          className={cn(
            "w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0",
            bg,
          )}
        >
          <Icon size={18} className={accent} />
        </div>
        {to && (
          <ArrowRight
            size={14}
            className="text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity"
          />
        )}
      </div>
      {loading ? (
        <div className="space-y-2">
          <Skeleton className="h-8 w-16" />
          <Skeleton className="h-3 w-24" />
        </div>
      ) : (
        <div>
          <p className="text-3xl font-extrabold tabular-nums">{value ?? "—"}</p>
          <p className="text-sm font-semibold text-muted-foreground mt-1">
            {label}
          </p>
          {sub && <p className="text-xs text-muted-foreground mt-0.5">{sub}</p>}
        </div>
      )}
    </UICard>
  );
  return to ? (
    <Link to={to} className="block h-full">
      {inner}
    </Link>
  ) : (
    inner
  );
}

// ── Branch status dot ─────────────────────────────────────────────────────────
function BranchCard({ branch }: { branch: Branch }) {
  const { data: shiftData, isLoading: shiftLoading } = useQuery({
    queryKey: ["current-shift", branch.id],
    queryFn: () => getCurrentShift(branch.id).then((r) => r.data),
    refetchInterval: 60_000,
    staleTime: 30_000,
  });

  const shiftId = shiftData?.open_shift?.id;

  const { data: orders = [] } = useQuery({
    queryKey: ["shift-orders", shiftId],
    queryFn: () => getOrders({ shift_id: shiftId }).then((r) => r.data.data),
    enabled: !!shiftId,
    staleTime: 30_000,
  });

  const { data: invItems = [] } = useQuery({
    queryKey: ["inventory", branch.id],
    queryFn: () => getBranchStock(branch.id).then((r) => r.data),
    staleTime: 120_000,
  });

  const hasOpen = shiftData?.has_open_shift;
  const openShift = shiftData?.open_shift;
  const validOrds = orders.filter((o) => o.status !== "voided");
  const todaySales = validOrds.reduce((s, o) => s + o.total_amount, 0);
  const lowStock = (invItems as BranchInventoryItem[]).filter(
    (i) => i.below_reorder,
  );

  return (
    <UICard
      className={cn(
        "overflow-hidden transition-all hover:shadow-md",
        hasOpen ? "border-green-200 dark:border-green-800" : "",
      )}
    >
      {/* Header */}
      <div
        className={cn(
          "px-4 py-3 flex items-center justify-between border-b",
          hasOpen
            ? "bg-green-50 border-green-100 dark:bg-green-950/40 dark:border-green-900"
            : "bg-muted/50 border-border",
        )}
      >
        <div className="flex items-center gap-2.5 min-w-0">
          <span
            className={cn(
              "w-2.5 h-2.5 rounded-full flex-shrink-0",
              shiftLoading
                ? "bg-muted-foreground animate-pulse"
                : hasOpen
                  ? "bg-green-500 shadow-[0_0_0_3px_rgba(34,197,94,0.25)]"
                  : "bg-muted-foreground",
            )}
          />
          <p className="font-semibold text-sm truncate">{branch.name}</p>
        </div>
        {!shiftLoading && (
          <Badge
            variant={hasOpen ? "success" : "secondary"}
            className="flex-shrink-0 ml-2"
          >
            {hasOpen ? "Open" : "Closed"}
          </Badge>
        )}
      </div>

      {/* Body */}
      <div className="px-4 py-3 space-y-3">
        {shiftLoading ? (
          <div className="space-y-2">
            <Skeleton className="h-3.5 w-full" />
            <Skeleton className="h-3.5 w-3/4" />
          </div>
        ) : hasOpen && openShift ? (
          <>
            <div className="grid grid-cols-2 gap-x-4 gap-y-1.5 text-xs">
              <span className="text-muted-foreground">Teller</span>
              <span className="font-semibold text-right truncate">
                {openShift.teller_name}
              </span>
              <span className="text-muted-foreground">Running</span>
              <span className="font-mono text-right">
                {fmtDuration(openShift.opened_at)}
              </span>
              <span className="text-muted-foreground">Opening</span>
              <span className="font-mono text-right">
                {egp(openShift.opening_cash)}
              </span>
            </div>
            <div className="pt-2 border-t border-border">
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted-foreground">
                  Today's Sales
                </span>
                <span className="font-bold text-primary text-sm font-mono">
                  {egp(todaySales)}
                </span>
              </div>
              <div className="flex items-center justify-between mt-0.5">
                <span className="text-xs text-muted-foreground">
                  {validOrds.length} orders
                </span>
                {orders.filter((o) => o.status === "voided").length > 0 && (
                  <span className="text-xs text-destructive">
                    {orders.filter((o) => o.status === "voided").length} voided
                  </span>
                )}
              </div>
            </div>
          </>
        ) : (
          <p className="text-sm text-muted-foreground text-center py-1">
            No active shift
          </p>
        )}

        {lowStock.length > 0 && (
          <div className="flex items-center gap-2 bg-amber-50 border border-amber-200 dark:bg-amber-950/40 dark:border-amber-800 rounded-xl px-3 py-2">
            <AlertTriangle size={12} className="text-amber-600 flex-shrink-0" />
            <span className="text-xs font-semibold text-amber-700 dark:text-amber-400">
              {lowStock.length} item{lowStock.length > 1 ? "s" : ""} low on
              stock
            </span>
          </div>
        )}
      </div>

      <div className="px-4 pb-4">
        <Link
          to="/shifts"
          className="flex items-center justify-center gap-1.5 w-full py-2 rounded-xl text-xs font-semibold text-muted-foreground bg-muted hover:bg-muted/70 transition-colors"
        >
          View Shifts <ArrowRight size={11} />
        </Link>
      </div>
    </UICard>
  );
}

// ── Recent orders panel ───────────────────────────────────────────────────────
function RecentOrders({ branches }: { branches: Branch[] }) {
  const [activeBranchId, setActiveBranchId] = React.useState<string | null>(
    null,
  );
  const [shiftId, setShiftId] = React.useState<string | null>(null);

  useQuery({
    queryKey: ["dashboard-scan", branches.map((b) => b.id).join(",")],
    enabled: branches.length > 0 && !activeBranchId,
    queryFn: async () => {
      for (const branch of branches) {
        try {
          const r = await getCurrentShift(branch.id).then((res) => res.data);
          if (r.has_open_shift && r.open_shift?.id) {
            setActiveBranchId(branch.id);
            setShiftId(r.open_shift.id);
            return r;
          }
        } catch {
          /* skip */
        }
      }
      return null;
    },
  });

  const { data: orders = [], isLoading } = useQuery({
    queryKey: ["shift-orders", shiftId],
    queryFn: () => getOrders({ shift_id: shiftId! }).then((r) => r.data.data),
    enabled: !!shiftId,
    staleTime: 30_000,
    refetchInterval: 60_000,
  });

  const recent = [...orders]
    .sort(
      (a, b) =>
        new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    )
    .slice(0, 10);

  const activeBranch = branches.find((b) => b.id === activeBranchId);

  return (
    <UICard className="overflow-hidden">
      <div className="px-5 py-3.5 border-b border-border flex items-center justify-between">
        <div className="flex items-center gap-2 min-w-0">
          <ShoppingBag size={14} className="text-primary flex-shrink-0" />
          <h3 className="font-semibold text-sm truncate">Recent Orders</h3>
          {activeBranch && (
            <span className="text-xs text-muted-foreground font-mono hidden sm:block truncate">
              {activeBranch.name}
            </span>
          )}
        </div>
        <Link
          to="/shifts"
          className="text-xs font-semibold text-primary hover:text-primary/80 flex items-center gap-1 flex-shrink-0 ml-2"
        >
          All <ArrowRight size={11} />
        </Link>
      </div>

      {isLoading ? (
        <div className="p-4 space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="flex items-center gap-3">
              <Skeleton className="h-9 w-9 rounded-xl flex-shrink-0" />
              <div className="flex-1 space-y-1.5">
                <Skeleton className="h-3 w-28" />
                <Skeleton className="h-3 w-16" />
              </div>
              <Skeleton className="h-4 w-16 flex-shrink-0" />
            </div>
          ))}
        </div>
      ) : !shiftId ? (
        <div className="flex flex-col items-center justify-center py-12 text-muted-foreground gap-2">
          <WifiOff size={24} className="text-muted-foreground/40" />
          <p className="text-sm">No open shift found</p>
        </div>
      ) : recent.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-muted-foreground gap-2">
          <ShoppingBag size={24} className="text-muted-foreground/40" />
          <p className="text-sm">No orders yet this shift</p>
        </div>
      ) : (
        <div
          className="divide-y divide-border overflow-y-auto"
          style={{ maxHeight: "min(360px,50dvh)" }}
        >
          {recent.map((order) => {
            const isVoided = order.status === "voided";
            return (
              <div
                key={order.id}
                className={cn(
                  "flex items-center gap-3 px-5 py-3 hover:bg-muted/50 transition-colors",
                  isVoided && "opacity-50",
                )}
              >
                <div
                  className={cn(
                    "w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 font-bold text-xs",
                    isVoided
                      ? "bg-muted text-muted-foreground"
                      : "bg-primary/10 text-primary",
                  )}
                >
                  #{order.order_number}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <span
                      className={cn(
                        "text-xs font-semibold px-1.5 py-0.5 rounded-full",
                        PAYMENT_BG[order.payment_method] ??
                          "bg-muted text-muted-foreground",
                      )}
                    >
                      {fmtPayment(order.payment_method)}
                    </span>
                    {isVoided && (
                      <Badge variant="destructive" className="text-[10px]">
                        Voided
                      </Badge>
                    )}
                  </div>
                  <p className="text-xs text-muted-foreground mt-0.5">
                    {fmtTime(order.created_at)}
                  </p>
                </div>
                <p
                  className={cn(
                    "font-bold text-sm font-mono flex-shrink-0",
                    isVoided
                      ? "text-muted-foreground line-through"
                      : "text-foreground",
                  )}
                >
                  {egp(order.total_amount)}
                </p>
              </div>
            );
          })}
        </div>
      )}
    </UICard>
  );
}

// ── Low stock panel ───────────────────────────────────────────────────────────
function LowStockPanel({ branches }: { branches: Branch[] }) {
  const { data: items = [], isLoading } = useQuery({
    queryKey: ["inventory-all-branches", branches.map((b) => b.id)],
    enabled: branches.length > 0,
    staleTime: 120_000,
    queryFn: async () => {
      const results = await Promise.allSettled(
        branches.map((b) => getBranchStock(b.id).then((r) => r.data)),
      );
      const map = new Map<string, BranchInventoryItem>();
      results
        .filter(
          (r): r is PromiseFulfilledResult<BranchInventoryItem[]> =>
            r.status === "fulfilled",
        )
        .flatMap((r) => r.value)
        .forEach((item) => {
          const existing = map.get(item.ingredient_name);
          if (
            !existing ||
            parseFloat(String(item.current_stock)) <
              parseFloat(String(existing.current_stock))
          ) {
            map.set(item.ingredient_name, item);
          }
        });
      return [...map.values()];
    },
  });

  const low = items
    .filter((i) => i.below_reorder)
    .sort(
      (a, b) =>
        parseFloat(String(a.current_stock)) /
          Math.max(parseFloat(String(a.reorder_threshold)), 0.001) -
        parseFloat(String(b.current_stock)) /
          Math.max(parseFloat(String(b.reorder_threshold)), 0.001),
    );

  return (
    <UICard className="overflow-hidden">
      <div className="px-5 py-3.5 border-b border-border flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Package size={14} className="text-amber-500 flex-shrink-0" />
          <h3 className="font-semibold text-sm">Low Stock</h3>
          {low.length > 0 && <Badge variant="warning">{low.length}</Badge>}
        </div>
        <Link
          to="/inventory"
          className="text-xs font-semibold text-primary hover:text-primary/80 flex items-center gap-1 flex-shrink-0 ml-2"
        >
          Inventory <ArrowRight size={11} />
        </Link>
      </div>

      {isLoading ? (
        <div className="p-4 space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="space-y-1.5">
              <Skeleton className="h-3 w-28" />
              <Skeleton className="h-2 w-full rounded-full" />
            </div>
          ))}
        </div>
      ) : low.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 gap-2 text-muted-foreground">
          <CheckCircle2 size={24} className="text-green-500" />
          <p className="text-sm">All stock levels OK</p>
        </div>
      ) : (
        <div
          className="divide-y divide-border overflow-y-auto"
          style={{ maxHeight: "min(360px,50dvh)" }}
        >
          {low.map((item) => {
            const curr = parseFloat(String(item.current_stock));
            const thresh = parseFloat(String(item.reorder_threshold));
            const pct = Math.min((curr / Math.max(thresh, 0.001)) * 100, 100);
            const critical = curr === 0;
            return (
              <div key={item.id} className="px-5 py-3">
                <div className="flex items-center justify-between mb-1">
                  <p className="text-sm font-medium truncate mr-2">
                    {item.ingredient_name}
                  </p>
                  <span
                    className={cn(
                      "text-xs font-bold font-mono flex-shrink-0",
                      critical ? "text-destructive" : "text-amber-600",
                    )}
                  >
                    {curr} {item.unit}
                  </span>
                </div>
                <div className="h-1.5 w-full bg-muted rounded-full overflow-hidden">
                  <div
                    className={cn(
                      "h-full rounded-full transition-all",
                      critical ? "bg-destructive" : "bg-amber-400",
                    )}
                    style={{ width: `${Math.max(pct, 3)}%` }}
                  />
                </div>
                <p className="text-[10px] text-muted-foreground mt-1">
                  Reorder at {thresh} {item.unit}
                </p>
              </div>
            );
          })}
        </div>
      )}
    </UICard>
  );
}

// ── Today's sales summary ─────────────────────────────────────────────────────
function SalesSummary({ branches }: { branches: Branch[] }) {
  const { data, isLoading } = useQuery({
    queryKey: ["dashboard-sales", branches.map((b) => b.id)],
    enabled: branches.length > 0,
    staleTime: 60_000,
    queryFn: async () => {
      let totalSales = 0,
        totalOrders = 0,
        cash = 0,
        card = 0,
        talabat = 0,
        openCount = 0;
      await Promise.allSettled(
        branches.map(async (branch) => {
          try {
            const s = await getCurrentShift(branch.id).then((r) => r.data);
            if (!s.has_open_shift || !s.open_shift?.id) return;
            openCount++;
            const orders = await getOrders({ shift_id: s.open_shift.id }).then(
              (r) => r.data.data,
            );
            const valid = (orders as Order[]).filter(
              (o) => o.status !== "voided",
            );
            totalOrders += valid.length;
            valid.forEach((o) => {
              totalSales += o.total_amount;
              if (o.payment_method === "cash") cash += o.total_amount;
              if (o.payment_method === "card") card += o.total_amount;
              if (
                o.payment_method === "talabat_online" ||
                o.payment_method === "talabat_cash"
              )
                talabat += o.total_amount;
            });
          } catch {
            /* skip */
          }
        }),
      );
      return { totalSales, totalOrders, cash, card, talabat, openCount };
    },
  });

  const items = [
    {
      label: "Total Sales",
      value: egp(data?.totalSales),
      className: "text-primary",
    },
    {
      label: "Orders",
      value: data?.totalOrders ?? 0,
      className: "text-green-600",
    },
    { label: "Cash", value: egp(data?.cash), className: "text-foreground" },
    { label: "Card", value: egp(data?.card), className: "text-violet-600" },
    {
      label: "Talabat",
      value: egp(data?.talabat),
      className: "text-orange-600",
    },
  ];

  return (
    <UICard className="overflow-hidden">
      <div className="px-5 py-3.5 border-b border-border flex items-center justify-between">
        <div className="flex items-center gap-2">
          <TrendingUp size={14} className="text-primary" />
          <h3 className="font-semibold text-sm">Today's Sales</h3>
          {!isLoading && data && (
            <span className="text-xs text-muted-foreground">
              {data.openCount} active
            </span>
          )}
        </div>
        <Link
          to="/shifts"
          className="text-xs font-semibold text-primary hover:text-primary/80 flex items-center gap-1"
        >
          Details <ArrowRight size={11} />
        </Link>
      </div>
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 divide-x divide-y divide-border">
        {items.map(({ label, value, className }) => (
          <div key={label} className="px-4 py-4">
            {isLoading ? (
              <div className="space-y-1.5">
                <Skeleton className="h-5 w-20" />
                <Skeleton className="h-3 w-12" />
              </div>
            ) : (
              <>
                <p
                  className={cn(
                    "text-base font-extrabold font-mono",
                    className,
                  )}
                >
                  {value}
                </p>
                <p className="text-xs text-muted-foreground mt-0.5">{label}</p>
              </>
            )}
          </div>
        ))}
      </div>
    </UICard>
  );
}

// ── Branch status row (compact) ───────────────────────────────────────────────
function BranchStatusRow({ branch }: { branch: Branch }) {
  const { data, isLoading } = useQuery({
    queryKey: ["current-shift", branch.id],
    queryFn: () => getCurrentShift(branch.id).then((r) => r.data),
    refetchInterval: 60_000,
    staleTime: 30_000,
  });
  const hasOpen = data?.has_open_shift;
  const shift = data?.open_shift;
  return (
    <div className="flex items-center gap-3 px-5 py-3">
      <span
        className={cn(
          "w-2 h-2 rounded-full flex-shrink-0",
          isLoading
            ? "bg-muted-foreground animate-pulse"
            : hasOpen
              ? "bg-green-500"
              : "bg-muted-foreground",
        )}
      />
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium truncate">{branch.name}</p>
        {!isLoading && hasOpen && shift && (
          <p className="text-xs text-muted-foreground truncate">
            {shift.teller_name} · {fmtDuration(shift.opened_at)}
          </p>
        )}
        {!isLoading && !hasOpen && (
          <p className="text-xs text-muted-foreground">No active shift</p>
        )}
      </div>
      {isLoading ? (
        <Skeleton className="h-5 w-14" />
      ) : (
        <Badge variant={hasOpen ? "success" : "secondary"}>
          {hasOpen ? "Open" : "Closed"}
        </Badge>
      )}
    </div>
  );
}

// ── Active shifts count ───────────────────────────────────────────────────────
function ActiveShiftsCard({
  branches,
  loading,
}: {
  branches: Branch[];
  loading: boolean;
}) {
  const { data: count = 0, isLoading } = useQuery({
    queryKey: ["active-shifts-count", branches.map((b) => b.id)],
    enabled: branches.length > 0,
    staleTime: 60_000,
    queryFn: async () => {
      let c = 0;
      await Promise.allSettled(
        branches.map(async (b) => {
          const d = await getCurrentShift(b.id)
            .then((r) => r.data)
            .catch(() => null);
          if (d?.has_open_shift) c++;
        }),
      );
      return c;
    },
  });

  return (
    <StatCard
      icon={Clock}
      label="Active Shifts"
      value={isLoading || loading ? undefined : count}
      sub={`of ${branches.length} branches`}
      accent="text-green-600"
      bg="bg-green-50 dark:bg-green-950/50"
      loading={isLoading || loading}
    />
  );
}

// ── Super admin stats ─────────────────────────────────────────────────────────
function SuperAdminStats() {
  const { data: orgs, isLoading: orgsLoading } = useQuery({
    queryKey: ["orgs"],
    queryFn: () => getOrgs().then((r) => r.data),
  });
  const { data: users, isLoading: usersLoading } = useQuery({
    queryKey: ["users", null],
    queryFn: () => getUsers(null).then((r) => r.data),
  });

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <StatCard
        icon={Building2}
        label="Organizations"
        value={orgs?.length}
        sub="Active brands"
        accent="text-primary"
        bg="bg-primary/10"
        loading={orgsLoading}
        to="/orgs"
      />
      <StatCard
        icon={Users}
        label="Total Users"
        value={users?.length}
        sub="Staff accounts"
        accent="text-violet-600"
        bg="bg-violet-100 dark:bg-violet-950/50"
        loading={usersLoading}
        to="/users"
      />
      <StatCard
        icon={GitBranch}
        label="Active Orgs"
        value={orgs?.filter((o) => o.is_active).length}
        sub="Live now"
        accent="text-amber-600"
        bg="bg-amber-100 dark:bg-amber-950/50"
        loading={orgsLoading}
      />
      <StatCard
        icon={Coffee}
        label="Active Users"
        value={users?.filter((u) => u.is_active).length}
        sub="Accounts"
        accent="text-green-600"
        bg="bg-green-100 dark:bg-green-950/50"
        loading={usersLoading}
      />
    </div>
  );
}

// ── Org admin stats ───────────────────────────────────────────────────────────
function OrgAdminStats({ orgId }: { orgId: string }) {
  const { data: users, isLoading: usersLoading } = useQuery({
    queryKey: ["users", orgId],
    queryFn: () => getUsers(orgId).then((r) => r.data),
    enabled: !!orgId,
  });
  const { data: branches, isLoading: branchesLoading } = useQuery({
    queryKey: ["branches", orgId],
    queryFn: () => getBranches(orgId).then((r) => r.data),
    enabled: !!orgId,
  });

  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <StatCard
        icon={Users}
        label="Staff"
        value={users?.length}
        sub={`${users?.filter((u) => u.is_active).length ?? 0} active`}
        accent="text-violet-600"
        bg="bg-violet-100 dark:bg-violet-950/50"
        loading={usersLoading}
        to="/users"
      />
      <StatCard
        icon={GitBranch}
        label="Branches"
        value={branches?.length}
        sub={`${branches?.filter((b) => b.is_active).length ?? 0} active`}
        accent="text-primary"
        bg="bg-primary/10"
        loading={branchesLoading}
        to="/branches"
      />
      <StatCard
        icon={Coffee}
        label="Operating"
        value={branches?.filter((b) => b.is_active).length}
        sub="Today"
        accent="text-amber-600"
        bg="bg-amber-100 dark:bg-amber-950/50"
        loading={branchesLoading}
      />
      <ActiveShiftsCard branches={branches ?? []} loading={branchesLoading} />
    </div>
  );
}

// ── Main Dashboard ────────────────────────────────────────────────────────────
export default function Dashboard() {
  const user = useAuthStore((s) => s.user);
  const orgId = user?.org_id ?? "";
  const role = user?.role;

  const { data: branches = [], isLoading: branchesLoading } = useQuery({
    queryKey: ["branches", orgId],
    queryFn: () => getBranches(orgId).then((r) => r.data),
    enabled: !!orgId,
    staleTime: 120_000,
  });

  const isSuperAdmin = role === "super_admin";
  const isOrgLevel = role === "org_admin" || role === "branch_manager";

  return (
    <div className="p-4 sm:p-6 lg:p-8 space-y-5 max-w-[1400px] mx-auto animate-fade-in">
      {/* ── Welcome hero ─────────────────────────────────────── */}
      <div className="brand-gradient rounded-2xl p-6 sm:p-8 text-white relative overflow-hidden">
        <div className="relative z-10 flex flex-col sm:flex-row sm:items-center gap-4">
          <div className="flex-1 min-w-0">
            <p className="text-blue-200 text-xs sm:text-sm font-medium mb-1">
              Dashboard
            </p>
            <h2 className="text-xl sm:text-2xl lg:text-3xl font-extrabold mb-1 leading-snug">
              {greet(user?.name)}
            </h2>
            <p className="text-blue-100 text-xs sm:text-sm capitalize">
              {role?.replace(/_/g, " ")} · Rue POS
            </p>
          </div>
          {!branchesLoading && branches.length > 0 && (
            <div className="flex items-center gap-2 bg-white/15 backdrop-blur rounded-xl px-3 py-2 self-start">
              <span className="w-2 h-2 rounded-full bg-green-400" />
              <span className="text-sm font-semibold">
                {branches.length} branch{branches.length !== 1 ? "es" : ""}
              </span>
            </div>
          )}
        </div>
      </div>

      {/* ── Stats row ────────────────────────────────────────── */}
      {isSuperAdmin && <SuperAdminStats />}
      {isOrgLevel && <OrgAdminStats orgId={orgId} />}

      {/* ── Branch grid ──────────────────────────────────────── */}
      {isOrgLevel && branches.length > 0 && (
        <section>
          <h3 className="text-xs font-bold text-muted-foreground uppercase tracking-widest mb-3">
            Branch Overview
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {branchesLoading
              ? Array.from({ length: 3 }).map((_, i) => (
                  <Skeleton key={i} className="h-44 rounded-2xl" />
                ))
              : branches.map((branch) => (
                  <BranchCard key={branch.id} branch={branch} />
                ))}
          </div>
        </section>
      )}

      {/* ── Sales + orders + low stock ───────────────────────── */}
      {isOrgLevel && branches.length > 0 && (
        <>
          <SalesSummary branches={branches} />

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            {/* Left column */}
            <div className="space-y-4">
              {branches.length > 1 && (
                <UICard className="overflow-hidden">
                  <div className="px-5 py-3.5 border-b border-border flex items-center gap-2">
                    <Clock size={14} className="text-primary" />
                    <h3 className="font-semibold text-sm">Branch Status</h3>
                  </div>
                  <div className="divide-y divide-border">
                    {branches.map((branch) => (
                      <BranchStatusRow key={branch.id} branch={branch} />
                    ))}
                  </div>
                </UICard>
              )}
              <LowStockPanel branches={branches} />
            </div>

            {/* Right column */}
            <RecentOrders branches={branches} />
          </div>
        </>
      )}

      {/* ── Super admin quick actions ─────────────────────────── */}
      {isSuperAdmin && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <UICard className="p-5 sm:p-6">
            <div className="flex items-center gap-2 mb-4">
              <TrendingUp size={15} className="text-primary" />
              <h3 className="font-semibold">Quick Actions</h3>
            </div>
            <div className="space-y-2">
              {[
                {
                  label: "Manage Organizations",
                  to: "/orgs",
                  color:
                    "bg-primary/10 text-primary hover:bg-primary/20 dark:bg-primary/20",
                },
                {
                  label: "Manage Users",
                  to: "/users",
                  color:
                    "bg-violet-100 text-violet-700 hover:bg-violet-200 dark:bg-violet-950/50",
                },
                {
                  label: "View All Branches",
                  to: "/branches",
                  color:
                    "bg-amber-100 text-amber-700 hover:bg-amber-200 dark:bg-amber-950/50",
                },
                {
                  label: "Shifts & Reports",
                  to: "/shifts",
                  color:
                    "bg-green-100 text-green-700 hover:bg-green-200 dark:bg-green-950/50",
                },
                {
                  label: "Analytics",
                  to: "/analytics",
                  color:
                    "bg-blue-100 text-blue-700 hover:bg-blue-200 dark:bg-blue-950/50",
                },
              ].map((a) => (
                <Link
                  key={a.label}
                  to={a.to}
                  className={cn(
                    "flex items-center justify-between px-4 py-3 rounded-xl font-medium text-sm transition-colors",
                    a.color,
                  )}
                >
                  {a.label}
                  <ArrowRight size={14} />
                </Link>
              ))}
            </div>
          </UICard>

          <UICard className="p-5 sm:p-6">
            <div className="flex items-center gap-2 mb-4">
              <RefreshCw size={15} className="text-primary" />
              <h3 className="font-semibold">System Status</h3>
            </div>
            {["API Server", "Database", "Auth Service"].map((s) => (
              <div
                key={s}
                className="flex items-center justify-between py-3 border-b border-border last:border-0"
              >
                <span className="text-sm">{s}</span>
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                  <span className="text-xs font-semibold text-green-600">
                    Online
                  </span>
                </div>
              </div>
            ))}
          </UICard>
        </div>
      )}
    </div>
  );
}
