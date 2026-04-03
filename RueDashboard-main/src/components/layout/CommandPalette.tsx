import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  LayoutDashboard, Building2, Users, GitBranch, Coffee,
  Tag, ShoppingBag,
  Package, BookOpen, Clock, BarChart2, Shield,
} from "lucide-react";
import {
  CommandDialog, CommandEmpty, CommandGroup, CommandInput,
  CommandItem, CommandList, CommandSeparator,
} from "@/components/ui/command";
import { useAuthStore } from "@/store/auth";

const NAV_ITEMS = [
  { label: "Dashboard",     to: "/",                    icon: LayoutDashboard, roles: ["super_admin","org_admin","branch_manager","teller"] },
  { label: "Organizations", to: "/orgs",                icon: Building2,       roles: ["super_admin"] },
  { label: "Users",         to: "/users",               icon: Users,           roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Branches",      to: "/branches",            icon: GitBranch,       roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Menu",          to: "/menu",                icon: Coffee,          roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Inventory",     to: "/inventory",           icon: Package,         roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Recipes",       to: "/recipes",             icon: BookOpen,        roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Shifts",        to: "/shifts",              icon: Clock,           roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Analytics",     to: "/analytics",           icon: BarChart2,       roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Permissions",   to: "/permissions/select",  icon: Shield,          roles: ["super_admin","org_admin"] },
  { label: "Orders",        to: "/orders",              icon: ShoppingBag,     roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Discounts",     to: "/discounts",           icon: Tag,             roles: ["super_admin","org_admin","branch_manager"] },
];

export function CommandPalette() {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if ((e.key === "k" && (e.metaKey || e.ctrlKey)) || e.key === "/") {
        e.preventDefault();
        setOpen((o) => !o);
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  const filtered = NAV_ITEMS.filter((i) => i.roles.includes(user?.role ?? ""));

  return (
    <CommandDialog open={open} onOpenChange={setOpen}>
      <CommandInput placeholder="Search pages…" />
      <CommandList>
        <CommandEmpty>No results found.</CommandEmpty>
        <CommandGroup heading="Navigation">
          {filtered.map(({ label, to, icon: Icon }) => (
            <CommandItem
              key={to}
              onSelect={() => { navigate(to); setOpen(false); }}
            >
              <Icon className="mr-2 h-4 w-4" />
              {label}
            </CommandItem>
          ))}
        </CommandGroup>
        <CommandSeparator />
        <CommandGroup heading="Shortcuts">
          <CommandItem onSelect={() => { navigate("/shifts"); setOpen(false); }}>
            <Clock className="mr-2 h-4 w-4" />
            Open Shifts
          </CommandItem>
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  );
}
