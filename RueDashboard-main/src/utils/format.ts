import type { PaymentMethod } from "@/types";

export const TZ = "Africa/Cairo";
const loc = (opts: Intl.DateTimeFormatOptions) => ({ ...opts, timeZone: TZ });

// ── Money ─────────────────────────────────────────────────────────────────────
export const egp = (piastres: number = 0): string => {
  const egpValue = piastres / 100;
  return `EGP ${egpValue.toLocaleString("en", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  })}`;
};

export const egpFull = (piastres: number = 0): string => {
  const egpValue = piastres / 100;
  return `EGP ${egpValue.toLocaleString("en", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
};

export const toEGP      = (p: number): string => (p / 100).toFixed(2);
export const toPiastres = (v: string | number): number =>
  Math.round(parseFloat(String(v)) * 100) || 0;

// ── Dates ─────────────────────────────────────────────────────────────────────
export const fmtDate = (iso: string | null | undefined): string => {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-GB", loc({
    day: "2-digit", month: "short", year: "numeric",
  }));
};

export const fmtTime = (iso: string | null | undefined): string => {
  if (!iso) return "—";
  return new Date(iso).toLocaleTimeString("en-GB", loc({
    hour: "2-digit", minute: "2-digit",
  }));
};

export const fmtDateTime = (iso: string | null | undefined): string => {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("en-GB", loc({
    day: "2-digit", month: "short",
    hour: "2-digit", minute: "2-digit",
  }));
};

export const fmtDateTimeFull = (iso: string | null | undefined): string => {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("en-GB", loc({
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  }));
};

// ── Duration ──────────────────────────────────────────────────────────────────
export const fmtDuration = (
  start: string | null | undefined,
  end?: string | null,
): string => {
  if (!start) return "—";
  const ms = new Date(end ?? Date.now()).getTime() - new Date(start).getTime();
  const h  = Math.floor(ms / 3_600_000);
  const m  = Math.floor((ms % 3_600_000) / 60_000);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
};

// ── Payment methods ───────────────────────────────────────────────────────────
export const PAYMENT_LABELS: Record<PaymentMethod, string> = {
  cash:           "Cash",
  card:           "Card",
  digital_wallet: "Digital Wallet",
  mixed:          "Mixed",
  talabat_online: "Talabat Online",
  talabat_cash:   "Talabat Cash",
};

export const fmtPayment = (method: string): string =>
  PAYMENT_LABELS[method as PaymentMethod] ??
  method.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

export const PAYMENT_COLORS: Record<PaymentMethod, string> = {
  cash:           "hsl(142 71% 45%)",
  card:           "hsl(221 78% 47%)",
  digital_wallet: "hsl(258 58% 52%)",
  mixed:          "hsl(38 80% 50%)",
  talabat_online: "hsl(22 88% 52%)",
  talabat_cash:   "hsl(22 60% 38%)",
};

export const PAYMENT_BG: Record<PaymentMethod, string> = {
  cash:           "bg-green-50 text-green-700 dark:bg-green-950 dark:text-green-300",
  card:           "bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300",
  digital_wallet: "bg-purple-50 text-purple-700 dark:bg-purple-950 dark:text-purple-300",
  mixed:          "bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-300",
  talabat_online: "bg-orange-50 text-orange-700 dark:bg-orange-950 dark:text-orange-300",
  talabat_cash:   "bg-orange-50 text-orange-800 dark:bg-orange-950 dark:text-orange-400",
};

// ── Roles ─────────────────────────────────────────────────────────────────────
export const ROLE_LABELS: Record<string, string> = {
  super_admin:    "Super Admin",
  org_admin:      "Org Admin",
  branch_manager: "Branch Manager",
  teller:         "Teller",
};

export const fmtRole = (role: string): string =>
  ROLE_LABELS[role] ?? role.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

export const ROLE_COLORS: Record<string, string> = {
  super_admin:    "bg-yellow-50 text-yellow-700 border-yellow-200 dark:bg-yellow-950 dark:text-yellow-300 dark:border-yellow-800",
  org_admin:      "bg-violet-50 text-violet-700 border-violet-200 dark:bg-violet-950 dark:text-violet-300 dark:border-violet-800",
  branch_manager: "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:border-blue-800",
  teller:         "bg-green-50 text-green-700 border-green-200 dark:bg-green-950 dark:text-green-300 dark:border-green-800",
};

// ── Shift status ──────────────────────────────────────────────────────────────
export const SHIFT_STATUS_LABELS: Record<string, string> = {
  open:         "Open",
  closed:       "Closed",
  force_closed: "Force Closed",
};

export const SHIFT_STATUS_COLORS: Record<string, string> = {
  open:         "bg-green-50 text-green-700 border-green-200 dark:bg-green-950 dark:text-green-300",
  closed:       "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950 dark:text-blue-300",
  force_closed: "bg-orange-50 text-orange-700 border-orange-200 dark:bg-orange-950 dark:text-orange-300",
};

// ── Units ─────────────────────────────────────────────────────────────────────
export const UNIT_LABELS: Record<string, string> = {
  g: "g", kg: "kg", ml: "ml", l: "L", pcs: "pcs",
};

export const fmtUnit = (unit: string): string => UNIT_LABELS[unit] ?? unit;

// ── Percentage ────────────────────────────────────────────────────────────────
export const pct = (value: number, total: number): string => {
  if (total === 0) return "0%";
  return `${((value / total) * 100).toFixed(1)}%`;
};

// ── Size labels ───────────────────────────────────────────────────────────────
export const SIZE_LABELS: Record<string, string> = {
  small:       "Small",
  medium:      "Medium",
  large:       "Large",
  extra_large: "X-Large",
  one_size:    "One Size",
};

export const SIZE_SHORT: Record<string, string> = {
  small: "S", medium: "M", large: "L", extra_large: "XL", one_size: "—",
};

export const fmtSize = (size: string): string => SIZE_LABELS[size] ?? size;

// ── Addon type labels ─────────────────────────────────────────────────────────
export const ADDON_TYPE_LABELS: Record<string, string> = {
  coffee_type: "Coffee Type",
  milk_type:   "Milk Type",
  extra:       "Extra",
};

export const fmtAddonType = (type: string): string =>
  ADDON_TYPE_LABELS[type] ?? type;

// ── Normalise name capitalisation ─────────────────────────────────────────────
export const normName = (s: string = ""): string =>
  s.split(" ").map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(" ");

// ── Initials ──────────────────────────────────────────────────────────────────
export const initials = (name: string = ""): string =>
  name.split(" ").slice(0, 2).map((w) => w[0]?.toUpperCase() ?? "").join("");

// ── Period formatting ─────────────────────────────────────────────────────────
export const formatPeriod = (iso: string, granularity: string): string => {
  const d = new Date(iso);
  const opts: Intl.DateTimeFormatOptions =
    granularity === "hourly"  ? { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit", hour12: false } :
    granularity === "monthly" ? { month: "short", year: "numeric" } :
                                { month: "short", day: "numeric" };
  return d.toLocaleString("en-GB", loc(opts));
};