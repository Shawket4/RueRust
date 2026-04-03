import React, { useState } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import { useTheme } from "next-themes";
import {
  Coffee,
  Tag,
  ShoppingBag,
  Building2,
  Users,
  LayoutDashboard,
  LogOut,
  Search,
  X,
  GitBranch,
  Package,
  BookOpen,
  Clock,
  BarChart2,
  Shield,
  Sun,
  Moon,
  Languages,
  ChevronRight,
  PanelLeftClose,
  PanelLeftOpen,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
  TooltipProvider,
} from "@/components/ui/tooltip";
import { Separator } from "@/components/ui/separator";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import { fmtRole, ROLE_COLORS, initials } from "@/utils/format";

const NAV = [
  {
    group: "Overview",
    items: [
      {
        to: "/",
        icon: LayoutDashboard,
        label: "Dashboard",
        sub: "System overview",
        roles: ["super_admin", "org_admin", "branch_manager", "teller"],
      },
    ],
  },
  {
    group: "Management",
    items: [
      {
        to: "/orgs",
        icon: Building2,
        label: "Organizations",
        sub: "Manage coffee brands",
        roles: ["super_admin"],
      },
      {
        to: "/users",
        icon: Users,
        label: "Users",
        sub: "Staff accounts",
        roles: ["super_admin", "org_admin", "branch_manager"],
      },
      {
        to: "/branches",
        icon: GitBranch,
        label: "Branches",
        sub: "Manage branches",
        roles: ["super_admin", "org_admin", "branch_manager"],
      },
      {
        to: "/menu",
        icon: Coffee,
        label: "Menu",
        sub: "Items & categories",
        roles: ["super_admin", "org_admin", "branch_manager"],
      },
      {
        to: "/inventory",
        icon: Package,
        label: "Inventory",
        sub: "Stock & transfers",
        roles: ["super_admin", "org_admin", "branch_manager"],
      },
      {
        to: "/recipes",
        icon: BookOpen,
        label: "Recipes",
        sub: "Drink ingredients",
        roles: ["super_admin", "org_admin", "branch_manager"],
      },
      {
        to: "/shifts",
        icon: Clock,
        label: "Shifts",
        sub: "Reports & management",
        roles: ["super_admin", "org_admin", "branch_manager"],
      },
      {
        to: "/analytics",
        icon: BarChart2,
        label: "Analytics",
        sub: "Reports & trends",
        roles: ["super_admin", "org_admin", "branch_manager"],
      },
      {
        to: "/orders",
        icon: ShoppingBag,
        label: "Orders",
        sub: "Browse by shift",
        roles: ["super_admin", "org_admin", "branch_manager"],
      },
      {
        to: "/discounts",
        icon: Tag,
        label: "Discounts",
        sub: "Preset discounts",
        roles: ["super_admin", "org_admin", "branch_manager"],
      },
    ],
  },
] as const;

interface SidebarContentProps {
  collapsed: boolean;
  onClose?: () => void;
}

