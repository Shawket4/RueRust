import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  Plus,
  Pencil,
  Trash2,
  Package,
  ArrowLeftRight,
  ClipboardList,
  Boxes,
  AlertTriangle,
} from "lucide-react";
import { type ColumnDef } from "@tanstack/react-table";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as inventoryApi from "@/api/inventory";
import * as branchesApi from "@/api/branches";
import type {
  OrgIngredient,
  BranchInventoryItem,
  BranchInventoryAdjustment,
  BranchInventoryTransfer,
  InventoryUnit,
} from "@/types";
import { fmtUnit } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { DataTable } from "@/components/shared/DataTable";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";

const UNITS: InventoryUnit[] = ["g", "kg", "ml", "l", "pcs"];

// ── Branch selector (uses store) ──────────────────────────────────────────────
function useBranchOrgIds() {
  const user = useAuthStore((s) => s.user);
  const selectedOrgId    = useAppStore((s) => s.selectedOrgId);
  const selectedBranchId = useAppStore((s) => s.selectedBranchId);
  const orgId    = selectedOrgId    ?? user?.org_id    ?? "";
  const branchId = selectedBranchId ?? "";
  return { orgId, branchId };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Org Catalog
// ═══════════════════════════════════════════════════════════════════════════════

function CatalogTab() {
  const { orgId } = useBranchOrgIds();
  const qc = useQueryClient();

  const { data: items = [], isLoading } = useQuery({
    queryKey: ["org-catalog", orgId],
    queryFn:  () => inventoryApi.getCatalog(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  // ── Create dialog ──────────────────────────────────────────────────────
  const [createOpen, setCreateOpen] = useState(false);
  const [createForm, setCreateForm] = useState({
    name: "", unit: "kg" as InventoryUnit, description: "", cost_per_unit: "",
  });

  const createMutation = useMutation({
    mutationFn: () =>
      inventoryApi.createCatalogItem(orgId, {
        name:          createForm.name.trim(),
        unit:          createForm.unit,
        description:   createForm.description || undefined,
        cost_per_unit: createForm.cost_per_unit ? Number(createForm.cost_per_unit) : 0,
      }),
    onSuccess: () => {
      toast.success("Ingredient added to catalog");
      qc.invalidateQueries({ queryKey: ["org-catalog"] });
      setCreateOpen(false);
      setCreateForm({ name: "", unit: "kg", description: "", cost_per_unit: "" });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Edit dialog ────────────────────────────────────────────────────────
  const [editItem, setEditItem] = useState<OrgIngredient | null>(null);
  const [editForm, setEditForm] = useState({
    name: "", unit: "kg" as InventoryUnit, description: "", cost_per_unit: "", is_active: true,
  });

  const openEdit = (item: OrgIngredient) => {
    setEditItem(item);
    setEditForm({
      name:          item.name,
      unit:          item.unit,
      description:   item.description ?? "",
      cost_per_unit: String(item.cost_per_unit),
      is_active:     item.is_active,
    });
  };

  const editMutation = useMutation({
    mutationFn: () =>
      inventoryApi.updateCatalogItem(orgId, editItem!.id, {
        name:          editForm.name,
        unit:          editForm.unit,
        description:   editForm.description || undefined,
        cost_per_unit: Number(editForm.cost_per_unit),
        is_active:     editForm.is_active,
      }),
    onSuccess: () => {
      toast.success("Ingredient updated");
      qc.invalidateQueries({ queryKey: ["org-catalog"] });
      setEditItem(null);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Delete ─────────────────────────────────────────────────────────────
  const deleteMutation = useMutation({
    mutationFn: (id: string) => inventoryApi.deleteCatalogItem(orgId, id),
    onSuccess:  () => { toast.success("Ingredient deleted"); qc.invalidateQueries({ queryKey: ["org-catalog"] }); },
    onError:    (e) => toast.error(getErrorMessage(e)),
  });

  // ── Columns ────────────────────────────────────────────────────────────
  const cols: ColumnDef<OrgIngredient, any>[] = [
    {
      accessorKey: "name",
      header: "Name",
      cell: ({ row }) => (
        <div>
          <p className="font-semibold text-sm">{row.original.name}</p>
          {row.original.description && (
            <p className="text-xs text-muted-foreground">{row.original.description}</p>
          )}
        </div>
      ),
    },
    {
      accessorKey: "unit",
      header: "Unit",
      cell: ({ row }) => <Badge variant="outline">{fmtUnit(row.original.unit)}</Badge>,
    },
    {
      accessorKey: "cost_per_unit",
      header: "Cost / unit",
      cell: ({ row }) => (
        <span className="tabular-nums text-sm">
          {row.original.cost_per_unit > 0 ? `${row.original.cost_per_unit} pt` : "—"}
        </span>
      ),
    },
    {
      accessorKey: "is_active",
      header: "Status",
      cell: ({ row }) => (
        <Badge variant={row.original.is_active ? "default" : "secondary"}>
          {row.original.is_active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <div className="flex items-center gap-1 justify-end" onClick={(e) => e.stopPropagation()}>
          <Button variant="ghost" size="icon-sm" onClick={() => openEdit(row.original)}>
            <Pencil size={14} />
          </Button>
          <Button
            variant="ghost"
            size="icon-sm"
            className="text-destructive"
            onClick={() => deleteMutation.mutate(row.original.id)}
            disabled={deleteMutation.isPending}
          >
            <Trash2 size={14} />
          </Button>
        </div>
      ),
    },
  ];

  if (isLoading) return <Skeleton className="h-64 w-full rounded-2xl" />;

  return (
    <div className="space-y-4">
      <PageHeader
        title="Ingredient Catalog"
        sub="Org-wide ingredients used in recipes and branch stock"
        actions={
          <Button onClick={() => setCreateOpen(true)}>
            <Plus size={16} className="mr-1" /> New Ingredient
          </Button>
        }
      />

      {items.length === 0 ? (
        <EmptyState
          icon={Boxes}
          title="No ingredients yet"
          sub="Add ingredients to the catalog, then track them per branch."
          action={
            <Button onClick={() => setCreateOpen(true)}>
              <Plus size={14} className="mr-1" /> Add First Ingredient
            </Button>
          }
        />
      ) : (
        <DataTable columns={cols} data={items} />
      )}

      {/* Create dialog */}
      <Dialog open={createOpen} onOpenChange={setCreateOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>New Catalog Ingredient</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1">
              <Label>Name *</Label>
              <Input
                value={createForm.name}
                onChange={(e) => setCreateForm((f) => ({ ...f, name: e.target.value }))}
                placeholder="e.g. Oat Milk"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Unit *</Label>
                <Select
                  value={createForm.unit}
                  onValueChange={(v) => setCreateForm((f) => ({ ...f, unit: v as InventoryUnit }))}
                >
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {UNITS.map((u) => <SelectItem key={u} value={u}>{fmtUnit(u)}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>Cost / unit (piastres)</Label>
                <Input
                  type="number"
                  min="0"
                  value={createForm.cost_per_unit}
                  onChange={(e) => setCreateForm((f) => ({ ...f, cost_per_unit: e.target.value }))}
                  placeholder="0"
                />
              </div>
            </div>
            <div className="space-y-1">
              <Label>Description</Label>
              <Input
                value={createForm.description}
                onChange={(e) => setCreateForm((f) => ({ ...f, description: e.target.value }))}
                placeholder="Optional"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreateOpen(false)}>Cancel</Button>
            <Button onClick={() => createMutation.mutate()} disabled={!createForm.name.trim() || createMutation.isPending}>
              {createMutation.isPending ? "Creating…" : "Create"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit dialog */}
      <Dialog open={!!editItem} onOpenChange={(o) => !o && setEditItem(null)}>
        <DialogContent>
          <DialogHeader><DialogTitle>Edit: {editItem?.name}</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1">
              <Label>Name</Label>
              <Input value={editForm.name} onChange={(e) => setEditForm((f) => ({ ...f, name: e.target.value }))} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Unit</Label>
                <Select value={editForm.unit} onValueChange={(v) => setEditForm((f) => ({ ...f, unit: v as InventoryUnit }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {UNITS.map((u) => <SelectItem key={u} value={u}>{fmtUnit(u)}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>Cost / unit</Label>
                <Input type="number" min="0" value={editForm.cost_per_unit} onChange={(e) => setEditForm((f) => ({ ...f, cost_per_unit: e.target.value }))} />
              </div>
            </div>
            <div className="space-y-1">
              <Label>Description</Label>
              <Input value={editForm.description} onChange={(e) => setEditForm((f) => ({ ...f, description: e.target.value }))} />
            </div>
            <div className="flex items-center gap-3">
              <Switch checked={editForm.is_active} onCheckedChange={(v) => setEditForm((f) => ({ ...f, is_active: v }))} />
              <Label>Active</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditItem(null)}>Cancel</Button>
            <Button onClick={() => editMutation.mutate()} disabled={editMutation.isPending}>
              {editMutation.isPending ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — Branch Stock
// ═══════════════════════════════════════════════════════════════════════════════

function StockTab() {
  const { orgId, branchId } = useBranchOrgIds();
  const qc = useQueryClient();

  const { data: stock = [], isLoading: stockLoading } = useQuery({
    queryKey: ["branch-stock", branchId],
    queryFn:  () => inventoryApi.getBranchStock(branchId).then((r) => r.data),
    enabled:  !!branchId,
  });

  const { data: catalog = [] } = useQuery({
    queryKey: ["org-catalog", orgId],
    queryFn:  () => inventoryApi.getCatalog(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  // Available = catalog items not yet tracked on this branch
  const trackedIds = new Set(stock.map((s) => s.org_ingredient_id));
  const available  = catalog.filter((c) => c.is_active && !trackedIds.has(c.id));

  // ── Add dialog ─────────────────────────────────────────────────────────
  const [addOpen, setAddOpen] = useState(false);
  const [addForm, setAddForm] = useState({ org_ingredient_id: "", current_stock: "", reorder_threshold: "" });

  const addMutation = useMutation({
    mutationFn: () =>
      inventoryApi.addToStock(branchId, {
        org_ingredient_id: addForm.org_ingredient_id,
        current_stock:     addForm.current_stock ? Number(addForm.current_stock) : 0,
        reorder_threshold: addForm.reorder_threshold ? Number(addForm.reorder_threshold) : 0,
      }),
    onSuccess: () => {
      toast.success("Ingredient added to branch stock");
      qc.invalidateQueries({ queryKey: ["branch-stock"] });
      setAddOpen(false);
      setAddForm({ org_ingredient_id: "", current_stock: "", reorder_threshold: "" });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Edit threshold inline ──────────────────────────────────────────────
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editThresh, setEditThresh] = useState("");

  const updateMutation = useMutation({
    mutationFn: ({ id, reorder_threshold }: { id: string; reorder_threshold: number }) =>
      inventoryApi.updateStock(branchId, id, { reorder_threshold }),
    onSuccess: () => {
      toast.success("Threshold updated");
      qc.invalidateQueries({ queryKey: ["branch-stock"] });
      setEditingId(null);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const removeMutation = useMutation({
    mutationFn: (id: string) => inventoryApi.removeFromStock(branchId, id),
    onSuccess:  () => { toast.success("Ingredient removed from branch"); qc.invalidateQueries({ queryKey: ["branch-stock"] }); },
    onError:    (e) => toast.error(getErrorMessage(e)),
  });

  const cols: ColumnDef<BranchInventoryItem, any>[] = [
    {
      accessorKey: "ingredient_name",
      header: "Ingredient",
      cell: ({ row }) => (
        <div className="flex items-center gap-2">
          {row.original.below_reorder && <AlertTriangle size={14} className="text-amber-500 shrink-0" />}
          <div>
            <p className="font-semibold text-sm">{row.original.ingredient_name}</p>
            {row.original.description && (
              <p className="text-xs text-muted-foreground">{row.original.description}</p>
            )}
          </div>
        </div>
      ),
    },
    {
      accessorKey: "unit",
      header: "Unit",
      cell: ({ row }) => <Badge variant="outline">{fmtUnit(row.original.unit)}</Badge>,
    },
    {
      accessorKey: "current_stock",
      header: "Current Stock",
      cell: ({ row }) => (
        <span className={`tabular-nums font-semibold text-sm ${row.original.below_reorder ? "text-amber-600" : ""}`}>
          {Number(row.original.current_stock).toFixed(3)}
        </span>
      ),
    },
    {
      accessorKey: "reorder_threshold",
      header: "Reorder At",
      cell: ({ row }) => {
        const item = row.original;
        if (editingId === item.id) {
          return (
            <div className="flex items-center gap-1">
              <Input
                type="number"
                value={editThresh}
                onChange={(e) => setEditThresh(e.target.value)}
                className="h-7 w-24 text-xs"
                step="0.001"
                min="0"
              />
              <Button
                size="icon-sm"
                variant="ghost"
                onClick={() => updateMutation.mutate({ id: item.id, reorder_threshold: Number(editThresh) })}
                disabled={updateMutation.isPending}
              >✓</Button>
              <Button size="icon-sm" variant="ghost" onClick={() => setEditingId(null)}>✕</Button>
            </div>
          );
        }
        return (
          <button
            className="tabular-nums text-sm hover:text-primary flex items-center gap-1"
            onClick={() => { setEditingId(item.id); setEditThresh(String(item.reorder_threshold)); }}
          >
            {Number(item.reorder_threshold).toFixed(3)} <Pencil size={11} className="opacity-50" />
          </button>
        );
      },
    },
    {
      accessorKey: "below_reorder",
      header: "Status",
      cell: ({ row }) => (
        <Badge variant={row.original.below_reorder ? "destructive" : "outline"}>
          {row.original.below_reorder ? "LOW" : "OK"}
        </Badge>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <div className="flex justify-end" onClick={(e) => e.stopPropagation()}>
          <Button
            variant="ghost"
            size="icon-sm"
            className="text-destructive"
            onClick={() => removeMutation.mutate(row.original.id)}
            disabled={removeMutation.isPending}
          >
            <Trash2 size={14} />
          </Button>
        </div>
      ),
    },
  ];

  if (!branchId) return <EmptyState icon={Package} title="Select a branch" sub="Choose a branch from the top bar to view its stock." />;
  if (stockLoading) return <Skeleton className="h-64 w-full rounded-2xl" />;

  return (
    <div className="space-y-4">
      <PageHeader
        title="Branch Stock"
        sub="Ingredients tracked for this branch"
        actions={
          <Button onClick={() => setAddOpen(true)} disabled={available.length === 0}>
            <Plus size={16} className="mr-1" />
            {available.length === 0 ? "All tracked" : "Add Ingredient"}
          </Button>
        }
      />

      {stock.length === 0 ? (
        <EmptyState
          icon={Package}
          title="No stock tracked"
          sub="Add ingredients from the org catalog to start tracking stock on this branch."
          action={<Button onClick={() => setAddOpen(true)}><Plus size={14} className="mr-1" /> Add Ingredient</Button>}
        />
      ) : (
        <DataTable columns={cols} data={stock} />
      )}

      <Dialog open={addOpen} onOpenChange={setAddOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>Add Ingredient to Branch</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1">
              <Label>Ingredient *</Label>
              <Select value={addForm.org_ingredient_id} onValueChange={(v) => setAddForm((f) => ({ ...f, org_ingredient_id: v }))}>
                <SelectTrigger><SelectValue placeholder="Select ingredient…" /></SelectTrigger>
                <SelectContent>
                  {available.map((c) => (
                    <SelectItem key={c.id} value={c.id}>{c.name} ({fmtUnit(c.unit)})</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Opening Stock</Label>
                <Input type="number" min="0" step="0.001" placeholder="0" value={addForm.current_stock} onChange={(e) => setAddForm((f) => ({ ...f, current_stock: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <Label>Reorder At</Label>
                <Input type="number" min="0" step="0.001" placeholder="0" value={addForm.reorder_threshold} onChange={(e) => setAddForm((f) => ({ ...f, reorder_threshold: e.target.value }))} />
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAddOpen(false)}>Cancel</Button>
            <Button onClick={() => addMutation.mutate()} disabled={!addForm.org_ingredient_id || addMutation.isPending}>
              {addMutation.isPending ? "Adding…" : "Add to Branch"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — Adjustments
// ═══════════════════════════════════════════════════════════════════════════════

function AdjustmentsTab() {
  const { branchId } = useBranchOrgIds();
  const qc = useQueryClient();

  const { data: adjs = [], isLoading } = useQuery({
    queryKey: ["branch-adjustments", branchId],
    queryFn:  () => inventoryApi.getAdjustments(branchId).then((r) => r.data),
    enabled:  !!branchId,
  });

  const { data: stock = [] } = useQuery({
    queryKey: ["branch-stock", branchId],
    queryFn:  () => inventoryApi.getBranchStock(branchId).then((r) => r.data),
    enabled:  !!branchId,
  });

  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    branch_inventory_id: "",
    adjustment_type: "add" as "add" | "remove",
    quantity: "",
    note: "",
  });

  const createMutation = useMutation({
    mutationFn: () =>
      inventoryApi.createAdjustment(branchId, {
        branch_inventory_id: form.branch_inventory_id,
        adjustment_type:     form.adjustment_type,
        quantity:            Number(form.quantity),
        note:                form.note.trim(),
      }),
    onSuccess: () => {
      toast.success("Adjustment saved");
      qc.invalidateQueries({ queryKey: ["branch-adjustments"] });
      qc.invalidateQueries({ queryKey: ["branch-stock"] });
      setOpen(false);
      setForm({ branch_inventory_id: "", adjustment_type: "add", quantity: "", note: "" });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const adjTypeBadge = (type: string) => {
    const colors: Record<string, string> = {
      add:          "bg-green-50 text-green-700 border-green-200 dark:bg-green-950 dark:text-green-300",
      remove:       "bg-red-50 text-red-700 border-red-200 dark:bg-red-950 dark:text-red-300",
      transfer_in:  "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950 dark:text-blue-300",
      transfer_out: "bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950 dark:text-amber-300",
    };
    return <Badge className={colors[type] ?? ""}>{type.replace("_", " ")}</Badge>;
  };

  const cols: ColumnDef<BranchInventoryAdjustment, any>[] = [
    {
      accessorKey: "ingredient_name",
      header: "Ingredient",
      cell: ({ row }) => (
        <div>
          <p className="font-semibold text-sm">{row.original.ingredient_name}</p>
          <p className="text-xs text-muted-foreground">{fmtUnit(row.original.unit)}</p>
        </div>
      ),
    },
    {
      accessorKey: "adjustment_type",
      header: "Type",
      cell: ({ row }) => adjTypeBadge(row.original.adjustment_type),
    },
    {
      accessorKey: "quantity",
      header: "Quantity",
      cell: ({ row }) => (
        <span className="tabular-nums font-semibold text-sm">
          {Number(row.original.quantity).toFixed(3)}
        </span>
      ),
    },
    {
      accessorKey: "note",
      header: "Note",
      cell: ({ row }) => <span className="text-sm text-muted-foreground">{row.original.note}</span>,
    },
    {
      accessorKey: "adjusted_by_name",
      header: "By",
      cell: ({ row }) => <span className="text-sm">{row.original.adjusted_by_name}</span>,
    },
    {
      accessorKey: "created_at",
      header: "Date",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground">
          {new Date(row.original.created_at).toLocaleString()}
        </span>
      ),
    },
  ];

  if (!branchId) return <EmptyState icon={ClipboardList} title="Select a branch" sub="Choose a branch to view its adjustments." />;
  if (isLoading) return <Skeleton className="h-64 w-full rounded-2xl" />;

  return (
    <div className="space-y-4">
      <PageHeader
        title="Adjustments"
        sub="Manual stock add / remove entries with required notes"
        actions={
          <Button onClick={() => setOpen(true)}>
            <Plus size={16} className="mr-1" /> Adjust Stock
          </Button>
        }
      />

      {adjs.length === 0 ? (
        <EmptyState icon={ClipboardList} title="No adjustments yet" />
      ) : (
        <DataTable columns={cols} data={adjs} />
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>Manual Stock Adjustment</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-1">
              <Label>Ingredient *</Label>
              <Select value={form.branch_inventory_id} onValueChange={(v) => setForm((f) => ({ ...f, branch_inventory_id: v }))}>
                <SelectTrigger><SelectValue placeholder="Select ingredient…" /></SelectTrigger>
                <SelectContent>
                  {stock.map((s) => (
                    <SelectItem key={s.id} value={s.id}>
                      {s.ingredient_name} — stock: {Number(s.current_stock).toFixed(3)} {fmtUnit(s.unit)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Type *</Label>
                <Select value={form.adjustment_type} onValueChange={(v) => setForm((f) => ({ ...f, adjustment_type: v as "add" | "remove" }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="add">Add</SelectItem>
                    <SelectItem value="remove">Remove</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>Quantity *</Label>
                <Input
                  type="number"
                  min="0.001"
                  step="0.001"
                  value={form.quantity}
                  onChange={(e) => setForm((f) => ({ ...f, quantity: e.target.value }))}
                />
              </div>
            </div>
            <div className="space-y-1">
              <Label>Note * <span className="text-muted-foreground text-xs">(required)</span></Label>
              <Input
                value={form.note}
                onChange={(e) => setForm((f) => ({ ...f, note: e.target.value }))}
                placeholder="Reason for adjustment…"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
            <Button
              onClick={() => createMutation.mutate()}
              disabled={!form.branch_inventory_id || !form.quantity || !form.note.trim() || createMutation.isPending}
            >
              {createMutation.isPending ? "Saving…" : "Save Adjustment"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4 — Transfers
// ═══════════════════════════════════════════════════════════════════════════════

function TransfersTab() {
  const { orgId, branchId } = useBranchOrgIds();
  const qc = useQueryClient();

  const [direction, setDirection] = useState<"" | "incoming" | "outgoing">("");

  const { data: transfers = [], isLoading } = useQuery({
    queryKey: ["branch-transfers", branchId, direction],
    queryFn:  () => inventoryApi.getTransfers(branchId, direction || undefined).then((r) => r.data),
    enabled:  !!branchId,
  });

  const { data: catalog = [] } = useQuery({
    queryKey: ["org-catalog", orgId],
    queryFn:  () => inventoryApi.getCatalog(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => branchesApi.getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    source_branch_id:      branchId,
    destination_branch_id: "",
    org_ingredient_id:     "",
    quantity:              "",
    note:                  "",
  });

  const createMutation = useMutation({
    mutationFn: () =>
      inventoryApi.createTransfer({
        source_branch_id:      form.source_branch_id,
        destination_branch_id: form.destination_branch_id,
        org_ingredient_id:     form.org_ingredient_id,
        quantity:              Number(form.quantity),
        note:                  form.note || undefined,
      }),
    onSuccess: () => {
      toast.success("Transfer applied");
      qc.invalidateQueries({ queryKey: ["branch-transfers"] });
      qc.invalidateQueries({ queryKey: ["branch-stock"] });
      setOpen(false);
      setForm({ source_branch_id: branchId, destination_branch_id: "", org_ingredient_id: "", quantity: "", note: "" });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const cols: ColumnDef<BranchInventoryTransfer, any>[] = [
    {
      accessorKey: "ingredient_name",
      header: "Ingredient",
      cell: ({ row }) => (
        <div>
          <p className="font-semibold text-sm">{row.original.ingredient_name}</p>
          <p className="text-xs text-muted-foreground">{fmtUnit(row.original.unit)}</p>
        </div>
      ),
    },
    {
      accessorKey: "source_branch_name",
      header: "From",
      cell: ({ row }) => (
        <span className={row.original.source_branch_id === branchId ? "font-semibold" : "text-muted-foreground text-sm"}>
          {row.original.source_branch_name}
        </span>
      ),
    },
    {
      accessorKey: "destination_branch_name",
      header: "To",
      cell: ({ row }) => (
        <span className={row.original.destination_branch_id === branchId ? "font-semibold" : "text-muted-foreground text-sm"}>
          {row.original.destination_branch_name}
        </span>
      ),
    },
    {
      accessorKey: "quantity",
      header: "Quantity",
      cell: ({ row }) => (
        <span className="tabular-nums font-semibold text-sm">{Number(row.original.quantity).toFixed(3)}</span>
      ),
    },
    {
      accessorKey: "note",
      header: "Note",
      cell: ({ row }) => <span className="text-sm text-muted-foreground">{row.original.note ?? "—"}</span>,
    },
    {
      accessorKey: "initiated_by_name",
      header: "By",
      cell: ({ row }) => <span className="text-sm">{row.original.initiated_by_name}</span>,
    },
    {
      accessorKey: "initiated_at",
      header: "Date",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground">
          {new Date(row.original.initiated_at).toLocaleString()}
        </span>
      ),
    },
  ];

  if (!branchId) return <EmptyState icon={ArrowLeftRight} title="Select a branch" sub="Choose a branch to view its transfers." />;
  if (isLoading) return <Skeleton className="h-64 w-full rounded-2xl" />;

  return (
    <div className="space-y-4">
      <PageHeader
        title="Transfers"
        sub="Stock moved between branches — applied immediately"
        actions={
          <div className="flex items-center gap-2">
            <Select value={direction} onValueChange={(v) => setDirection(v as any)}>
              <SelectTrigger className="w-36"><SelectValue placeholder="All transfers" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="">All</SelectItem>
                <SelectItem value="incoming">Incoming</SelectItem>
                <SelectItem value="outgoing">Outgoing</SelectItem>
              </SelectContent>
            </Select>
            <Button onClick={() => setOpen(true)}>
              <Plus size={16} className="mr-1" /> New Transfer
            </Button>
          </div>
        }
      />

      {transfers.length === 0 ? (
        <EmptyState icon={ArrowLeftRight} title="No transfers found" />
      ) : (
        <DataTable columns={cols} data={transfers} />
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>Transfer Stock</DialogTitle></DialogHeader>
          <div className="space-y-4 py-2">
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>From Branch *</Label>
                <Select value={form.source_branch_id} onValueChange={(v) => setForm((f) => ({ ...f, source_branch_id: v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {branches.map((b) => <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>To Branch *</Label>
                <Select value={form.destination_branch_id} onValueChange={(v) => setForm((f) => ({ ...f, destination_branch_id: v }))}>
                  <SelectTrigger><SelectValue placeholder="Select…" /></SelectTrigger>
                  <SelectContent>
                    {branches.filter((b) => b.id !== form.source_branch_id).map((b) => (
                      <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <Label>Ingredient *</Label>
                <Select value={form.org_ingredient_id} onValueChange={(v) => setForm((f) => ({ ...f, org_ingredient_id: v }))}>
                  <SelectTrigger><SelectValue placeholder="Select…" /></SelectTrigger>
                  <SelectContent>
                    {catalog.filter((c) => c.is_active).map((c) => (
                      <SelectItem key={c.id} value={c.id}>{c.name} ({fmtUnit(c.unit)})</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>Quantity *</Label>
                <Input type="number" min="0.001" step="0.001" value={form.quantity} onChange={(e) => setForm((f) => ({ ...f, quantity: e.target.value }))} />
              </div>
            </div>
            <div className="space-y-1">
              <Label>Note</Label>
              <Input value={form.note} onChange={(e) => setForm((f) => ({ ...f, note: e.target.value }))} placeholder="Optional reason" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>Cancel</Button>
            <Button
              onClick={() => createMutation.mutate()}
              disabled={!form.destination_branch_id || !form.org_ingredient_id || !form.quantity || createMutation.isPending}
            >
              {createMutation.isPending ? "Transferring…" : "Transfer"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main page
// ═══════════════════════════════════════════════════════════════════════════════

export default function Inventory() {
  return (
    <div className="p-6">
      <Tabs defaultValue="catalog">
        <TabsList className="mb-6">
          <TabsTrigger value="catalog"><Boxes size={14} className="mr-1.5" /> Catalog</TabsTrigger>
          <TabsTrigger value="stock"><Package size={14} className="mr-1.5" /> Branch Stock</TabsTrigger>
          <TabsTrigger value="adjustments"><ClipboardList size={14} className="mr-1.5" /> Adjustments</TabsTrigger>
          <TabsTrigger value="transfers"><ArrowLeftRight size={14} className="mr-1.5" /> Transfers</TabsTrigger>
        </TabsList>
        <TabsContent value="catalog"><CatalogTab /></TabsContent>
        <TabsContent value="stock"><StockTab /></TabsContent>
        <TabsContent value="adjustments"><AdjustmentsTab /></TabsContent>
        <TabsContent value="transfers"><TransfersTab /></TabsContent>
      </Tabs>
    </div>
  );
}
