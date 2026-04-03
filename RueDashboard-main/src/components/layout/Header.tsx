import React from "react";
import { useLocation } from "react-router-dom";
import { Menu, Search } from "lucide-react";
import { Button } from "@/components/ui/button";

const TITLES: Record<string, { title: string; sub: string }> = {
  "/":           { title: "Dashboard",     sub: "System overview" },
  "/orgs":       { title: "Organizations", sub: "Manage all coffee brands" },
  "/users":      { title: "Users",         sub: "Manage staff accounts" },
  "/branches":   { title: "Branches",      sub: "Manage branch locations" },
  "/menu":       { title: "Menu",          sub: "Categories, items and addons" },
  "/inventory":  { title: "Inventory",     sub: "Stock levels and transfers" },
  "/recipes":    { title: "Recipes",       sub: "Drink ingredients" },
  "/shifts":     { title: "Shifts",        sub: "Reports and shift management" },
  "/analytics":  { title: "Analytics",     sub: "Reports & trends" },
  "/permissions":{ title: "Permissions",   sub: "User access control" },
};

interface HeaderProps {
  onMenuClick: () => void;
  onSearchClick?: () => void;
}

export function Header({ onMenuClick, onSearchClick }: HeaderProps) {
  const loc  = useLocation();
  const segs = loc.pathname.split("/").filter(Boolean);
  const base = segs.length ? "/" + segs[0] : "/";
  const meta = TITLES[base] ?? { title: "Rue POS", sub: "" };

  return (
    <header className="h-14 flex-shrink-0 bg-background border-b border-border flex items-center px-4 gap-3 sticky top-0 z-30">
      {/* Mobile hamburger */}
      <Button
        variant="ghost"
        size="icon-sm"
        onClick={onMenuClick}
        className="lg:hidden flex-shrink-0"
        aria-label="Open menu"
      >
        <Menu size={18} />
      </Button>

      <div className="flex-1 min-w-0">
        <h1 className="text-sm font-bold leading-tight truncate">{meta.title}</h1>
        <p className="text-xs text-muted-foreground mt-0.5 hidden sm:block truncate">{meta.sub}</p>
      </div>

      {/* Search shortcut hint */}
      <button
        onClick={onSearchClick}
        className="hidden sm:flex items-center gap-2 text-xs text-muted-foreground bg-muted hover:bg-muted/80 px-3 py-1.5 rounded-lg transition-colors"
      >
        <Search size={12} />
        <span>Search</span>
        <kbd className="text-[10px] bg-background border border-border rounded px-1 font-mono">⌘K</kbd>
      </button>
    </header>
  );
}
