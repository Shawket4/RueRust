import React from "react";
import { cn } from "@/lib/utils";
import { Skeleton } from "@/components/ui/skeleton";
import type { LucideIcon } from "lucide-react";

interface StatCardProps {
  title:       string;
  value:       string | number;
  sub?:        string;
  icon?:       LucideIcon;
  iconColor?:  string;
  trend?:      { value: number; label: string };
  loading?:    boolean;
  className?:  string;
  onClick?:    () => void;
}

export function StatCard({ title, value, sub, icon: Icon, iconColor, trend, loading, className, onClick }: StatCardProps) {
  if (loading) return (
    <div className={cn("rounded-2xl border bg-card p-5 space-y-3", className)}>
      <Skeleton className="h-4 w-24" />
      <Skeleton className="h-8 w-32" />
      <Skeleton className="h-3 w-20" />
    </div>
  );

  return (
    <div
      onClick={onClick}
      className={cn(
        "rounded-2xl border bg-card p-5 transition-all duration-150",
        onClick && "cursor-pointer hover:shadow-md hover:-translate-y-0.5",
        className,
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</p>
          <p className="text-2xl font-bold mt-1 tabular-nums">{value}</p>
          {sub && <p className="text-xs text-muted-foreground mt-1">{sub}</p>}
          {trend && (
            <p className={cn("text-xs font-semibold mt-1", trend.value >= 0 ? "text-green-600" : "text-red-500")}>
              {trend.value >= 0 ? "↑" : "↓"} {Math.abs(trend.value).toFixed(1)}% {trend.label}
            </p>
          )}
        </div>
        {Icon && (
          <div className={cn("w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0", iconColor ?? "brand-gradient")}>
            <Icon size={18} className="text-white" />
          </div>
        )}
      </div>
    </div>
  );
}
