import React from "react";
import { cn } from "@/lib/utils";
import type { LucideIcon } from "lucide-react";

interface EmptyStateProps {
  icon?:       LucideIcon;
  title:       string;
  sub?:        string;
  action?:     React.ReactNode;
  className?:  string;
}

export function EmptyState({ icon: Icon, title, sub, action, className }: EmptyStateProps) {
  return (
    <div className={cn("flex flex-col items-center justify-center py-16 text-center", className)}>
      {Icon && (
        <div className="w-12 h-12 rounded-2xl bg-muted flex items-center justify-center mb-4">
          <Icon size={22} className="text-muted-foreground" />
        </div>
      )}
      <p className="font-semibold text-sm">{title}</p>
      {sub && <p className="text-xs text-muted-foreground mt-1 max-w-xs">{sub}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}
