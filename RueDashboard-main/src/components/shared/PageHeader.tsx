import React from "react";
import { cn } from "@/lib/utils";

interface PageHeaderProps {
  title:       string;
  sub?:        string;
  actions?:    React.ReactNode;
  className?:  string;
}

export function PageHeader({ title, sub, actions, className }: PageHeaderProps) {
  return (
    <div className={cn("flex items-start justify-between gap-4 mb-6", className)}>
      <div>
        <h1 className="text-xl font-bold">{title}</h1>
        {sub && <p className="text-sm text-muted-foreground mt-0.5">{sub}</p>}
      </div>
      {actions && <div className="flex items-center gap-2 flex-shrink-0">{actions}</div>}
    </div>
  );
}
