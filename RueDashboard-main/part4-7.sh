#!/usr/bin/env bash
# =============================================================================
#  Rue POS Dashboard — Frontend Parts 4-7
#  Menu · Recipes · Inventory · Shifts (+ Shift Report) · Analytics · Permissions
#  Run from the React project root after Parts 1-3 complete.
# =============================================================================
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log()  { echo -e "${CYAN}[parts4-7]${RESET} $*"; }
ok()   { echo -e "${GREEN}[done]   ${RESET} $*"; }
warn() { echo -e "${YELLOW}[warn]   ${RESET} $*"; }

[[ ! -f "package.json" ]] && { echo "ERROR: Run from React project root."; exit 1; }

mkdir -p src/pages/{menu,recipes,inventory,shifts,analytics,permissions}
mkdir -p src/components/{shared,shifts,analytics}

# ===========================================================================
#  SHARED COMPONENTS
# ===========================================================================
log "Writing shared components..."

cat > src/components/shared/DataTable.tsx << 'TSX'
import React from "react";
import {
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  getSortedRowModel,
  useReactTable,
  type ColumnDef,
  type SortingState,
  type ColumnFiltersState,
} from "@tanstack/react-table";
import { ChevronUp, ChevronDown, ChevronsUpDown, ChevronLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

interface DataTableProps<T> {
  data:           T[];
  columns:        ColumnDef<T, any>[];
  searchKey?:     string;
  searchPlaceholder?: string;
  pageSize?:      number;
  className?:     string;
  toolbar?:       React.ReactNode;
  onRowClick?:    (row: T) => void;
}

export function DataTable<T>({
  data, columns, searchKey, searchPlaceholder = "Search…",
  pageSize = 20, className, toolbar, onRowClick,
}: DataTableProps<T>) {
  const [sorting,       setSorting]       = React.useState<SortingState>([]);
  const [columnFilters, setColumnFilters] = React.useState<ColumnFiltersState>([]);
  const [globalFilter,  setGlobalFilter]  = React.useState("");

  const table = useReactTable({
    data,
    columns,
    state:                  { sorting, columnFilters, globalFilter },
    onSortingChange:        setSorting,
    onColumnFiltersChange:  setColumnFilters,
    onGlobalFilterChange:   setGlobalFilter,
    getCoreRowModel:        getCoreRowModel(),
    getSortedRowModel:      getSortedRowModel(),
    getFilteredRowModel:    getFilteredRowModel(),
    getPaginationRowModel:  getPaginationRowModel(),
    initialState:           { pagination: { pageSize } },
  });

  return (
    <div className={cn("space-y-3", className)}>
      {/* Toolbar */}
      <div className="flex items-center gap-3 flex-wrap">
        {searchKey || !searchKey ? (
          <Input
            placeholder={searchPlaceholder}
            value={globalFilter}
            onChange={(e) => setGlobalFilter(e.target.value)}
            className="h-9 w-full sm:w-64"
          />
        ) : null}
        {toolbar && <div className="flex items-center gap-2 ml-auto">{toolbar}</div>}
      </div>

      {/* Table */}
      <div className="rounded-xl border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-muted/50 border-b">
              {table.getHeaderGroups().map((hg) => (
                <tr key={hg.id}>
                  {hg.headers.map((header) => (
                    <th
                      key={header.id}
                      className="h-10 px-4 text-left font-semibold text-muted-foreground text-xs uppercase tracking-wide whitespace-nowrap"
                    >
                      {header.isPlaceholder ? null : (
                        <div
                          className={cn(
                            "flex items-center gap-1",
                            header.column.getCanSort() && "cursor-pointer select-none hover:text-foreground transition-colors",
                          )}
                          onClick={header.column.getToggleSortingHandler()}
                        >
                          {flexRender(header.column.columnDef.header, header.getContext())}
                          {header.column.getCanSort() && (
                            header.column.getIsSorted() === "asc"  ? <ChevronUp size={12} /> :
                            header.column.getIsSorted() === "desc" ? <ChevronDown size={12} /> :
                            <ChevronsUpDown size={12} className="opacity-40" />
                          )}
                        </div>
                      )}
                    </th>
                  ))}
                </tr>
              ))}
            </thead>
            <tbody>
              {table.getRowModel().rows.length === 0 ? (
                <tr>
                  <td colSpan={columns.length} className="h-32 text-center text-muted-foreground text-sm">
                    No results found.
                  </td>
                </tr>
              ) : (
                table.getRowModel().rows.map((row) => (
                  <tr
                    key={row.id}
                    onClick={() => onRowClick?.(row.original)}
                    className={cn(
                      "border-b border-border/50 transition-colors",
                      onRowClick && "cursor-pointer hover:bg-muted/40",
                    )}
                  >
                    {row.getVisibleCells().map((cell) => (
                      <td key={cell.id} className="px-4 py-3 align-middle">
                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                      </td>
                    ))}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pagination */}
      {table.getPageCount() > 1 && (
        <div className="flex items-center justify-between text-sm text-muted-foreground">
          <span>
            {table.getFilteredRowModel().rows.length} results ·{" "}
            Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}
          </span>
          <div className="flex items-center gap-1">
            <Button variant="outline" size="icon-sm" onClick={() => table.previousPage()} disabled={!table.getCanPreviousPage()}>
              <ChevronLeft size={14} />
            </Button>
            <Button variant="outline" size="icon-sm" onClick={() => table.nextPage()} disabled={!table.getCanNextPage()}>
              <ChevronRight size={14} />
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
TSX

cat > src/components/shared/StatCard.tsx << 'TSX'
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
TSX

cat > src/components/shared/PageHeader.tsx << 'TSX'
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
TSX

cat > src/components/shared/EmptyState.tsx << 'TSX'
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
TSX

cat > src/components/shared/DateRangePicker.tsx << 'TSX'
import React, { useState } from "react";
import { Calendar } from "lucide-react";
import { Button } from "@/components/ui/button";
import { fmtDate } from "@/utils/format";

interface DateRangePickerProps {
  from?:     string | null;
  to?:       string | null;
  onChange:  (from: string | null, to: string | null) => void;
}

const PRESETS = [
  { label: "Today",      days: 0 },
  { label: "7 days",     days: 7 },
  { label: "30 days",    days: 30 },
  { label: "90 days",    days: 90 },
];

export function DateRangePicker({ from, to, onChange }: DateRangePickerProps) {
  const apply = (days: number) => {
    const now = new Date();
    const start = new Date();
    start.setDate(now.getDate() - days);
    onChange(start.toISOString(), now.toISOString());
  };

  return (
    <div className="flex items-center gap-2 flex-wrap">
      {PRESETS.map((p) => (
        <Button key={p.label} variant="outline" size="sm" onClick={() => apply(p.days)} className="h-8 text-xs">
          {p.label}
        </Button>
      ))}
      <Button variant="outline" size="sm" onClick={() => onChange(null, null)} className="h-8 text-xs">
        All time
      </Button>
      {from && (
        <span className="text-xs text-muted-foreground flex items-center gap-1">
          <Calendar size={11} />
          {fmtDate(from)} → {to ? fmtDate(to) : "now"}
        </span>
      )}
    </div>
  );
}
TSX

ok "Shared components"

# ===========================================================================
#  PART 4A — MENU PAGE
# ===========================================================================
log "Writing Menu page..."

cat > src/pages/menu/Menu.tsx << 'TSX'
import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Plus, Pencil, Trash2, Coffee, Tag, Package, Image, ToggleLeft, ToggleRight } from "lucide-react";
import { type ColumnDef } from "@tanstack/react-table";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as menuApi from "@/api/menu";
import type { Category, MenuItem, AddonItem } from "@/types";
import { egp, fmtAddonType, ADDON_TYPE_LABELS } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { DataTable } from "@/components/shared/DataTable";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";

export default function Menu() {
  const user   = useAuthStore((s) => s.user);
  const orgId  = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const qc     = useQueryClient();
  const [tab, setTab] = useState("items");

  // ── Categories ──────────────────────────────────────────────
  const { data: cats = [], isLoading: catsLoading } = useQuery({
    queryKey: ["categories", orgId],
    queryFn:  () => menuApi.getCategories(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  // ── Menu items ───────────────────────────────────────────────
  const [selCat, setSelCat] = useState<string | null>(null);
  const { data: items = [], isLoading: itemsLoading } = useQuery({
    queryKey: ["menu-items", orgId, selCat],
    queryFn:  () => menuApi.getMenuItems(orgId, selCat).then((r) => r.data),
    enabled:  !!orgId,
  });

  // ── Addon items ──────────────────────────────────────────────
  const [selAddonType, setSelAddonType] = useState<string | null>(null);
  const { data: addons = [], isLoading: addonsLoading } = useQuery({
    queryKey: ["addon-items", orgId, selAddonType],
    queryFn:  () => menuApi.getAddonItems(orgId, selAddonType).then((r) => r.data),
    enabled:  !!orgId,
  });

  // ── Category dialog ──────────────────────────────────────────
  const [catDialog, setCatDialog]   = useState(false);
  const [editCat, setEditCat]       = useState<Category | null>(null);
  const [catForm, setCatForm]       = useState({ name: "", display_order: "0" });

  const openCatDialog = (cat?: Category) => {
    setEditCat(cat ?? null);
    setCatForm({ name: cat?.name ?? "", display_order: String(cat?.display_order ?? 0) });
    setCatDialog(true);
  };

  const catMutation = useMutation({
    mutationFn: () => editCat
      ? menuApi.updateCategory(editCat.id, { name: catForm.name, display_order: parseInt(catForm.display_order) })
      : menuApi.createCategory({ org_id: orgId, name: catForm.name, display_order: parseInt(catForm.display_order) }),
    onSuccess: () => {
      toast.success(editCat ? "Category updated" : "Category created");
      qc.invalidateQueries({ queryKey: ["categories"] });
      setCatDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const deleteCatMutation = useMutation({
    mutationFn: (id: string) => menuApi.deleteCategory(id),
    onSuccess: () => { toast.success("Category deleted"); qc.invalidateQueries({ queryKey: ["categories"] }); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Menu item dialog ─────────────────────────────────────────
  const [itemDialog, setItemDialog] = useState(false);
  const [editItem, setEditItem]     = useState<MenuItem | null>(null);
  const [itemForm, setItemForm]     = useState({
    name: "", description: "", base_price: "", category_id: "", is_active: true,
  });

  const openItemDialog = (item?: MenuItem) => {
    setEditItem(item ?? null);
    setItemForm({
      name:        item?.name ?? "",
      description: item?.description ?? "",
      base_price:  item ? String(item.base_price / 100) : "",
      category_id: item?.category_id ?? "",
      is_active:   item?.is_active ?? true,
    });
    setItemDialog(true);
  };

  const itemMutation = useMutation({
    mutationFn: () => {
      const payload = {
        org_id:      orgId,
        name:        itemForm.name,
        description: itemForm.description || null,
        base_price:  Math.round(parseFloat(itemForm.base_price) * 100),
        category_id: itemForm.category_id || null,
        is_active:   itemForm.is_active,
      };
      return editItem
        ? menuApi.updateMenuItem(editItem.id, payload)
        : menuApi.createMenuItem(payload);
    },
    onSuccess: () => {
      toast.success(editItem ? "Item updated" : "Item created");
      qc.invalidateQueries({ queryKey: ["menu-items"] });
      setItemDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const toggleItem = useMutation({
    mutationFn: (item: MenuItem) => menuApi.updateMenuItem(item.id, { is_active: !item.is_active }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["menu-items"] }),
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Addon dialog ─────────────────────────────────────────────
  const [addonDialog, setAddonDialog] = useState(false);
  const [editAddon, setEditAddon]     = useState<AddonItem | null>(null);
  const [addonForm, setAddonForm]     = useState({
    name: "", addon_type: "extra", default_price: "", display_order: "0",
  });

  const openAddonDialog = (addon?: AddonItem) => {
    setEditAddon(addon ?? null);
    setAddonForm({
      name:          addon?.name ?? "",
      addon_type:    addon?.addon_type ?? "extra",
      default_price: addon ? String(addon.default_price / 100) : "",
      display_order: String(addon?.display_order ?? 0),
    });
    setAddonDialog(true);
  };

  const addonMutation = useMutation({
    mutationFn: () => {
      const payload = {
        org_id:        orgId,
        name:          addonForm.name,
        addon_type:    addonForm.addon_type,
        default_price: Math.round(parseFloat(addonForm.default_price) * 100),
        display_order: parseInt(addonForm.display_order),
      };
      return editAddon
        ? menuApi.updateAddonItem(editAddon.id, payload)
        : menuApi.createAddonItem(payload);
    },
    onSuccess: () => {
      toast.success(editAddon ? "Addon updated" : "Addon created");
      qc.invalidateQueries({ queryKey: ["addon-items"] });
      setAddonDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Columns ──────────────────────────────────────────────────
  const itemCols: ColumnDef<MenuItem, any>[] = [
    { accessorKey: "name", header: "Name",
      cell: ({ row }) => (
        <div>
          <p className="font-semibold text-sm">{row.original.name}</p>
          {row.original.description && <p className="text-xs text-muted-foreground truncate max-w-[200px]">{row.original.description}</p>}
        </div>
      ),
    },
    { accessorKey: "base_price", header: "Price",
      cell: ({ row }) => <span className="font-semibold tabular-nums">{egp(row.original.base_price)}</span>,
    },
    { accessorKey: "category_id", header: "Category",
      cell: ({ row }) => {
        const cat = cats.find((c) => c.id === row.original.category_id);
        return cat ? <Badge variant="outline">{cat.name}</Badge> : <span className="text-muted-foreground text-xs">—</span>;
      },
    },
    { accessorKey: "is_active", header: "Active",
      cell: ({ row }) => (
        <button onClick={(e) => { e.stopPropagation(); toggleItem.mutate(row.original); }}>
          {row.original.is_active
            ? <ToggleRight size={20} className="text-green-500" />
            : <ToggleLeft  size={20} className="text-muted-foreground" />}
        </button>
      ),
    },
    { id: "actions", header: "",
      cell: ({ row }) => (
        <div className="flex items-center gap-1 justify-end" onClick={(e) => e.stopPropagation()}>
          <Button variant="ghost" size="icon-sm" onClick={() => openItemDialog(row.original)}>
            <Pencil size={13} />
          </Button>
        </div>
      ),
    },
  ];

  const catCols: ColumnDef<Category, any>[] = [
    { accessorKey: "name", header: "Name", cell: ({ row }) => <span className="font-semibold">{row.original.name}</span> },
    { accessorKey: "display_order", header: "Order" },
    { accessorKey: "is_active", header: "Active",
      cell: ({ row }) => <Badge variant={row.original.is_active ? "success" : "outline"}>{row.original.is_active ? "Active" : "Inactive"}</Badge>,
    },
    { id: "actions", header: "",
      cell: ({ row }) => (
        <div className="flex items-center gap-1 justify-end">
          <Button variant="ghost" size="icon-sm" onClick={() => openCatDialog(row.original)}><Pencil size={13} /></Button>
          <Button variant="ghost" size="icon-sm" className="text-destructive" onClick={() => deleteCatMutation.mutate(row.original.id)}><Trash2 size={13} /></Button>
        </div>
      ),
    },
  ];

  const addonCols: ColumnDef<AddonItem, any>[] = [
    { accessorKey: "name", header: "Name", cell: ({ row }) => <span className="font-semibold">{row.original.name}</span> },
    { accessorKey: "addon_type", header: "Type",
      cell: ({ row }) => <Badge variant="info">{fmtAddonType(row.original.addon_type)}</Badge>,
    },
    { accessorKey: "default_price", header: "Price",
      cell: ({ row }) => <span className="tabular-nums">{egp(row.original.default_price)}</span>,
    },
    { accessorKey: "is_active", header: "Active",
      cell: ({ row }) => <Badge variant={row.original.is_active ? "success" : "outline"}>{row.original.is_active ? "Active" : "Inactive"}</Badge>,
    },
    { id: "actions", header: "",
      cell: ({ row }) => (
        <div className="flex justify-end">
          <Button variant="ghost" size="icon-sm" onClick={() => openAddonDialog(row.original)}><Pencil size={13} /></Button>
        </div>
      ),
    },
  ];

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader title="Menu" sub="Manage categories, items and addons" />

      <Tabs value={tab} onValueChange={setTab}>
        <TabsList className="mb-6">
          <TabsTrigger value="items"><Coffee size={14} /> Items ({items.length})</TabsTrigger>
          <TabsTrigger value="categories"><Tag size={14} /> Categories ({cats.length})</TabsTrigger>
          <TabsTrigger value="addons"><Package size={14} /> Addons ({addons.length})</TabsTrigger>
        </TabsList>

        {/* Items tab */}
        <TabsContent value="items">
          <div className="mb-4 flex items-center gap-3 flex-wrap">
            <Select value={selCat ?? "all"} onValueChange={(v) => setSelCat(v === "all" ? null : v)}>
              <SelectTrigger className="w-48 h-9"><SelectValue placeholder="All categories" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All categories</SelectItem>
                {cats.map((c) => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button size="sm" className="ml-auto" onClick={() => openItemDialog()}>
              <Plus size={14} /> Add Item
            </Button>
          </div>
          {itemsLoading
            ? <div className="space-y-2">{Array.from({length:5}).map((_,i) => <Skeleton key={i} className="h-14 rounded-xl" />)}</div>
            : <DataTable data={items} columns={itemCols} searchPlaceholder="Search items..." onRowClick={openItemDialog} />
          }
        </TabsContent>

        {/* Categories tab */}
        <TabsContent value="categories">
          <div className="mb-4 flex justify-end">
            <Button size="sm" onClick={() => openCatDialog()}><Plus size={14} /> Add Category</Button>
          </div>
          {catsLoading
            ? <div className="space-y-2">{Array.from({length:4}).map((_,i) => <Skeleton key={i} className="h-12 rounded-xl" />)}</div>
            : <DataTable data={cats} columns={catCols} searchPlaceholder="Search categories..." />
          }
        </TabsContent>

        {/* Addons tab */}
        <TabsContent value="addons">
          <div className="mb-4 flex items-center gap-3 flex-wrap">
            <Select value={selAddonType ?? "all"} onValueChange={(v) => setSelAddonType(v === "all" ? null : v)}>
              <SelectTrigger className="w-44 h-9"><SelectValue placeholder="All types" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All types</SelectItem>
                {Object.entries(ADDON_TYPE_LABELS).map(([k, v]) => <SelectItem key={k} value={k}>{v}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button size="sm" className="ml-auto" onClick={() => openAddonDialog()}>
              <Plus size={14} /> Add Addon
            </Button>
          </div>
          {addonsLoading
            ? <div className="space-y-2">{Array.from({length:5}).map((_,i) => <Skeleton key={i} className="h-12 rounded-xl" />)}</div>
            : <DataTable data={addons} columns={addonCols} searchPlaceholder="Search addons..." />
          }
        </TabsContent>
      </Tabs>

      {/* Category dialog */}
      <Dialog open={catDialog} onOpenChange={setCatDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editCat ? "Edit Category" : "New Category"}</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Name</Label>
              <Input value={catForm.name} onChange={(e) => setCatForm((f) => ({ ...f, name: e.target.value }))} placeholder="e.g. Hot Drinks" />
            </div>
            <div className="space-y-1.5">
              <Label>Display Order</Label>
              <Input type="number" value={catForm.display_order} onChange={(e) => setCatForm((f) => ({ ...f, display_order: e.target.value }))} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCatDialog(false)}>Cancel</Button>
            <Button loading={catMutation.isPending} onClick={() => catMutation.mutate()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Item dialog */}
      <Dialog open={itemDialog} onOpenChange={setItemDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editItem ? "Edit Item" : "New Item"}</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Name</Label>
              <Input value={itemForm.name} onChange={(e) => setItemForm((f) => ({ ...f, name: e.target.value }))} placeholder="e.g. Latte" />
            </div>
            <div className="space-y-1.5">
              <Label>Description</Label>
              <Input value={itemForm.description} onChange={(e) => setItemForm((f) => ({ ...f, description: e.target.value }))} placeholder="Optional" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label>Price (EGP)</Label>
                <Input type="number" step="0.5" value={itemForm.base_price} onChange={(e) => setItemForm((f) => ({ ...f, base_price: e.target.value }))} placeholder="0.00" />
              </div>
              <div className="space-y-1.5">
                <Label>Category</Label>
                <Select value={itemForm.category_id || "none"} onValueChange={(v) => setItemForm((f) => ({ ...f, category_id: v === "none" ? "" : v }))}>
                  <SelectTrigger><SelectValue placeholder="None" /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">No category</SelectItem>
                    {cats.map((c) => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Switch checked={itemForm.is_active} onCheckedChange={(v) => setItemForm((f) => ({ ...f, is_active: v }))} />
              <Label>Active</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setItemDialog(false)}>Cancel</Button>
            <Button loading={itemMutation.isPending} onClick={() => itemMutation.mutate()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Addon dialog */}
      <Dialog open={addonDialog} onOpenChange={setAddonDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editAddon ? "Edit Addon" : "New Addon"}</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Name</Label>
              <Input value={addonForm.name} onChange={(e) => setAddonForm((f) => ({ ...f, name: e.target.value }))} placeholder="e.g. Oat Milk" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label>Type</Label>
                <Select value={addonForm.addon_type} onValueChange={(v) => setAddonForm((f) => ({ ...f, addon_type: v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {Object.entries(ADDON_TYPE_LABELS).map(([k, v]) => <SelectItem key={k} value={k}>{v}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label>Default Price (EGP)</Label>
                <Input type="number" step="0.5" value={addonForm.default_price} onChange={(e) => setAddonForm((f) => ({ ...f, default_price: e.target.value }))} placeholder="0.00" />
              </div>
            </div>
            <div className="space-y-1.5">
              <Label>Display Order</Label>
              <Input type="number" value={addonForm.display_order} onChange={(e) => setAddonForm((f) => ({ ...f, display_order: e.target.value }))} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAddonDialog(false)}>Cancel</Button>
            <Button loading={addonMutation.isPending} onClick={() => addonMutation.mutate()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
TSX
ok "Menu page"

# ===========================================================================
#  PART 4B — RECIPES PAGE
# ===========================================================================
log "Writing Recipes page..."

cat > src/pages/recipes/Recipes.tsx << 'TSX'
import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Plus, Trash2, BookOpen, Coffee, Package } from "lucide-react";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as menuApi from "@/api/menu";
import * as recipesApi from "@/api/recipes";
import * as inventoryApi from "@/api/inventory";
import type { MenuItem, DrinkRecipe, AddonItem, AddonIngredient } from "@/types";
import { egp, fmtUnit, SIZE_LABELS } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";

function RecipeRow({ recipe, onDelete }: { recipe: DrinkRecipe; onDelete: () => void }) {
  return (
    <div className="flex items-center gap-3 py-2 px-3 rounded-lg hover:bg-muted/50 group">
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium">{recipe.inventory_item_name}</p>
        <p className="text-xs text-muted-foreground">{recipe.quantity_used} {fmtUnit(recipe.unit)} · {SIZE_LABELS[recipe.size_label] ?? recipe.size_label}</p>
      </div>
      <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100 text-destructive" onClick={onDelete}>
        <Trash2 size={13} />
      </Button>
    </div>
  );
}

function DrinkRecipePanel({ item, branchId }: { item: MenuItem; branchId: string }) {
  const qc = useQueryClient();
  const { data: recipes = [], isLoading } = useQuery({
    queryKey: ["drink-recipes", item.id],
    queryFn:  () => recipesApi.getDrinkRecipes(item.id).then((r) => r.data),
  });
  const { data: invItems = [] } = useQuery({
    queryKey: ["inventory-items", branchId],
    queryFn:  () => inventoryApi.getInventoryItems(branchId).then((r) => r.data),
    enabled:  !!branchId,
  });

  const [form, setForm] = useState({ size_label: "medium", inventory_item_id: "", quantity_used: "" });

  const addMutation = useMutation({
    mutationFn: () => recipesApi.upsertDrinkRecipe(item.id, {
      size_label:        form.size_label,
      inventory_item_id: form.inventory_item_id,
      quantity_used:     parseFloat(form.quantity_used),
    }),
    onSuccess: () => { toast.success("Recipe saved"); qc.invalidateQueries({ queryKey: ["drink-recipes", item.id] }); setForm((f) => ({...f, quantity_used: ""})); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const delMutation = useMutation({
    mutationFn: ({ size, invId }: { size: string; invId: string }) =>
      recipesApi.deleteDrinkRecipe(item.id, size, invId),
    onSuccess: () => { toast.success("Removed"); qc.invalidateQueries({ queryKey: ["drink-recipes", item.id] }); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const sizes = Object.entries(SIZE_LABELS);

  return (
    <div className="p-4 space-y-4">
      <div className="space-y-1">
        {isLoading
          ? <Skeleton className="h-20" />
          : recipes.length === 0
            ? <p className="text-sm text-muted-foreground py-4 text-center">No ingredients yet</p>
            : recipes.map((r) => (
                <RecipeRow key={`${r.size_label}-${r.inventory_item_id}`} recipe={r}
                  onDelete={() => delMutation.mutate({ size: r.size_label, invId: r.inventory_item_id })} />
              ))
        }
      </div>
      <Separator />
      <div className="grid grid-cols-2 gap-2">
        <div className="space-y-1">
          <Label>Size</Label>
          <Select value={form.size_label} onValueChange={(v) => setForm((f) => ({...f, size_label: v}))}>
            <SelectTrigger className="h-8 text-xs"><SelectValue /></SelectTrigger>
            <SelectContent>{sizes.map(([k,v]) => <SelectItem key={k} value={k}>{v}</SelectItem>)}</SelectContent>
          </Select>
        </div>
        <div className="space-y-1">
          <Label>Qty</Label>
          <Input className="h-8 text-xs" type="number" step="0.1" placeholder="e.g. 200" value={form.quantity_used}
            onChange={(e) => setForm((f) => ({...f, quantity_used: e.target.value}))} />
        </div>
        <div className="col-span-2 space-y-1">
          <Label>Ingredient</Label>
          <Select value={form.inventory_item_id} onValueChange={(v) => setForm((f) => ({...f, inventory_item_id: v}))}>
            <SelectTrigger className="h-8 text-xs"><SelectValue placeholder="Select ingredient…" /></SelectTrigger>
            <SelectContent>
              {invItems.map((i) => <SelectItem key={i.id} value={i.id}>{i.name} ({fmtUnit(i.unit)})</SelectItem>)}
            </SelectContent>
          </Select>
        </div>
        <div className="col-span-2">
          <Button size="sm" className="w-full" loading={addMutation.isPending}
            disabled={!form.inventory_item_id || !form.quantity_used}
            onClick={() => addMutation.mutate()}>
            <Plus size={13} /> Add Ingredient
          </Button>
        </div>
      </div>
    </div>
  );
}

function AddonRecipePanel({ addon, branchId }: { addon: AddonItem; branchId: string }) {
  const qc = useQueryClient();
  const { data: ingredients = [], isLoading } = useQuery({
    queryKey: ["addon-ingredients", addon.id],
    queryFn:  () => recipesApi.getAddonIngredients(addon.id).then((r) => r.data),
  });
  const { data: invItems = [] } = useQuery({
    queryKey: ["inventory-items", branchId],
    queryFn:  () => inventoryApi.getInventoryItems(branchId).then((r) => r.data),
    enabled:  !!branchId,
  });

  const [form, setForm] = useState({ inventory_item_id: "", quantity_used: "" });

  const addMutation = useMutation({
    mutationFn: () => recipesApi.upsertAddonIngredient(addon.id, {
      inventory_item_id: form.inventory_item_id,
      quantity_used:     parseFloat(form.quantity_used),
    }),
    onSuccess: () => { toast.success("Saved"); qc.invalidateQueries({ queryKey: ["addon-ingredients", addon.id] }); setForm((f) => ({...f, quantity_used:""})); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const delMutation = useMutation({
    mutationFn: (invId: string) => recipesApi.deleteAddonIngredient(addon.id, invId),
    onSuccess: () => { toast.success("Removed"); qc.invalidateQueries({ queryKey: ["addon-ingredients", addon.id] }); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  return (
    <div className="p-4 space-y-4">
      <div className="space-y-1">
        {isLoading ? <Skeleton className="h-16" />
          : ingredients.length === 0
            ? <p className="text-sm text-muted-foreground py-4 text-center">No ingredients</p>
            : ingredients.map((r) => (
                <div key={r.inventory_item_id} className="flex items-center gap-3 py-2 px-3 rounded-lg hover:bg-muted/50 group">
                  <div className="flex-1"><p className="text-sm font-medium">{r.inventory_item_name}</p>
                    <p className="text-xs text-muted-foreground">{r.quantity_used} {fmtUnit(r.unit)}</p>
                  </div>
                  <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100 text-destructive"
                    onClick={() => delMutation.mutate(r.inventory_item_id)}><Trash2 size={13} /></Button>
                </div>
              ))
        }
      </div>
      <Separator />
      <div className="space-y-2">
        <div className="space-y-1">
          <Label>Ingredient</Label>
          <Select value={form.inventory_item_id} onValueChange={(v) => setForm((f) => ({...f, inventory_item_id: v}))}>
            <SelectTrigger className="h-8 text-xs"><SelectValue placeholder="Select…" /></SelectTrigger>
            <SelectContent>{invItems.map((i) => <SelectItem key={i.id} value={i.id}>{i.name} ({fmtUnit(i.unit)})</SelectItem>)}</SelectContent>
          </Select>
        </div>
        <div className="space-y-1">
          <Label>Quantity</Label>
          <Input className="h-8 text-xs" type="number" step="0.1" placeholder="e.g. 30" value={form.quantity_used}
            onChange={(e) => setForm((f) => ({...f, quantity_used: e.target.value}))} />
        </div>
        <Button size="sm" className="w-full" loading={addMutation.isPending}
          disabled={!form.inventory_item_id || !form.quantity_used} onClick={() => addMutation.mutate()}>
          <Plus size={13} /> Add
        </Button>
      </div>
    </div>
  );
}

export default function Recipes() {
  const user    = useAuthStore((s) => s.user);
  const orgId   = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const branchId = useAppStore((s) => s.selectedBranchId) ?? "";
  const [tab, setTab] = useState("drinks");
  const [selItem,  setSelItem]  = useState<MenuItem | null>(null);
  const [selAddon, setSelAddon] = useState<AddonItem | null>(null);

  const { data: items  = [], isLoading: itemsLoading  } = useQuery({
    queryKey: ["menu-items", orgId],
    queryFn:  () => menuApi.getMenuItems(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });
  const { data: addons = [], isLoading: addonsLoading } = useQuery({
    queryKey: ["addon-items", orgId],
    queryFn:  () => menuApi.getAddonItems(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader title="Recipes" sub="Configure ingredient deductions per drink and addon" />

      <Tabs value={tab} onValueChange={(v) => { setTab(v); setSelItem(null); setSelAddon(null); }}>
        <TabsList className="mb-6">
          <TabsTrigger value="drinks"><Coffee size={14} /> Drinks ({items.length})</TabsTrigger>
          <TabsTrigger value="addons"><Package size={14} /> Addons ({addons.length})</TabsTrigger>
        </TabsList>

        <TabsContent value="drinks">
          <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-4">
            {/* Item list */}
            <div className="rounded-2xl border overflow-hidden">
              <div className="p-3 border-b bg-muted/30">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Menu Items</p>
              </div>
              <ScrollArea className="h-[500px]">
                {itemsLoading ? <div className="p-3 space-y-2">{Array.from({length:6}).map((_,i)=><Skeleton key={i} className="h-10"/>)}</div>
                  : items.map((item) => (
                    <button key={item.id} onClick={() => setSelItem(item)}
                      className={`w-full text-left px-4 py-3 border-b border-border/50 hover:bg-muted/40 transition-colors ${selItem?.id === item.id ? "bg-accent" : ""}`}>
                      <p className="text-sm font-medium">{item.name}</p>
                      <p className="text-xs text-muted-foreground">{egp(item.base_price)}</p>
                    </button>
                  ))
                }
              </ScrollArea>
            </div>
            {/* Recipe panel */}
            <div className="rounded-2xl border overflow-hidden">
              {selItem ? (
                <>
                  <div className="p-4 border-b bg-muted/30 flex items-center justify-between">
                    <div>
                      <p className="font-semibold">{selItem.name}</p>
                      <p className="text-xs text-muted-foreground">Ingredient deductions per size</p>
                    </div>
                    <Badge variant="info">{egp(selItem.base_price)}</Badge>
                  </div>
                  <DrinkRecipePanel item={selItem} branchId={branchId} />
                </>
              ) : (
                <EmptyState icon={BookOpen} title="Select a drink" sub="Choose a menu item to configure its recipe" className="h-[500px]" />
              )}
            </div>
          </div>
        </TabsContent>

        <TabsContent value="addons">
          <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-4">
            <div className="rounded-2xl border overflow-hidden">
              <div className="p-3 border-b bg-muted/30">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Addon Items</p>
              </div>
              <ScrollArea className="h-[500px]">
                {addonsLoading ? <div className="p-3 space-y-2">{Array.from({length:6}).map((_,i)=><Skeleton key={i} className="h-10"/>)}</div>
                  : addons.map((addon) => (
                    <button key={addon.id} onClick={() => setSelAddon(addon)}
                      className={`w-full text-left px-4 py-3 border-b border-border/50 hover:bg-muted/40 transition-colors ${selAddon?.id === addon.id ? "bg-accent" : ""}`}>
                      <p className="text-sm font-medium">{addon.name}</p>
                      <p className="text-xs text-muted-foreground">{egp(addon.default_price)}</p>
                    </button>
                  ))
                }
              </ScrollArea>
            </div>
            <div className="rounded-2xl border overflow-hidden">
              {selAddon ? (
                <>
                  <div className="p-4 border-b bg-muted/30">
                    <p className="font-semibold">{selAddon.name}</p>
                    <p className="text-xs text-muted-foreground">Ingredient deductions</p>
                  </div>
                  <AddonRecipePanel addon={selAddon} branchId={branchId} />
                </>
              ) : (
                <EmptyState icon={Package} title="Select an addon" sub="Choose an addon to configure its ingredients" className="h-[500px]" />
              )}
            </div>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}
TSX
ok "Recipes page"

# ===========================================================================
#  PART 5 — INVENTORY PAGE
# ===========================================================================
log "Writing Inventory page..."

cat > src/pages/inventory/Inventory.tsx << 'TSX'
import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Plus, Pencil, ArrowRightLeft, AlertTriangle, Package } from "lucide-react";
import { type ColumnDef } from "@tanstack/react-table";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as inventoryApi from "@/api/inventory";
import * as branchesApi from "@/api/branches";
import type { InventoryItem, InventoryAdjustment, InventoryTransfer } from "@/types";
import { egp, fmtDateTime, fmtUnit, UNIT_LABELS } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { DataTable } from "@/components/shared/DataTable";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";

export default function Inventory() {
  const user     = useAuthStore((s) => s.user);
  const orgId    = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const branchId = useAppStore((s) => s.selectedBranchId) ?? "";
  const qc       = useQueryClient();
  const [tab, setTab] = useState("stock");

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => branchesApi.getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const activeBranch = branches.find((b) => b.id === branchId) ?? branches[0];

  const { data: items = [], isLoading: stockLoading } = useQuery({
    queryKey: ["inventory-items", activeBranch?.id],
    queryFn:  () => inventoryApi.getInventoryItems(activeBranch!.id).then((r) => r.data),
    enabled:  !!activeBranch?.id,
  });

  const { data: adjustments = [], isLoading: adjLoading } = useQuery({
    queryKey: ["adjustments", activeBranch?.id],
    queryFn:  () => inventoryApi.getAdjustments(activeBranch!.id).then((r) => r.data),
    enabled:  !!activeBranch?.id,
  });

  const { data: transfers = [], isLoading: transLoading } = useQuery({
    queryKey: ["transfers", activeBranch?.id],
    queryFn:  () => inventoryApi.getTransfers(activeBranch!.id).then((r) => r.data),
    enabled:  !!activeBranch?.id,
  });

  const lowStock = items.filter((i) => i.current_stock <= i.reorder_threshold);

  // ── Item dialog ───────────────────────────────────────────────
  const [itemDialog, setItemDialog] = useState(false);
  const [editItem, setEditItem]     = useState<InventoryItem | null>(null);
  const [itemForm, setItemForm]     = useState({
    name: "", unit: "g", current_stock: "", reorder_threshold: "", cost_per_unit: "", is_active: true,
  });

  const openItemDialog = (item?: InventoryItem) => {
    setEditItem(item ?? null);
    setItemForm({
      name:              item?.name ?? "",
      unit:              item?.unit ?? "g",
      current_stock:     item ? String(item.current_stock) : "",
      reorder_threshold: item ? String(item.reorder_threshold) : "",
      cost_per_unit:     item?.cost_per_unit ? String(item.cost_per_unit) : "",
      is_active:         item?.is_active ?? true,
    });
    setItemDialog(true);
  };

  const itemMutation = useMutation({
    mutationFn: () => {
      const payload = {
        name:              itemForm.name,
        unit:              itemForm.unit,
        current_stock:     parseFloat(itemForm.current_stock),
        reorder_threshold: parseFloat(itemForm.reorder_threshold),
        cost_per_unit:     itemForm.cost_per_unit ? parseFloat(itemForm.cost_per_unit) : null,
        is_active:         itemForm.is_active,
      };
      return editItem
        ? inventoryApi.updateInventoryItem(editItem.id, payload)
        : inventoryApi.createInventoryItem(activeBranch!.id, payload);
    },
    onSuccess: () => {
      toast.success(editItem ? "Item updated" : "Item created");
      qc.invalidateQueries({ queryKey: ["inventory-items"] });
      setItemDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Adjustment dialog ─────────────────────────────────────────
  const [adjDialog, setAdjDialog] = useState(false);
  const [adjForm, setAdjForm]     = useState({ inventory_item_id: "", adjustment_type: "add", quantity: "", note: "" });

  const adjMutation = useMutation({
    mutationFn: () => inventoryApi.createAdjustment(activeBranch!.id, {
      inventory_item_id: adjForm.inventory_item_id,
      adjustment_type:   adjForm.adjustment_type,
      quantity:          parseFloat(adjForm.quantity),
      note:              adjForm.note || null,
    }),
    onSuccess: () => {
      toast.success("Adjustment recorded");
      qc.invalidateQueries({ queryKey: ["inventory-items"] });
      qc.invalidateQueries({ queryKey: ["adjustments"] });
      setAdjDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Transfer dialog ───────────────────────────────────────────
  const [transDialog, setTransDialog] = useState(false);
  const [transForm, setTransForm]     = useState({ destination_branch_id: "", inventory_item_id: "", quantity_sent: "", note: "" });

  const transMutation = useMutation({
    mutationFn: () => inventoryApi.createTransfer({
      source_branch_id:      activeBranch!.id,
      destination_branch_id: transForm.destination_branch_id,
      inventory_item_id:     transForm.inventory_item_id,
      quantity_sent:         parseFloat(transForm.quantity_sent),
      note:                  transForm.note || null,
    }),
    onSuccess: () => {
      toast.success("Transfer initiated");
      qc.invalidateQueries({ queryKey: ["transfers"] });
      setTransDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Table columns ─────────────────────────────────────────────
  const stockCols: ColumnDef<InventoryItem, any>[] = [
    { accessorKey: "name", header: "Item",
      cell: ({ row }) => (
        <div className="flex items-center gap-2">
          {row.original.current_stock <= row.original.reorder_threshold && (
            <AlertTriangle size={13} className="text-amber-500 flex-shrink-0" />
          )}
          <span className="font-semibold text-sm">{row.original.name}</span>
        </div>
      ),
    },
    { accessorKey: "unit", header: "Unit", cell: ({ row }) => <Badge variant="outline">{fmtUnit(row.original.unit)}</Badge> },
    { accessorKey: "current_stock", header: "Stock",
      cell: ({ row }) => {
        const pct = Math.min(100, (row.original.current_stock / Math.max(row.original.reorder_threshold * 2, 1)) * 100);
        const low = row.original.current_stock <= row.original.reorder_threshold;
        return (
          <div className="flex items-center gap-2 min-w-[120px]">
            <Progress value={pct} className={`h-1.5 flex-1 ${low ? "[&>div]:bg-amber-500" : ""}`} />
            <span className={`text-xs tabular-nums font-semibold ${low ? "text-amber-600" : ""}`}>
              {row.original.current_stock} {fmtUnit(row.original.unit)}
            </span>
          </div>
        );
      },
    },
    { accessorKey: "reorder_threshold", header: "Reorder",
      cell: ({ row }) => <span className="text-xs text-muted-foreground">{row.original.reorder_threshold} {fmtUnit(row.original.unit)}</span>,
    },
    { accessorKey: "cost_per_unit", header: "Cost/Unit",
      cell: ({ row }) => row.original.cost_per_unit
        ? <span className="text-xs tabular-nums">{egp(row.original.cost_per_unit * 100)}</span>
        : <span className="text-muted-foreground text-xs">—</span>,
    },
    { accessorKey: "is_active", header: "Active",
      cell: ({ row }) => <Badge variant={row.original.is_active ? "success" : "outline"}>{row.original.is_active ? "Active" : "Off"}</Badge>,
    },
    { id: "actions", header: "",
      cell: ({ row }) => (
        <Button variant="ghost" size="icon-sm" onClick={(e) => { e.stopPropagation(); openItemDialog(row.original); }}>
          <Pencil size={13} />
        </Button>
      ),
    },
  ];

  const adjCols: ColumnDef<InventoryAdjustment, any>[] = [
    { accessorKey: "item_name", header: "Item", cell: ({ row }) => <span className="font-semibold text-sm">{row.original.item_name}</span> },
    { accessorKey: "adjustment_type", header: "Type",
      cell: ({ row }) => (
        <Badge variant={row.original.adjustment_type === "add" ? "success" : "warning"}>
          {row.original.adjustment_type.replace("_", " ")}
        </Badge>
      ),
    },
    { accessorKey: "quantity", header: "Qty",
      cell: ({ row }) => <span className="tabular-nums text-sm">{row.original.quantity} {fmtUnit(row.original.unit)}</span>,
    },
    { accessorKey: "note", header: "Note", cell: ({ row }) => <span className="text-xs text-muted-foreground">{row.original.note ?? "—"}</span> },
    { accessorKey: "adjusted_by_name", header: "By", cell: ({ row }) => <span className="text-xs">{row.original.adjusted_by_name}</span> },
    { accessorKey: "created_at", header: "Date", cell: ({ row }) => <span className="text-xs text-muted-foreground">{fmtDateTime(row.original.created_at)}</span> },
  ];

  const STATUS_VARIANT: Record<string, any> = { pending: "warning", completed: "success", partial: "info", rejected: "destructive" };
  const transCols: ColumnDef<InventoryTransfer, any>[] = [
    { accessorKey: "item_name", header: "Item", cell: ({ row }) => <span className="font-semibold text-sm">{row.original.item_name}</span> },
    { accessorKey: "source_branch_name",      header: "From", cell: ({ row }) => <span className="text-xs">{row.original.source_branch_name}</span> },
    { accessorKey: "destination_branch_name", header: "To",   cell: ({ row }) => <span className="text-xs">{row.original.destination_branch_name}</span> },
    { accessorKey: "quantity_sent", header: "Qty",
      cell: ({ row }) => <span className="tabular-nums text-sm">{row.original.quantity_sent} {fmtUnit(row.original.unit)}</span>,
    },
    { accessorKey: "status", header: "Status",
      cell: ({ row }) => <Badge variant={STATUS_VARIANT[row.original.status]}>{row.original.status}</Badge>,
    },
    { accessorKey: "initiated_at", header: "Date", cell: ({ row }) => <span className="text-xs text-muted-foreground">{fmtDateTime(row.original.initiated_at)}</span> },
  ];

  if (!activeBranch) return (
    <div className="p-6 lg:p-8"><EmptyState icon={Package} title="No branch selected" sub="Select a branch from the sidebar to view inventory" /></div>
  );

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader
        title="Inventory"
        sub={`${activeBranch.name} · ${items.length} items${lowStock.length > 0 ? ` · ${lowStock.length} low stock` : ""}`}
        actions={
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={() => setAdjDialog(true)}>
              <Plus size={13} /> Adjustment
            </Button>
            <Button variant="outline" size="sm" onClick={() => setTransDialog(true)}>
              <ArrowRightLeft size={13} /> Transfer
            </Button>
            <Button size="sm" onClick={() => openItemDialog()}>
              <Plus size={13} /> Add Item
            </Button>
          </div>
        }
      />

      {/* Low stock banner */}
      {lowStock.length > 0 && (
        <div className="mb-4 flex items-center gap-3 bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800 rounded-xl px-4 py-3">
          <AlertTriangle size={16} className="text-amber-500 flex-shrink-0" />
          <p className="text-sm font-medium text-amber-800 dark:text-amber-200">
            {lowStock.length} item{lowStock.length > 1 ? "s" : ""} below reorder threshold:{" "}
            <span className="font-bold">{lowStock.map((i) => i.name).join(", ")}</span>
          </p>
        </div>
      )}

      <Tabs value={tab} onValueChange={setTab}>
        <TabsList className="mb-6">
          <TabsTrigger value="stock">
            Stock ({items.length})
            {lowStock.length > 0 && <Badge variant="warning" className="ml-1 h-4 text-[10px]">{lowStock.length}</Badge>}
          </TabsTrigger>
          <TabsTrigger value="adjustments">Adjustments ({adjustments.length})</TabsTrigger>
          <TabsTrigger value="transfers">Transfers ({transfers.length})</TabsTrigger>
        </TabsList>

        <TabsContent value="stock">
          {stockLoading
            ? <div className="space-y-2">{Array.from({length:6}).map((_,i)=><Skeleton key={i} className="h-14 rounded-xl"/>)}</div>
            : <DataTable data={items} columns={stockCols} searchPlaceholder="Search items..." onRowClick={openItemDialog} />
          }
        </TabsContent>

        <TabsContent value="adjustments">
          {adjLoading
            ? <div className="space-y-2">{Array.from({length:5}).map((_,i)=><Skeleton key={i} className="h-12 rounded-xl"/>)}</div>
            : <DataTable data={adjustments} columns={adjCols} searchPlaceholder="Search adjustments..." />
          }
        </TabsContent>

        <TabsContent value="transfers">
          {transLoading
            ? <div className="space-y-2">{Array.from({length:5}).map((_,i)=><Skeleton key={i} className="h-12 rounded-xl"/>)}</div>
            : <DataTable data={transfers} columns={transCols} searchPlaceholder="Search transfers..." />
          }
        </TabsContent>
      </Tabs>

      {/* Item dialog */}
      <Dialog open={itemDialog} onOpenChange={setItemDialog}>
        <DialogContent>
          <DialogHeader><DialogTitle>{editItem ? "Edit Item" : "New Inventory Item"}</DialogTitle></DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5"><Label>Name</Label>
              <Input value={itemForm.name} onChange={(e) => setItemForm((f)=>({...f,name:e.target.value}))} placeholder="e.g. Whole Milk" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5"><Label>Unit</Label>
                <Select value={itemForm.unit} onValueChange={(v)=>setItemForm((f)=>({...f,unit:v}))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>{Object.entries(UNIT_LABELS).map(([k,v])=><SelectItem key={k} value={k}>{v}</SelectItem>)}</SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5"><Label>Current Stock</Label>
                <Input type="number" step="0.1" value={itemForm.current_stock} onChange={(e)=>setItemForm((f)=>({...f,current_stock:e.target.value}))} placeholder="0" />
              </div>
              <div className="space-y-1.5"><Label>Reorder Threshold</Label>
                <Input type="number" step="0.1" value={itemForm.reorder_threshold} onChange={(e)=>setItemForm((f)=>({...f,reorder_threshold:e.target.value}))} placeholder="0" />
              </div>
              <div className="space-y-1.5"><Label>Cost per Unit (EGP)</Label>
                <Input type="number" step="0.01" value={itemForm.cost_per_unit} onChange={(e)=>setItemForm((f)=>({...f,cost_per_unit:e.target.value}))} placeholder="Optional" />
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Switch checked={itemForm.is_active} onCheckedChange={(v)=>setItemForm((f)=>({...f,is_active:v}))} />
              <Label>Active</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={()=>setItemDialog(false)}>Cancel</Button>
            <Button loading={itemMutation.isPending} onClick={()=>itemMutation.mutate()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Adjustment dialog */}
      <Dialog open={adjDialog} onOpenChange={setAdjDialog}>
        <DialogContent>
          <DialogHeader><DialogTitle>Stock Adjustment</DialogTitle></DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5"><Label>Item</Label>
              <Select value={adjForm.inventory_item_id} onValueChange={(v)=>setAdjForm((f)=>({...f,inventory_item_id:v}))}>
                <SelectTrigger><SelectValue placeholder="Select item…" /></SelectTrigger>
                <SelectContent>{items.map((i)=><SelectItem key={i.id} value={i.id}>{i.name} ({fmtUnit(i.unit)})</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5"><Label>Type</Label>
                <Select value={adjForm.adjustment_type} onValueChange={(v)=>setAdjForm((f)=>({...f,adjustment_type:v}))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="add">Add stock</SelectItem>
                    <SelectItem value="remove">Remove stock</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5"><Label>Quantity</Label>
                <Input type="number" step="0.1" value={adjForm.quantity} onChange={(e)=>setAdjForm((f)=>({...f,quantity:e.target.value}))} placeholder="0" />
              </div>
            </div>
            <div className="space-y-1.5"><Label>Note (optional)</Label>
              <Input value={adjForm.note} onChange={(e)=>setAdjForm((f)=>({...f,note:e.target.value}))} placeholder="Reason for adjustment" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={()=>setAdjDialog(false)}>Cancel</Button>
            <Button loading={adjMutation.isPending} onClick={()=>adjMutation.mutate()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Transfer dialog */}
      <Dialog open={transDialog} onOpenChange={setTransDialog}>
        <DialogContent>
          <DialogHeader><DialogTitle>Create Transfer</DialogTitle></DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5"><Label>Item</Label>
              <Select value={transForm.inventory_item_id} onValueChange={(v)=>setTransForm((f)=>({...f,inventory_item_id:v}))}>
                <SelectTrigger><SelectValue placeholder="Select item…" /></SelectTrigger>
                <SelectContent>{items.map((i)=><SelectItem key={i.id} value={i.id}>{i.name} ({fmtUnit(i.unit)})</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5"><Label>Destination Branch</Label>
              <Select value={transForm.destination_branch_id} onValueChange={(v)=>setTransForm((f)=>({...f,destination_branch_id:v}))}>
                <SelectTrigger><SelectValue placeholder="Select branch…" /></SelectTrigger>
                <SelectContent>
                  {branches.filter((b)=>b.id!==activeBranch.id).map((b)=><SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5"><Label>Quantity</Label>
              <Input type="number" step="0.1" value={transForm.quantity_sent} onChange={(e)=>setTransForm((f)=>({...f,quantity_sent:e.target.value}))} placeholder="0" />
            </div>
            <div className="space-y-1.5"><Label>Note (optional)</Label>
              <Input value={transForm.note} onChange={(e)=>setTransForm((f)=>({...f,note:e.target.value}))} placeholder="Optional note" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={()=>setTransDialog(false)}>Cancel</Button>
            <Button loading={transMutation.isPending} onClick={()=>transMutation.mutate()}>Send</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
TSX
ok "Inventory page"

# ===========================================================================
#  PART 6 — SHIFTS PAGE + SHIFT REPORT
# ===========================================================================
log "Writing Shifts page and Shift Report..."

cat > src/pages/shifts/Shifts.tsx << 'TSX'
import React, { useState, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  Clock, Plus, Printer, X, ChevronRight, ArrowDownLeft,
  ArrowUpRight, AlertCircle, DollarSign, FileText, CheckCircle,
} from "lucide-react";
import { type ColumnDef } from "@tanstack/react-table";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as shiftsApi from "@/api/shifts";
import * as branchesApi from "@/api/branches";
import * as reportsApi from "@/api/reports";
import type { Shift, ShiftReport, CashMovementSummaryRow } from "@/types";
import {
  egp, fmtDateTime, fmtDuration, fmtPayment,
  PAYMENT_COLORS, SHIFT_STATUS_COLORS, SHIFT_STATUS_LABELS,
} from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from "@/components/ui/dialog";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { ScrollArea } from "@/components/ui/scroll-area";
import { DataTable } from "@/components/shared/DataTable";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { StatCard } from "@/components/shared/StatCard";
import { getErrorMessage } from "@/lib/client";

// ── Shift Report Component ───────────────────────────────────────────────────
function ShiftReportView({ shiftId, onClose }: { shiftId: string; onClose: () => void }) {
  const printRef = useRef<HTMLDivElement>(null);

  const { data: report, isLoading } = useQuery({
    queryKey: ["shift-report", shiftId],
    queryFn:  () => shiftsApi.getShiftReport(shiftId).then((r) => r.data),
  });

  const handlePrint = () => {
    const el = printRef.current;
    if (!el) return;
    const w = window.open("", "_blank");
    if (!w) return;
    w.document.write(`
      <html><head>
        <title>Shift Report</title>
        <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700&display=swap" rel="stylesheet">
        <style>
          * { font-family: Cairo, sans-serif; margin: 0; padding: 0; box-sizing: border-box; }
          body { padding: 20px; color: #111; font-size: 13px; max-width: 380px; margin: 0 auto; }
          h1 { font-size: 18px; font-weight: 700; text-align: center; margin-bottom: 4px; }
          h2 { font-size: 11px; text-transform: uppercase; letter-spacing: 0.1em; color: #666; text-align: center; margin-bottom: 16px; }
          .row { display: flex; justify-content: space-between; padding: 4px 0; font-size: 12px; }
          .row.bold { font-weight: 700; font-size: 13px; }
          .row.total { border-top: 2px solid #111; margin-top: 4px; padding-top: 8px; font-size: 14px; font-weight: 700; }
          .section { margin-bottom: 16px; }
          .section-title { font-size: 10px; text-transform: uppercase; letter-spacing: 0.1em; color: #666; border-bottom: 1px solid #ddd; padding-bottom: 4px; margin-bottom: 8px; }
          .discrepancy-neg { color: #dc2626; }
          .discrepancy-pos { color: #16a34a; }
          hr { border: none; border-top: 1px dashed #ddd; margin: 12px 0; }
        </style>
      </head><body>${el.innerHTML}</body></html>
    `);
    w.document.close();
    w.focus();
    setTimeout(() => { w.print(); w.close(); }, 400);
  };

  if (isLoading) return (
    <div className="p-6 space-y-3">
      {Array.from({length:6}).map((_,i)=><Skeleton key={i} className="h-8 rounded-xl"/>)}
    </div>
  );

  if (!report) return <EmptyState icon={FileText} title="Report unavailable" className="h-64" />;

  const { shift, payment_summary, cash_movements, cash_movements_in, cash_movements_out, cash_movements_net, total_payments, net_payments } = report;
  const discrepancy = shift.cash_discrepancy ?? 0;

  return (
    <div className="flex flex-col h-full max-h-[85vh]">
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b flex-shrink-0">
        <div>
          <h2 className="font-bold">Shift Report</h2>
          <p className="text-xs text-muted-foreground">{shift.teller_name} · {fmtDateTime(shift.opened_at)}</p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={handlePrint}>
            <Printer size={13} /> Print
          </Button>
          <Button variant="ghost" size="icon-sm" onClick={onClose}><X size={16} /></Button>
        </div>
      </div>

      <ScrollArea className="flex-1">
        {/* Printable content */}
        <div ref={printRef} className="p-6 space-y-6">
          {/* Print header (hidden on screen) */}
          <div className="hidden print:block text-center mb-6">
            <h1>The Rue</h1>
            <h2>Shift Report</h2>
          </div>

          {/* KPIs */}
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <StatCard title="Total Revenue"  value={egp(total_payments)}  iconColor="brand-gradient" />
            <StatCard title="Net Payments"   value={egp(net_payments)} />
            <StatCard title="Opening Cash"   value={egp(shift.opening_cash)} />
          </div>

          {/* Shift info */}
          <div className="section rounded-xl border p-4 space-y-2">
            <p className="section-title text-xs font-semibold uppercase tracking-wide text-muted-foreground mb-3">Shift Details</p>
            {[
              ["Teller",     shift.teller_name],
              ["Status",     SHIFT_STATUS_LABELS[shift.status] ?? shift.status],
              ["Opened",     fmtDateTime(shift.opened_at)],
              ["Closed",     shift.closed_at ? fmtDateTime(shift.closed_at) : "—"],
              ["Duration",   fmtDuration(shift.opened_at, shift.closed_at ?? undefined)],
            ].map(([k,v]) => (
              <div key={k} className="flex justify-between items-center py-1 border-b border-border/40 last:border-0">
                <span className="text-xs text-muted-foreground">{k}</span>
                <span className="text-sm font-medium">{v}</span>
              </div>
            ))}
          </div>

          {/* Payment breakdown */}
          <div className="rounded-xl border overflow-hidden">
            <div className="p-3 bg-muted/40 border-b">
              <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Payment Breakdown</p>
            </div>
            <div className="divide-y divide-border/50">
              {payment_summary.length === 0
                ? <p className="text-sm text-muted-foreground text-center py-6">No payments</p>
                : payment_summary.map((row) => {
                    const color = PAYMENT_COLORS[row.payment_method] ?? "#888";
                    const pct   = total_payments > 0 ? (row.total / total_payments) * 100 : 0;
                    return (
                      <div key={row.payment_method} className="p-4">
                        <div className="flex items-center justify-between mb-1.5">
                          <div className="flex items-center gap-2">
                            <span className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ background: color }} />
                            <span className="text-sm font-medium">{fmtPayment(row.payment_method)}</span>
                            <Badge variant="outline" className="text-[10px] h-4">{row.order_count} orders</Badge>
                          </div>
                          <span className="font-bold tabular-nums">{egp(row.total)}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <div className="flex-1 h-1.5 bg-muted rounded-full overflow-hidden">
                            <div className="h-full rounded-full transition-all" style={{ width: `${pct}%`, background: color }} />
                          </div>
                          <span className="text-xs text-muted-foreground w-10 text-right">{pct.toFixed(1)}%</span>
                        </div>
                      </div>
                    );
                  })
              }
              <div className="p-4 bg-muted/30 flex justify-between font-bold">
                <span>Total</span>
                <span className="tabular-nums">{egp(total_payments)}</span>
              </div>
            </div>
          </div>

          {/* Cash summary */}
          <div className="rounded-xl border overflow-hidden">
            <div className="p-3 bg-muted/40 border-b">
              <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Cash Summary</p>
            </div>
            <div className="p-4 space-y-3">
              {[
                { label: "Opening Cash",          value: egp(shift.opening_cash), icon: DollarSign },
                { label: "Cash Sales",            value: egp(payment_summary.find(p=>p.payment_method==="cash")?.total ?? 0), icon: ArrowUpRight },
                { label: "Cash Movements In",     value: `+ ${egp(cash_movements_in)}`,  icon: ArrowDownLeft,  className: "text-green-600" },
                { label: "Cash Movements Out",    value: `- ${egp(cash_movements_out)}`, icon: ArrowUpRight,   className: "text-red-500" },
              ].map(({label,value,icon:Icon,className: cn}) => (
                <div key={label} className="flex items-center justify-between">
                  <div className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Icon size={13} />{label}
                  </div>
                  <span className={`font-semibold tabular-nums text-sm ${cn ?? ""}`}>{value}</span>
                </div>
              ))}
              <Separator />
              <div className="flex items-center justify-between">
                <span className="font-semibold">Expected Closing Cash</span>
                <span className="font-bold tabular-nums">{egp(shift.closing_cash_system ?? 0)}</span>
              </div>
              {shift.closing_cash_declared != null && (
                <div className="flex items-center justify-between">
                  <span className="font-semibold">Declared Closing Cash</span>
                  <span className="font-bold tabular-nums">{egp(shift.closing_cash_declared)}</span>
                </div>
              )}
              {discrepancy !== 0 && (
                <div className={`flex items-center justify-between rounded-lg px-3 py-2 ${discrepancy < 0 ? "bg-red-50 dark:bg-red-950/30" : "bg-green-50 dark:bg-green-950/30"}`}>
                  <div className="flex items-center gap-2">
                    <AlertCircle size={13} className={discrepancy < 0 ? "text-red-500" : "text-green-500"} />
                    <span className="font-semibold text-sm">Discrepancy</span>
                  </div>
                  <span className={`font-bold tabular-nums ${discrepancy < 0 ? "text-red-600" : "text-green-600"}`}>
                    {discrepancy > 0 ? "+" : ""}{egp(discrepancy)}
                  </span>
                </div>
              )}
            </div>
          </div>

          {/* Cash movements */}
          {cash_movements.length > 0 && (
            <div className="rounded-xl border overflow-hidden">
              <div className="p-3 bg-muted/40 border-b">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Cash Movements</p>
              </div>
              <div className="divide-y divide-border/50">
                {cash_movements.map((m, i) => (
                  <div key={i} className="flex items-center justify-between px-4 py-3">
                    <div>
                      <p className="text-sm font-medium">{m.note}</p>
                      <p className="text-xs text-muted-foreground">{m.moved_by_name} · {fmtDateTime(m.created_at)}</p>
                    </div>
                    <span className={`font-bold tabular-nums text-sm ${m.amount < 0 ? "text-red-500" : "text-green-600"}`}>
                      {m.amount > 0 ? "+" : ""}{egp(m.amount)}
                    </span>
                  </div>
                ))}
                <div className="flex justify-between px-4 py-3 bg-muted/30 font-semibold text-sm">
                  <span>Net Movements</span>
                  <span className={`tabular-nums ${cash_movements_net < 0 ? "text-red-500" : "text-green-600"}`}>
                    {cash_movements_net >= 0 ? "+" : ""}{egp(cash_movements_net)}
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>
      </ScrollArea>
    </div>
  );
}

// ── Main Shifts Page ──────────────────────────────────────────────────────────
export default function Shifts() {
  const user    = useAuthStore((s) => s.user);
  const orgId   = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const branchId = useAppStore((s) => s.selectedBranchId) ?? "";
  const qc      = useQueryClient();

  const [selBranch, setSelBranch]   = useState(branchId);
  const [reportShiftId, setReportShiftId] = useState<string | null>(null);

  // Dialogs
  const [openDialog, setOpenDialog]   = useState(false);
  const [closeDialog, setCloseDialog] = useState(false);
  const [cashDialog, setCashDialog]   = useState(false);
  const [forceDialog, setForceDialog] = useState(false);
  const [selShift, setSelShift]       = useState<Shift | null>(null);

  const [openForm,  setOpenForm]  = useState({ opening_cash: "" });
  const [closeForm, setCloseForm] = useState({ closing_cash_declared: "", notes: "" });
  const [cashForm,  setCashForm]  = useState({ amount: "", note: "", direction: "in" });
  const [forceForm, setForceForm] = useState({ reason: "" });

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => branchesApi.getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const activeBranch = branches.find((b) => b.id === selBranch) ?? branches[0];

  const { data: preFill } = useQuery({
    queryKey: ["shift-prefill", activeBranch?.id],
    queryFn:  () => shiftsApi.getCurrentShift(activeBranch!.id).then((r) => r.data),
    enabled:  !!activeBranch?.id,
  });

  const { data: shifts = [], isLoading } = useQuery({
    queryKey: ["shifts", activeBranch?.id],
    queryFn:  () => shiftsApi.getBranchShifts(activeBranch!.id).then((r) => r.data),
    enabled:  !!activeBranch?.id,
  });

  const openMutation = useMutation({
    mutationFn: () => shiftsApi.openShift(activeBranch!.id, { opening_cash: Math.round(parseFloat(openForm.opening_cash) * 100) }),
    onSuccess: () => { toast.success("Shift opened"); qc.invalidateQueries({ queryKey: ["shifts"] }); qc.invalidateQueries({ queryKey: ["shift-prefill"] }); setOpenDialog(false); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const closeMutation = useMutation({
    mutationFn: () => shiftsApi.closeShift(selShift!.id, {
      closing_cash_declared: Math.round(parseFloat(closeForm.closing_cash_declared) * 100),
      notes: closeForm.notes || null,
    }),
    onSuccess: () => { toast.success("Shift closed"); qc.invalidateQueries({ queryKey: ["shifts"] }); qc.invalidateQueries({ queryKey: ["shift-prefill"] }); setCloseDialog(false); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const cashMutation = useMutation({
    mutationFn: () => {
      const raw    = parseFloat(cashForm.amount) * 100;
      const signed = cashForm.direction === "out" ? -Math.abs(raw) : Math.abs(raw);
      return shiftsApi.addCashMovement(selShift!.id, { amount: signed, note: cashForm.note });
    },
    onSuccess: () => { toast.success("Cash movement recorded"); qc.invalidateQueries({ queryKey: ["shifts"] }); setCashDialog(false); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const forceMutation = useMutation({
    mutationFn: () => shiftsApi.forceCloseShift(selShift!.id, { reason: forceForm.reason }),
    onSuccess: () => { toast.success("Shift force closed"); qc.invalidateQueries({ queryKey: ["shifts"] }); qc.invalidateQueries({ queryKey: ["shift-prefill"] }); setForceDialog(false); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const openShift  = preFill?.open_shift;
  const hasOpen    = preFill?.has_open_shift;
  const suggested  = preFill?.suggested_opening_cash ?? 0;

  const columns: ColumnDef<Shift, any>[] = [
    { accessorKey: "teller_name", header: "Teller", cell: ({ row }) => <span className="font-semibold text-sm">{row.original.teller_name}</span> },
    { accessorKey: "status", header: "Status",
      cell: ({ row }) => (
        <Badge className={SHIFT_STATUS_COLORS[row.original.status]}>{SHIFT_STATUS_LABELS[row.original.status] ?? row.original.status}</Badge>
      ),
    },
    { accessorKey: "opened_at", header: "Opened",  cell: ({ row }) => <span className="text-xs">{fmtDateTime(row.original.opened_at)}</span> },
    { accessorKey: "closed_at", header: "Closed",  cell: ({ row }) => <span className="text-xs text-muted-foreground">{row.original.closed_at ? fmtDateTime(row.original.closed_at) : "—"}</span> },
    { id: "duration",           header: "Duration", cell: ({ row }) => <span className="text-xs">{fmtDuration(row.original.opened_at, row.original.closed_at ?? undefined)}</span> },
    { id: "actions", header: "",
      cell: ({ row }) => (
        <div className="flex items-center gap-1 justify-end" onClick={(e) => e.stopPropagation()}>
          <Button variant="ghost" size="sm" onClick={() => setReportShiftId(row.original.id)}>
            <FileText size={13} /> Report
          </Button>
          {row.original.status === "open" && (
            <>
              <Button variant="ghost" size="sm" onClick={() => { setSelShift(row.original); setCashDialog(true); }}>
                <DollarSign size={13} /> Cash
              </Button>
              <Button variant="ghost" size="sm" onClick={() => { setSelShift(row.original); setCloseDialog(true); }}>
                <CheckCircle size={13} /> Close
              </Button>
            </>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader
        title="Shifts"
        sub={activeBranch ? `${activeBranch.name} · ${shifts.length} shifts` : "Select a branch"}
        actions={
          <div className="flex items-center gap-2">
            {branches.length > 1 && (
              <Select value={selBranch} onValueChange={setSelBranch}>
                <SelectTrigger className="w-44 h-9"><SelectValue placeholder="Branch…" /></SelectTrigger>
                <SelectContent>{branches.map((b)=><SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>)}</SelectContent>
              </Select>
            )}
            {hasOpen && openShift ? (
              <Button variant="outline" size="sm" onClick={() => { setSelShift(openShift); setForceDialog(true); }}>
                Force Close
              </Button>
            ) : (
              <Button size="sm" onClick={() => { setOpenForm({ opening_cash: String(suggested / 100) }); setOpenDialog(true); }}>
                <Plus size={13} /> Open Shift
              </Button>
            )}
          </div>
        }
      />

      {/* Open shift banner */}
      {hasOpen && openShift && (
        <div className="mb-4 flex items-center gap-3 bg-green-50 dark:bg-green-950/30 border border-green-200 dark:border-green-800 rounded-xl px-4 py-3">
          <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse flex-shrink-0" />
          <div className="flex-1">
            <p className="text-sm font-semibold text-green-800 dark:text-green-200">Shift is open</p>
            <p className="text-xs text-green-700 dark:text-green-300">{openShift.teller_name} · {fmtDateTime(openShift.opened_at)} · {fmtDuration(openShift.opened_at)}</p>
          </div>
          <div className="flex gap-2">
            <Button size="sm" variant="outline" onClick={() => setReportShiftId(openShift.id)}>
              <FileText size={13} /> Report
            </Button>
            <Button size="sm" variant="outline" onClick={() => { setSelShift(openShift); setCashDialog(true); }}>
              <DollarSign size={13} /> Cash
            </Button>
            <Button size="sm" onClick={() => { setSelShift(openShift); setCloseDialog(true); }}>
              <CheckCircle size={13} /> Close Shift
            </Button>
          </div>
        </div>
      )}

      {isLoading
        ? <div className="space-y-2">{Array.from({length:6}).map((_,i)=><Skeleton key={i} className="h-14 rounded-xl"/>)}</div>
        : <DataTable data={shifts} columns={columns} searchPlaceholder="Search shifts…" pageSize={15} />
      }

      {/* Open shift dialog */}
      <Dialog open={openDialog} onOpenChange={setOpenDialog}>
        <DialogContent>
          <DialogHeader><DialogTitle>Open New Shift</DialogTitle></DialogHeader>
          <div className="p-6 space-y-4">
            {suggested > 0 && (
              <div className="bg-accent rounded-xl px-4 py-3 text-sm">
                Suggested opening cash (previous closing): <strong>{egp(suggested)}</strong>
              </div>
            )}
            <div className="space-y-1.5">
              <Label>Opening Cash (EGP)</Label>
              <Input type="number" step="0.5" value={openForm.opening_cash}
                onChange={(e) => setOpenForm({ opening_cash: e.target.value })} placeholder="0.00" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpenDialog(false)}>Cancel</Button>
            <Button loading={openMutation.isPending} onClick={() => openMutation.mutate()}>Open Shift</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Close shift dialog */}
      <Dialog open={closeDialog} onOpenChange={setCloseDialog}>
        <DialogContent>
          <DialogHeader><DialogTitle>Close Shift</DialogTitle></DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Declared Closing Cash (EGP)</Label>
              <Input type="number" step="0.5" value={closeForm.closing_cash_declared}
                onChange={(e) => setCloseForm((f) => ({ ...f, closing_cash_declared: e.target.value }))} placeholder="0.00" />
            </div>
            <div className="space-y-1.5">
              <Label>Notes (optional)</Label>
              <Input value={closeForm.notes} onChange={(e) => setCloseForm((f) => ({ ...f, notes: e.target.value }))} placeholder="Any notes…" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCloseDialog(false)}>Cancel</Button>
            <Button loading={closeMutation.isPending} onClick={() => closeMutation.mutate()}>Close Shift</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Cash movement dialog */}
      <Dialog open={cashDialog} onOpenChange={setCashDialog}>
        <DialogContent>
          <DialogHeader><DialogTitle>Cash Movement</DialogTitle></DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Direction</Label>
              <Select value={cashForm.direction} onValueChange={(v) => setCashForm((f) => ({ ...f, direction: v }))}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="in">Cash In (add to drawer)</SelectItem>
                  <SelectItem value="out">Cash Out (remove from drawer)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Amount (EGP)</Label>
              <Input type="number" step="0.5" value={cashForm.amount}
                onChange={(e) => setCashForm((f) => ({ ...f, amount: e.target.value }))} placeholder="0.00" />
            </div>
            <div className="space-y-1.5">
              <Label>Note</Label>
              <Input value={cashForm.note} onChange={(e) => setCashForm((f) => ({ ...f, note: e.target.value }))} placeholder="Reason for movement" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCashDialog(false)}>Cancel</Button>
            <Button loading={cashMutation.isPending} onClick={() => cashMutation.mutate()}>Record</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Force close dialog */}
      <Dialog open={forceDialog} onOpenChange={setForceDialog}>
        <DialogContent>
          <DialogHeader><DialogTitle>Force Close Shift</DialogTitle></DialogHeader>
          <div className="p-6 space-y-4">
            <div className="bg-orange-50 dark:bg-orange-950/30 border border-orange-200 rounded-xl px-4 py-3 text-sm text-orange-800 dark:text-orange-200">
              Force closing will end the shift without a proper cash count. Use only when necessary.
            </div>
            <div className="space-y-1.5">
              <Label>Reason</Label>
              <Input value={forceForm.reason} onChange={(e) => setForceForm({ reason: e.target.value })} placeholder="Required reason…" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setForceDialog(false)}>Cancel</Button>
            <Button variant="destructive" loading={forceMutation.isPending} onClick={() => forceMutation.mutate()}>Force Close</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Shift report drawer */}
      <Dialog open={!!reportShiftId} onOpenChange={(o) => !o && setReportShiftId(null)}>
        <DialogContent sheet="right" showClose={false} className="p-0">
          {reportShiftId && (
            <ShiftReportView shiftId={reportShiftId} onClose={() => setReportShiftId(null)} />
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
TSX
ok "Shifts page"

# ===========================================================================
#  PART 7 — ANALYTICS PAGE
# ===========================================================================
log "Writing Analytics page..."

cat > src/pages/analytics/Analytics.tsx << 'TSX'
import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import {
  AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from "recharts";
import { BarChart2, TrendingUp, Users, Package, Coffee, Clock } from "lucide-react";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as reportsApi from "@/api/reports";
import * as branchesApi from "@/api/branches";
import { egp, fmtDate, fmtPayment, PAYMENT_COLORS, pct } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import { StatCard } from "@/components/shared/StatCard";
import { PageHeader } from "@/components/shared/PageHeader";
import { DateRangePicker } from "@/components/shared/DateRangePicker";
import { DataTable } from "@/components/shared/DataTable";
import { type ColumnDef } from "@tanstack/react-table";
import type { TellerStats, TimeseriesPoint, ItemSales, BranchComparison } from "@/types";

const GRANULARITIES = [
  { value: "hourly",  label: "Hourly" },
  { value: "daily",   label: "Daily"  },
  { value: "monthly", label: "Monthly"},
];

// Custom tooltip for charts
function ChartTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-popover border border-border rounded-xl shadow-lg p-3 text-sm">
      <p className="font-semibold mb-2 text-xs text-muted-foreground">{label}</p>
      {payload.map((p: any) => (
        <div key={p.dataKey} className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full" style={{ background: p.color }} />
            <span className="text-xs">{p.name}</span>
          </div>
          <span className="font-bold text-xs tabular-nums">
            {p.dataKey.includes("revenue") || p.dataKey === "revenue" ? egp(p.value) : p.value}
          </span>
        </div>
      ))}
    </div>
  );
}

export default function Analytics() {
  const user    = useAuthStore((s) => s.user);
  const orgId   = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const branchId = useAppStore((s) => s.selectedBranchId) ?? "";

  const [tab,         setTab]         = useState("overview");
  const [selBranch,   setSelBranch]   = useState(branchId);
  const [from,        setFrom]        = useState<string | null>(null);
  const [to,          setTo]          = useState<string | null>(null);
  const [granularity, setGranularity] = useState("daily");

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => branchesApi.getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });
  const activeBranch = branches.find((b) => b.id === selBranch) ?? branches[0];

  const params = { from: from ?? undefined, to: to ?? undefined };

  const { data: sales, isLoading: salesLoading } = useQuery({
    queryKey: ["branch-sales", activeBranch?.id, from, to],
    queryFn:  () => reportsApi.getBranchSales(activeBranch!.id, params).then((r) => r.data),
    enabled:  !!activeBranch?.id,
  });

  const { data: timeseries = [], isLoading: tsLoading } = useQuery({
    queryKey: ["timeseries", activeBranch?.id, from, to, granularity],
    queryFn:  () => reportsApi.getBranchTimeseries(activeBranch!.id, { ...params, granularity }).then((r) => r.data),
    enabled:  !!activeBranch?.id && tab === "revenue",
  });

  const { data: tellers = [], isLoading: tellersLoading } = useQuery({
    queryKey: ["tellers", activeBranch?.id, from, to],
    queryFn:  () => reportsApi.getBranchTellers(activeBranch!.id, params).then((r) => r.data),
    enabled:  !!activeBranch?.id && tab === "tellers",
  });

  const { data: addons = [], isLoading: addonsLoading } = useQuery({
    queryKey: ["addon-sales", activeBranch?.id, from, to],
    queryFn:  () => reportsApi.getBranchAddonSales(activeBranch!.id, params).then((r) => r.data),
    enabled:  !!activeBranch?.id && (tab === "items" || tab === "overview"),
  });

  const { data: comparison, isLoading: compLoading } = useQuery({
    queryKey: ["org-comparison", orgId, from, to],
    queryFn:  () => reportsApi.getOrgComparison(orgId, params).then((r) => r.data),
    enabled:  !!orgId && tab === "branches",
  });

  const { data: stock, isLoading: stockLoading } = useQuery({
    queryKey: ["branch-stock", activeBranch?.id],
    queryFn:  () => reportsApi.getBranchStock(activeBranch!.id).then((r) => r.data),
    enabled:  !!activeBranch?.id && tab === "inventory",
  });

  // Payment pie data
  const paymentPie = sales ? [
    { name: "Cash",            value: sales.cash_revenue,           color: PAYMENT_COLORS.cash           },
    { name: "Card",            value: sales.card_revenue,           color: PAYMENT_COLORS.card           },
    { name: "Digital Wallet",  value: sales.digital_wallet_revenue, color: PAYMENT_COLORS.digital_wallet },
    { name: "Mixed",           value: sales.mixed_revenue,          color: PAYMENT_COLORS.mixed          },
    { name: "Talabat Online",  value: sales.talabat_online_revenue, color: PAYMENT_COLORS.talabat_online },
    { name: "Talabat Cash",    value: sales.talabat_cash_revenue,   color: PAYMENT_COLORS.talabat_cash   },
  ].filter((d) => d.value > 0) : [];

  // Timeseries chart data
  const tsData = timeseries.map((p) => ({
    ...p,
    period: fmtDate(p.period),
  }));

  // Teller columns
  const tellerCols: ColumnDef<TellerStats, any>[] = [
    { accessorKey: "teller_name", header: "Teller", cell: ({ row }) => <span className="font-semibold">{row.original.teller_name}</span> },
    { accessorKey: "orders",      header: "Orders",  cell: ({ row }) => <span className="tabular-nums">{row.original.orders}</span> },
    { accessorKey: "revenue",     header: "Revenue", cell: ({ row }) => <span className="font-semibold tabular-nums">{egp(row.original.revenue)}</span> },
    { accessorKey: "avg_order_value", header: "Avg Order", cell: ({ row }) => <span className="tabular-nums">{egp(row.original.avg_order_value)}</span> },
    { accessorKey: "voided", header: "Voided", cell: ({ row }) => (
      <span className={row.original.voided > 0 ? "text-red-500 font-semibold" : "text-muted-foreground"}>{row.original.voided}</span>
    )},
    { accessorKey: "shifts", header: "Shifts", cell: ({ row }) => <span className="tabular-nums">{row.original.shifts}</span> },
  ];

  // Branch comparison columns
  const branchCols: ColumnDef<BranchComparison, any>[] = [
    { accessorKey: "branch_name",  header: "Branch",  cell: ({ row }) => <span className="font-semibold">{row.original.branch_name}</span> },
    { accessorKey: "total_orders", header: "Orders",  cell: ({ row }) => <span className="tabular-nums">{row.original.total_orders}</span> },
    { accessorKey: "total_revenue",header: "Revenue", cell: ({ row }) => <span className="font-bold tabular-nums">{egp(row.original.total_revenue)}</span> },
    { accessorKey: "cash_revenue", header: "Cash",    cell: ({ row }) => <span className="tabular-nums text-xs">{egp(row.original.cash_revenue)}</span> },
    { accessorKey: "card_revenue", header: "Card",    cell: ({ row }) => <span className="tabular-nums text-xs">{egp(row.original.card_revenue)}</span> },
    { id: "talabat", header: "Talabat", cell: ({ row }) => (
      <span className="tabular-nums text-xs">{egp(row.original.talabat_online_revenue + row.original.talabat_cash_revenue)}</span>
    )},
    { accessorKey: "avg_order_value", header: "AOV",     cell: ({ row }) => <span className="tabular-nums text-xs">{egp(row.original.avg_order_value)}</span> },
    { accessorKey: "void_rate_pct",   header: "Void %",  cell: ({ row }) => (
      <span className={`tabular-nums text-xs ${row.original.void_rate_pct > 5 ? "text-red-500 font-semibold" : "text-muted-foreground"}`}>
        {row.original.void_rate_pct.toFixed(1)}%
      </span>
    )},
  ];

  // Top items columns
  const itemCols: ColumnDef<ItemSales, any>[] = [
    { accessorKey: "item_name",     header: "Item",     cell: ({ row }) => <span className="font-semibold">{row.original.item_name}</span> },
    { accessorKey: "quantity_sold", header: "Qty Sold", cell: ({ row }) => <span className="tabular-nums">{row.original.quantity_sold}</span> },
    { accessorKey: "revenue",       header: "Revenue",  cell: ({ row }) => <span className="font-semibold tabular-nums">{egp(row.original.revenue)}</span> },
    { id: "share", header: "Share", cell: ({ row }) => (
      <span className="text-xs text-muted-foreground">{pct(row.original.revenue, sales?.total_revenue ?? 0)}</span>
    )},
  ];

  const Loader = () => (
    <div className="space-y-3">
      {Array.from({length:4}).map((_,i)=><Skeleton key={i} className="h-14 rounded-xl"/>)}
    </div>
  );

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader
        title="Analytics"
        sub={activeBranch ? `${activeBranch.name}` : "Select a branch"}
        actions={
          branches.length > 1 && (
            <Select value={selBranch} onValueChange={setSelBranch}>
              <SelectTrigger className="w-44 h-9"><SelectValue placeholder="Branch…" /></SelectTrigger>
              <SelectContent>{branches.map((b)=><SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>)}</SelectContent>
            </Select>
          )
        }
      />

      {/* Date range */}
      <div className="mb-6">
        <DateRangePicker from={from} to={to} onChange={(f, t) => { setFrom(f); setTo(t); }} />
      </div>

      <Tabs value={tab} onValueChange={setTab}>
        <TabsList className="mb-6 flex-wrap h-auto gap-1">
          <TabsTrigger value="overview"> <BarChart2 size={13} /> Overview</TabsTrigger>
          <TabsTrigger value="revenue">  <TrendingUp size={13} /> Revenue</TabsTrigger>
          <TabsTrigger value="items">    <Coffee size={13} /> Items</TabsTrigger>
          <TabsTrigger value="tellers">  <Users size={13} /> Tellers</TabsTrigger>
          <TabsTrigger value="branches"> <BarChart2 size={13} /> Branches</TabsTrigger>
          <TabsTrigger value="inventory"><Package size={13} /> Inventory</TabsTrigger>
        </TabsList>

        {/* ── Overview ── */}
        <TabsContent value="overview" className="space-y-6">
          {salesLoading ? (
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
              {Array.from({length:4}).map((_,i)=><Skeleton key={i} className="h-28 rounded-2xl"/>)}
            </div>
          ) : sales && (
            <>
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <StatCard title="Total Revenue" value={egp(sales.total_revenue)} sub={`${sales.total_orders} orders`} icon={TrendingUp} />
                <StatCard title="Total Discount" value={egp(sales.total_discount)} sub="Applied discounts" icon={BarChart2} iconColor="bg-amber-500" />
                <StatCard title="Tax Collected" value={egp(sales.total_tax)} icon={Coffee} iconColor="bg-purple-500" />
                <StatCard title="Voided Orders" value={sales.voided_orders}
                  sub={`${pct(sales.voided_orders, sales.total_orders + sales.voided_orders)} void rate`}
                  icon={Clock} iconColor="bg-red-500" />
              </div>

              {/* Payment pie */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Revenue by Payment Method</p>
                  {paymentPie.length > 0 ? (
                    <ResponsiveContainer width="100%" height={220}>
                      <PieChart>
                        <Pie data={paymentPie} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={80} innerRadius={48}>
                          {paymentPie.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                        </Pie>
                        <Tooltip formatter={(v: number) => egp(v)} />
                        <Legend formatter={(v) => <span className="text-xs">{v}</span>} />
                      </PieChart>
                    </ResponsiveContainer>
                  ) : <p className="text-center text-muted-foreground text-sm py-10">No data</p>}
                </div>

                {/* Top 5 items */}
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Top Items</p>
                  <div className="space-y-3">
                    {sales.top_items.slice(0,5).map((item, i) => {
                      const share = sales.total_revenue > 0 ? (item.revenue / sales.total_revenue) * 100 : 0;
                      return (
                        <div key={item.menu_item_id}>
                          <div className="flex items-center justify-between mb-1">
                            <div className="flex items-center gap-2">
                              <span className="text-xs text-muted-foreground w-4">#{i+1}</span>
                              <span className="text-sm font-medium">{item.item_name}</span>
                            </div>
                            <div className="flex items-center gap-2">
                              <span className="text-xs text-muted-foreground">{item.quantity_sold}x</span>
                              <span className="text-sm font-bold tabular-nums">{egp(item.revenue)}</span>
                            </div>
                          </div>
                          <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                            <div className="h-full brand-gradient rounded-full" style={{ width: `${share}%` }} />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            </>
          )}
        </TabsContent>

        {/* ── Revenue timeseries ── */}
        <TabsContent value="revenue" className="space-y-4">
          <div className="flex items-center gap-3 flex-wrap">
            {GRANULARITIES.map((g) => (
              <Button key={g.value} variant={granularity === g.value ? "default" : "outline"} size="sm"
                onClick={() => setGranularity(g.value)}>
                {g.label}
              </Button>
            ))}
          </div>

          {tsLoading ? <Skeleton className="h-72 rounded-2xl" /> : (
            <div className="rounded-2xl border p-5">
              <p className="text-sm font-bold mb-4">Revenue Over Time</p>
              <ResponsiveContainer width="100%" height={280}>
                <AreaChart data={tsData}>
                  <defs>
                    <linearGradient id="grad-cash"           x1="0" y1="0" x2="0" y2="1"><stop offset="5%"  stopColor={PAYMENT_COLORS.cash}           stopOpacity={0.3}/><stop offset="95%" stopColor={PAYMENT_COLORS.cash}           stopOpacity={0}/></linearGradient>
                    <linearGradient id="grad-card"           x1="0" y1="0" x2="0" y2="1"><stop offset="5%"  stopColor={PAYMENT_COLORS.card}           stopOpacity={0.3}/><stop offset="95%" stopColor={PAYMENT_COLORS.card}           stopOpacity={0}/></linearGradient>
                    <linearGradient id="grad-digital"        x1="0" y1="0" x2="0" y2="1"><stop offset="5%"  stopColor={PAYMENT_COLORS.digital_wallet} stopOpacity={0.3}/><stop offset="95%" stopColor={PAYMENT_COLORS.digital_wallet} stopOpacity={0}/></linearGradient>
                    <linearGradient id="grad-talabat-online" x1="0" y1="0" x2="0" y2="1"><stop offset="5%"  stopColor={PAYMENT_COLORS.talabat_online} stopOpacity={0.3}/><stop offset="95%" stopColor={PAYMENT_COLORS.talabat_online} stopOpacity={0}/></linearGradient>
                    <linearGradient id="grad-talabat-cash"   x1="0" y1="0" x2="0" y2="1"><stop offset="5%"  stopColor={PAYMENT_COLORS.talabat_cash}   stopOpacity={0.3}/><stop offset="95%" stopColor={PAYMENT_COLORS.talabat_cash}   stopOpacity={0}/></linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                  <XAxis dataKey="period" tick={{ fontSize: 11 }} />
                  <YAxis tickFormatter={(v) => `${(v/100).toFixed(0)}`} tick={{ fontSize: 11 }} />
                  <Tooltip content={<ChartTooltip />} />
                  <Legend formatter={(v) => <span className="text-xs">{fmtPayment(v.replace("_revenue",""))}</span>} />
                  <Area type="monotone" dataKey="cash_revenue"           name="cash"           stroke={PAYMENT_COLORS.cash}           fill="url(#grad-cash)"           strokeWidth={2} />
                  <Area type="monotone" dataKey="card_revenue"           name="card"           stroke={PAYMENT_COLORS.card}           fill="url(#grad-card)"           strokeWidth={2} />
                  <Area type="monotone" dataKey="digital_wallet_revenue" name="digital_wallet" stroke={PAYMENT_COLORS.digital_wallet} fill="url(#grad-digital)"        strokeWidth={2} />
                  <Area type="monotone" dataKey="talabat_online_revenue" name="talabat_online" stroke={PAYMENT_COLORS.talabat_online} fill="url(#grad-talabat-online)" strokeWidth={2} />
                  <Area type="monotone" dataKey="talabat_cash_revenue"   name="talabat_cash"   stroke={PAYMENT_COLORS.talabat_cash}   fill="url(#grad-talabat-cash)"   strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}

          {/* Orders timeseries */}
          {!tsLoading && tsData.length > 0 && (
            <div className="rounded-2xl border p-5">
              <p className="text-sm font-bold mb-4">Orders Over Time</p>
              <ResponsiveContainer width="100%" height={200}>
                <BarChart data={tsData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                  <XAxis dataKey="period" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} />
                  <Tooltip content={<ChartTooltip />} />
                  <Bar dataKey="orders" name="Orders" fill="hsl(var(--primary))" radius={[4,4,0,0]} />
                  <Bar dataKey="voided" name="Voided" fill="hsl(var(--destructive))" radius={[4,4,0,0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </TabsContent>

        {/* ── Items ── */}
        <TabsContent value="items" className="space-y-4">
          {salesLoading ? <Loader /> : sales && (
            <>
              <div className="rounded-2xl border p-5">
                <p className="text-sm font-bold mb-4">Top Items by Revenue</p>
                <DataTable data={sales.top_items} columns={itemCols} searchPlaceholder="Search items…" pageSize={10} />
              </div>

              {/* By category */}
              <div className="rounded-2xl border p-5">
                <p className="text-sm font-bold mb-4">By Category</p>
                <div className="space-y-3">
                  {sales.by_category.map((cat) => {
                    const share = sales.total_revenue > 0 ? (cat.revenue / sales.total_revenue) * 100 : 0;
                    return (
                      <div key={cat.category_id ?? "uncategorised"}>
                        <div className="flex items-center justify-between mb-1">
                          <span className="text-sm font-medium">{cat.category_name ?? "Uncategorised"}</span>
                          <div className="flex items-center gap-3">
                            <span className="text-xs text-muted-foreground">{cat.quantity_sold} sold</span>
                            <span className="font-bold tabular-nums text-sm">{egp(cat.revenue)}</span>
                          </div>
                        </div>
                        <div className="h-1.5 bg-muted rounded-full overflow-hidden">
                          <div className="h-full brand-gradient rounded-full" style={{ width: `${share}%` }} />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Addon sales */}
              {addons.length > 0 && (
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Addon Sales</p>
                  <div className="space-y-2">
                    {addons.slice(0,10).map((a) => (
                      <div key={a.addon_item_id} className="flex items-center justify-between py-2 border-b border-border/50 last:border-0">
                        <div>
                          <span className="text-sm font-medium">{a.addon_name}</span>
                          <Badge variant="info" className="ml-2 text-[10px]">{a.addon_type.replace("_"," ")}</Badge>
                        </div>
                        <div className="flex items-center gap-3">
                          <span className="text-xs text-muted-foreground">{a.quantity_sold}x</span>
                          <span className="font-semibold tabular-nums text-sm">{egp(a.revenue)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </>
          )}
        </TabsContent>

        {/* ── Tellers ── */}
        <TabsContent value="tellers" className="space-y-4">
          {tellersLoading ? <Loader /> : (
            <>
              {tellers.length > 0 && (
                <div className="rounded-2xl border p-5">
                  <p className="text-sm font-bold mb-4">Revenue by Teller</p>
                  <ResponsiveContainer width="100%" height={220}>
                    <BarChart data={tellers.slice(0,8)} layout="vertical">
                      <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" horizontal={false} />
                      <XAxis type="number" tickFormatter={(v) => `${(v/100).toFixed(0)}`} tick={{ fontSize: 11 }} />
                      <YAxis type="category" dataKey="teller_name" tick={{ fontSize: 11 }} width={90} />
                      <Tooltip content={<ChartTooltip />} />
                      <Bar dataKey="revenue" name="revenue" fill="hsl(var(--primary))" radius={[0,4,4,0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
              <DataTable data={tellers} columns={tellerCols} searchPlaceholder="Search tellers…" />
            </>
          )}
        </TabsContent>

        {/* ── Branch comparison ── */}
        <TabsContent value="branches" className="space-y-4">
          {compLoading ? <Loader /> : comparison && (
            <>
              <div className="rounded-2xl border p-5">
                <p className="text-sm font-bold mb-4">Revenue by Branch</p>
                <ResponsiveContainer width="100%" height={220}>
                  <BarChart data={comparison.branches}>
                    <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                    <XAxis dataKey="branch_name" tick={{ fontSize: 11 }} />
                    <YAxis tickFormatter={(v) => `${(v/100).toFixed(0)}`} tick={{ fontSize: 11 }} />
                    <Tooltip content={<ChartTooltip />} />
                    <Bar dataKey="cash_revenue"           name="cash"           fill={PAYMENT_COLORS.cash}           stackId="a" radius={[0,0,0,0]} />
                    <Bar dataKey="card_revenue"           name="card"           fill={PAYMENT_COLORS.card}           stackId="a" />
                    <Bar dataKey="digital_wallet_revenue" name="digital_wallet" fill={PAYMENT_COLORS.digital_wallet} stackId="a" />
                    <Bar dataKey="talabat_online_revenue" name="talabat_online" fill={PAYMENT_COLORS.talabat_online} stackId="a" />
                    <Bar dataKey="talabat_cash_revenue"   name="talabat_cash"   fill={PAYMENT_COLORS.talabat_cash}   stackId="a" radius={[4,4,0,0]} />
                    <Legend formatter={(v) => <span className="text-xs">{fmtPayment(v)}</span>} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
              <DataTable data={comparison.branches} columns={branchCols} searchPlaceholder="Search branches…" />
            </>
          )}
        </TabsContent>

        {/* ── Inventory ── */}
        <TabsContent value="inventory" className="space-y-4">
          {stockLoading ? <Loader /> : stock && (
            <>
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <StatCard title="Total Items"    value={stock.items.length} />
                <StatCard title="Low Stock"      value={stock.items.filter(i=>i.below_reorder).length} iconColor="bg-amber-500" />
                <StatCard title="Active Items"   value={stock.items.filter(i=>i.is_active).length} />
                <StatCard title="Inactive Items" value={stock.items.filter(i=>!i.is_active).length} iconColor="bg-muted" />
              </div>
              <div className="rounded-2xl border overflow-hidden">
                <div className="p-4 border-b bg-muted/30">
                  <p className="font-bold text-sm">Stock Levels</p>
                </div>
                <div className="divide-y divide-border/50">
                  {stock.items.sort((a,b)=> Number(b.below_reorder)-Number(a.below_reorder)).map((item) => {
                    const pctVal = Math.min(100,(item.current_stock / Math.max(item.reorder_threshold*2,1))*100);
                    return (
                      <div key={item.inventory_item_id} className="flex items-center gap-4 px-4 py-3">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-1">
                            <span className="text-sm font-medium">{item.item_name}</span>
                            {item.below_reorder && <Badge variant="warning" className="text-[10px] h-4">Low</Badge>}
                          </div>
                          <div className="flex items-center gap-2">
                            <div className="flex-1 h-1.5 bg-muted rounded-full overflow-hidden">
                              <div className={`h-full rounded-full ${item.below_reorder ? "bg-amber-500" : "brand-gradient"}`}
                                style={{ width: `${pctVal}%` }} />
                            </div>
                            <span className="text-xs text-muted-foreground whitespace-nowrap">
                              {item.current_stock} / {item.reorder_threshold} {item.unit}
                            </span>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}
TSX
ok "Analytics page"

# ===========================================================================
#  PERMISSIONS PAGE
# ===========================================================================
log "Writing Permissions page..."

cat > src/pages/permissions/Permissions.tsx << 'TSX'
import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useParams, useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { Shield, Check, X, ChevronRight } from "lucide-react";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as permissionsApi from "@/api/permissions";
import * as usersApi from "@/api/users";
import type { UserPublic, PermissionMatrix } from "@/types";
import { fmtRole, ROLE_COLORS } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { ScrollArea } from "@/components/ui/scroll-area";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";
import { cn } from "@/lib/utils";

const RESOURCES = [
  "orders","shifts","branches","users","menu_items","categories","addon_items",
  "inventory","recipes","permissions","shift_counts","soft_serve",
];

const ACTIONS = ["read","create","update","delete"];

export default function Permissions() {
  const { userId } = useParams<{ userId?: string }>();
  const navigate   = useNavigate();
  const authUser   = useAuthStore((s) => s.user);
  const orgId      = useAppStore((s) => s.selectedOrgId) ?? authUser?.org_id ?? "";
  const qc         = useQueryClient();
  const [selUser, setSelUser] = useState<string | null>(userId ?? null);

  const { data: users = [], isLoading: usersLoading } = useQuery({
    queryKey: ["users", orgId],
    queryFn:  () => usersApi.getUsers(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const { data: matrix = [], isLoading: matrixLoading } = useQuery({
    queryKey: ["permissions-matrix", selUser],
    queryFn:  () => permissionsApi.getMatrix(selUser!).then((r) => r.data),
    enabled:  !!selUser,
  });

  const upsertMutation = useMutation({
    mutationFn: (data: { resource: string; action: string; granted: boolean }) =>
      permissionsApi.upsertPermission(selUser!, data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["permissions-matrix", selUser] }),
    onError:   (e) => toast.error(getErrorMessage(e)),
  });

  const deleteMutation = useMutation({
    mutationFn: ({ resource, action }: { resource: string; action: string }) =>
      permissionsApi.deletePermission(selUser!, resource, action),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["permissions-matrix", selUser] }),
    onError:   (e) => toast.error(getErrorMessage(e)),
  });

  const getCell = (resource: string, action: string): PermissionMatrix | undefined =>
    matrix.find((m) => m.resource === resource && m.action === action);

  const handleToggle = (resource: string, action: string, cell: PermissionMatrix | undefined) => {
    if (!cell) return;
    if (cell.user_override !== null) {
      // Remove override → revert to role default
      deleteMutation.mutate({ resource, action });
    } else {
      // Set override opposite to role default
      upsertMutation.mutate({ resource, action, granted: !cell.role_default });
    }
  };

  const selectedUser = users.find((u) => u.id === selUser);

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader title="Permissions" sub="Manage per-user access overrides" />

      <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-4">
        {/* User list */}
        <div className="rounded-2xl border overflow-hidden">
          <div className="p-3 border-b bg-muted/30">
            <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Select User</p>
          </div>
          <ScrollArea className="h-[600px]">
            {usersLoading
              ? <div className="p-3 space-y-2">{Array.from({length:5}).map((_,i)=><Skeleton key={i} className="h-12"/>)}</div>
              : users.filter((u) => u.id !== authUser?.id).map((u) => (
                  <button key={u.id} onClick={() => { setSelUser(u.id); navigate(`/permissions/${u.id}`); }}
                    className={cn(
                      "w-full text-left px-4 py-3 border-b border-border/50 hover:bg-muted/40 transition-colors flex items-center gap-3",
                      selUser === u.id && "bg-accent",
                    )}>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold truncate">{u.name}</p>
                      <p className={cn("text-[10px] font-semibold px-1.5 py-0.5 rounded-full border inline-block mt-0.5", ROLE_COLORS[u.role])}>
                        {fmtRole(u.role)}
                      </p>
                    </div>
                    {selUser === u.id && <ChevronRight size={14} className="text-primary flex-shrink-0" />}
                  </button>
                ))
            }
          </ScrollArea>
        </div>

        {/* Permission matrix */}
        <div className="rounded-2xl border overflow-hidden">
          {!selUser ? (
            <EmptyState icon={Shield} title="Select a user" sub="Choose a user to view and manage their permissions" className="h-[600px]" />
          ) : (
            <>
              <div className="p-4 border-b bg-muted/30 flex items-center justify-between">
                <div>
                  <p className="font-bold">{selectedUser?.name}</p>
                  <p className="text-xs text-muted-foreground">Overrides applied on top of role defaults</p>
                </div>
                {selectedUser && (
                  <Badge className={ROLE_COLORS[selectedUser.role]}>{fmtRole(selectedUser.role)}</Badge>
                )}
              </div>

              <ScrollArea className="h-[560px]">
                {matrixLoading ? (
                  <div className="p-4 space-y-2">{Array.from({length:8}).map((_,i)=><Skeleton key={i} className="h-10"/>)}</div>
                ) : (
                  <table className="w-full text-sm">
                    <thead className="sticky top-0 bg-background border-b z-10">
                      <tr>
                        <th className="text-left px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Resource</th>
                        {ACTIONS.map((a) => (
                          <th key={a} className="text-center px-3 py-2.5 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{a}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {RESOURCES.map((resource) => (
                        <tr key={resource} className="border-b border-border/50 hover:bg-muted/30 transition-colors">
                          <td className="px-4 py-3 font-medium text-sm capitalize">{resource.replace("_"," ")}</td>
                          {ACTIONS.map((action) => {
                            const cell = getCell(resource, action);
                            if (!cell) return (
                              <td key={action} className="px-3 py-3 text-center">
                                <span className="text-muted-foreground">—</span>
                              </td>
                            );
                            const hasOverride = cell.user_override !== null;
                            const effective   = cell.effective;
                            return (
                              <td key={action} className="px-3 py-3 text-center">
                                <div className="flex flex-col items-center gap-1">
                                  <button
                                    onClick={() => handleToggle(resource, action, cell)}
                                    className={cn(
                                      "w-7 h-7 rounded-lg flex items-center justify-center transition-all border",
                                      hasOverride
                                        ? effective
                                          ? "bg-primary text-primary-foreground border-primary"
                                          : "bg-destructive/10 text-destructive border-destructive/30"
                                        : effective
                                          ? "bg-muted text-muted-foreground border-border"
                                          : "bg-muted text-muted-foreground/40 border-border",
                                    )}
                                    title={`${hasOverride ? "Override: " : "Default: "}${effective ? "Granted" : "Denied"}`}
                                  >
                                    {effective ? <Check size={12} /> : <X size={12} />}
                                  </button>
                                  {hasOverride && (
                                    <span className="text-[9px] font-bold text-primary uppercase">override</span>
                                  )}
                                </div>
                              </td>
                            );
                          })}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </ScrollArea>

              <div className="p-3 border-t bg-muted/20 flex items-center gap-4 text-xs text-muted-foreground">
                <div className="flex items-center gap-1.5"><div className="w-4 h-4 rounded bg-primary/20 border border-primary/30" /> Override granted</div>
                <div className="flex items-center gap-1.5"><div className="w-4 h-4 rounded bg-destructive/10 border border-destructive/30" /> Override denied</div>
                <div className="flex items-center gap-1.5"><div className="w-4 h-4 rounded bg-muted border border-border" /> Role default</div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
TSX
ok "Permissions page"

# ===========================================================================
#  Done
# ===========================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}  Parts 4-7 complete!${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo "  Created:"
echo "    ✓ src/components/shared/  DataTable, StatCard, PageHeader,"
echo "                              EmptyState, DateRangePicker"
echo "    ✓ src/pages/menu/         Menu.tsx (items, categories, addons)"
echo "    ✓ src/pages/recipes/      Recipes.tsx (drink + addon recipes)"
echo "    ✓ src/pages/inventory/    Inventory.tsx (stock, adjustments, transfers)"
echo "    ✓ src/pages/shifts/       Shifts.tsx + full ShiftReportView"
echo "                              (payment breakdown, cash movements,"
echo "                               discrepancy, browser print)"
echo "    ✓ src/pages/analytics/    Analytics.tsx (6 tabs: overview, revenue,"
echo "                               items, tellers, branches, inventory)"
echo "    ✓ src/pages/permissions/  Permissions.tsx (matrix + overrides)"
echo ""
echo "  Run: npm run build"
echo ""