function SidebarContent({ collapsed, onClose }: SidebarContentProps) {
  const [search, setSearch] = useState("");
  const user = useAuthStore((s) => s.user);
  const signOut = useAuthStore((s) => s.signOut);
  const language = useAppStore((s) => s.language);
  const setLang = useAppStore((s) => s.setLanguage);
  const { theme, setTheme } = useTheme();
  const navigate = useNavigate();

  const handleSignOut = () => {
    signOut();
    navigate("/login");
  };
  const toggleLang = () => setLang(language === "en" ? "ar" : "en");
  const toggleTheme = () => setTheme(theme === "dark" ? "light" : "dark");

  const filtered = NAV.map((g) => ({
    ...g,
    items: g.items.filter(
      (i) =>
        (i.roles as readonly string[]).includes(user?.role ?? "") &&
        (search === "" || i.label.toLowerCase().includes(search.toLowerCase())),
    ),
  })).filter((g) => g.items.length > 0);

  return (
    <TooltipProvider delayDuration={0}>
      <div className="flex flex-col h-full overflow-hidden">
        {/* Logo ─────────────────────────────────────────────── */}
        <div
          className={cn(
            "flex items-center border-b border-border flex-shrink-0",
            collapsed
              ? "h-14 justify-center px-2"
              : "h-14 px-4 justify-between",
          )}
        >
          {!collapsed && (
            <img
              src="/TheRue.png"
              alt="The Rue"
              className="h-7 object-contain"
            />
          )}
          {collapsed && (
            <div className="w-8 h-8 brand-gradient rounded-xl flex items-center justify-center">
              <Coffee size={16} className="text-white" />
            </div>
          )}
          {onClose && !collapsed && (
            <Button
              variant="ghost"
              size="icon-sm"
              onClick={onClose}
              className="lg:hidden"
            >
              <X size={16} />
            </Button>
          )}
        </div>

        {/* Search — hidden when collapsed */}
        {!collapsed && (
          <div className="px-3 py-2 border-b border-border flex-shrink-0">
            <div className="flex items-center gap-2 bg-muted rounded-xl px-3 py-2">
              <Search
                size={13}
                className="text-muted-foreground flex-shrink-0"
              />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search… ⌘K"
                className="flex-1 bg-transparent text-sm outline-none placeholder:text-muted-foreground min-w-0"
              />
              {search && (
                <button
                  onClick={() => setSearch("")}
                  className="text-muted-foreground hover:text-foreground transition-colors"
                >
                  <X size={13} />
                </button>
              )}
            </div>
          </div>
        )}

        {/* Nav */}
        <nav className="flex-1 overflow-y-auto py-2 px-2 no-scrollbar">
          {filtered.map((group) => (
            <div key={group.group} className="mb-3">
              {!collapsed && (
                <p className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest px-3 mb-1">
                  {group.group}
                </p>
              )}
              <div className="space-y-0.5">
                {group.items.map(({ to, icon: Icon, label, sub }) => (
                  <Tooltip key={to} disableHoverableContent={!collapsed}>
                    <TooltipTrigger asChild>
                      <NavLink to={to} end={to === "/"} onClick={onClose}>
                        {({ isActive }) => (
                          <div
                            className={cn(
                              "relative flex items-center gap-3 rounded-xl transition-all duration-150",
                              collapsed
                                ? "justify-center h-10 w-10 mx-auto"
                                : "px-3 py-2.5",
                              isActive
                                ? "bg-accent text-accent-foreground font-semibold"
                                : "text-foreground hover:bg-muted hover:text-foreground",
                            )}
                          >
                            {isActive && !collapsed && (
                              <span className="nav-active-indicator" />
                            )}
                            <div
                              className={cn(
                                "flex items-center justify-center rounded-lg flex-shrink-0 transition-all",
                                collapsed ? "w-8 h-8" : "w-7 h-7",
                                isActive
                                  ? "brand-gradient text-white shadow-sm"
                                  : "bg-muted text-foreground",
                              )}
                            >
                              <Icon size={collapsed ? 15 : 14} />
                            </div>
                            {!collapsed && (
                              <div className="flex-1 min-w-0">
                                <p
                                  className={cn(
                                    "text-sm leading-tight truncate",
                                    isActive ? "font-semibold" : "font-medium",
                                  )}
                                >
                                  {label}
                                </p>
                                <p className="text-[11px] text-muted-foreground truncate">
                                  {sub}
                                </p>
                              </div>
                            )}
                            {!collapsed && isActive && (
                              <ChevronRight
                                size={12}
                                className="text-primary flex-shrink-0"
                              />
                            )}
                          </div>
                        )}
                      </NavLink>
                    </TooltipTrigger>
                    {collapsed && (
                      <TooltipContent side="right">
                        <p className="font-medium">{label}</p>
                      </TooltipContent>
                    )}
                  </Tooltip>
                ))}
              </div>
            </div>
          ))}
        </nav>

        {/* Footer */}
        <div
          className={cn(
            "flex-shrink-0 border-t border-border",
            collapsed ? "p-2" : "p-3",
          )}
        >
          {/* Theme + Language */}
          <div
            className={cn(
              "flex mb-2 gap-1",
              collapsed
                ? "flex-col items-center"
                : "items-center justify-between",
            )}
          >
            {!collapsed && (
              <span className="text-xs text-muted-foreground">Appearance</span>
            )}
            <div className="flex gap-1">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="ghost" size="icon-sm" onClick={toggleTheme}>
                    {theme === "dark" ? <Sun size={14} /> : <Moon size={14} />}
                  </Button>
                </TooltipTrigger>
                <TooltipContent side={collapsed ? "right" : "top"}>
                  {theme === "dark" ? "Light mode" : "Dark mode"}
                </TooltipContent>
              </Tooltip>
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="ghost" size="icon-sm" onClick={toggleLang}>
                    <Languages size={14} />
                  </Button>
                </TooltipTrigger>
                <TooltipContent side={collapsed ? "right" : "top"}>
                  {language === "en" ? "Switch to Arabic" : "Switch to English"}
                </TooltipContent>
              </Tooltip>
            </div>
          </div>

          <Separator className="mb-2" />

          {/* User */}
          {collapsed ? (
            <Tooltip>
              <TooltipTrigger asChild>
                <button
                  onClick={handleSignOut}
                  className="w-full flex items-center justify-center"
                >
                  <Avatar className="h-8 w-8">
                    <AvatarFallback className="text-xs">
                      {initials(user?.name ?? "")}
                    </AvatarFallback>
                  </Avatar>
                </button>
              </TooltipTrigger>
              <TooltipContent side="right">
                <p className="font-medium">{user?.name}</p>
                <p className="text-xs text-muted-foreground">
                  {fmtRole(user?.role ?? "")}
                </p>
              </TooltipContent>
            </Tooltip>
          ) : (
            <>
              <div className="flex items-center gap-3 p-2 rounded-xl bg-muted mb-2">
                <Avatar className="h-8 w-8 flex-shrink-0">
                  <AvatarFallback className="text-xs">
                    {initials(user?.name ?? "")}
                  </AvatarFallback>
                </Avatar>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold truncate">{user?.name}</p>
                  <p
                    className={cn(
                      "text-[10px] font-semibold px-1.5 py-0.5 rounded-full border inline-block mt-0.5",
                      ROLE_COLORS[user?.role ?? ""],
                    )}
                  >
                    {fmtRole(user?.role ?? "")}
                  </p>
                </div>
              </div>
              <Button
                variant="destructive"
                size="sm"
                className="w-full justify-center"
                onClick={handleSignOut}
              >
                <LogOut size={13} />
                Sign Out
              </Button>
            </>
          )}
        </div>
      </div>
    </TooltipProvider>
  );
}

interface SidebarProps {
  mobileOpen: boolean;
  onMobileClose: () => void;
}

export function Sidebar({ mobileOpen, onMobileClose }: SidebarProps) {
  const collapsed = useAppStore((s) => !s.sidebarOpen);
  const toggleSidebar = useAppStore((s) => s.toggleSidebar);

  return (
    <>
      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm lg:hidden"
          onClick={onMobileClose}
        />
      )}

      {/* Mobile drawer */}
      <aside
        className={cn(
          "fixed left-0 top-0 bottom-0 z-50 w-[min(280px,82vw)] bg-background border-r border-border shadow-xl",
          "transition-transform duration-250 ease-[cubic-bezier(0.4,0,0.2,1)] lg:hidden",
          mobileOpen ? "translate-x-0" : "-translate-x-full",
        )}
      >
        <SidebarContent collapsed={false} onClose={onMobileClose} />
      </aside>

      {/* Desktop sidebar */}
      <aside
        className={cn(
          "hidden lg:flex flex-col bg-background border-r border-border flex-shrink-0 sticky top-0 h-screen",
          "transition-[width] duration-200 ease-in-out relative",
          collapsed ? "w-[64px]" : "w-[240px]",
        )}
      >
        <SidebarContent collapsed={collapsed} />

        {/* Collapse toggle */}
        <button
          onClick={toggleSidebar}
          className={cn(
            "absolute -right-3 top-20 z-10",
            "w-6 h-6 rounded-full bg-background border border-border shadow-sm",
            "flex items-center justify-center text-muted-foreground hover:text-foreground",
            "transition-colors",
          )}
        >
          {collapsed ? (
            <PanelLeftOpen size={12} />
          ) : (
            <PanelLeftClose size={12} />
          )}
        </button>
      </aside>
    </>
  );
}
