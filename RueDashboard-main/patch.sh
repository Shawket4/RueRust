#!/bin/bash
set -e
echo "=== Patching Rue POS Frontend ==="

# ── src/types/index.ts ────────────────────────────────────────
cat > src/types/index.ts << 'EOF'
export type UserRole = "super_admin" | "org_admin" | "branch_manager" | "teller";

export interface UserPublic {
  id:        string;
  org_id:    string | null;
  branch_id: string | null;
  name:      string;
  email:     string | null;
  phone:     string | null;
  role:      UserRole;
  is_active: boolean;
}

export interface LoginResponse {
  token: string;
  user:  UserPublic;
}

export interface Org {
  id:             string;
  name:           string;
  slug:           string;
  logo_url:       string | null;
  currency_code:  string;
  tax_rate:       number;
  receipt_footer: string | null;
  is_active:      boolean;
}

export type PrinterBrand = "star" | "epson";

export interface Branch {
  id:            string;
  org_id:        string;
  name:          string;
  address:       string | null;
  phone:         string | null;
  timezone:      string;
  printer_brand: PrinterBrand | null;
  printer_ip:    string | null;
  printer_port:  number | null;
  is_active:     boolean;
  created_at:    string;
  updated_at:    string;
}

export interface UserBranch {
  branch_id:   string;
  branch_name: string;
}

export interface Permission {
  id:       string;
  user_id:  string;
  resource: string;
  action:   string;
  granted:  boolean;
}

export interface RolePermission {
  role:     string;
  resource: string;
  action:   string;
  granted:  boolean;
}

export interface PermissionMatrix {
  resource:      string;
  action:        string;
  role_default:  boolean | null;
  user_override: boolean | null;
  effective:     boolean;
}

// ── Org ingredient catalog ────────────────────────────────────
export type InventoryUnit = "g" | "kg" | "ml" | "l" | "pcs";

export interface OrgIngredient {
  id:         string;
  org_id:     string;
  name:       string;
  unit:       InventoryUnit;
  created_at: string;
  updated_at: string;
}

// ── Branch inventory ──────────────────────────────────────────
export interface BranchInventory {
  id:                string;
  branch_id:         string;
  org_ingredient_id: string;
  ingredient_name:   string;
  unit:              InventoryUnit;
  current_stock:     number;
  reorder_threshold: number;
  cost_per_unit:     number;
  is_active:         boolean;
  created_at:        string;
  updated_at:        string;
}

export interface InventoryAdjustment {
  id:                  string;
  branch_inventory_id: string;
  branch_id:           string;
  ingredient_name:     string;
  unit:                string;
  adjustment_type:     "add" | "remove";
  quantity:            number;
  note:                string;
  adjusted_by:         string;
  adjusted_by_name:    string;
  created_at:          string;
}

export interface TransferResponse {
  source_adjustment:      InventoryAdjustment;
  destination_adjustment: InventoryAdjustment;
}

// ── Menu ──────────────────────────────────────────────────────
export interface Category {
  id:            string;
  org_id:        string;
  name:          string;
  image_url:     string | null;
  display_order: number;
  is_active:     boolean;
  created_at:    string;
  updated_at:    string;
}

export type AddonType = "coffee_type" | "milk_type" | "extra";

export interface AddonItem {
  id:            string;
  org_id:        string;
  name:          string;
  addon_type:    AddonType;
  default_price: number;
  is_active:     boolean;
  display_order: number;
  created_at:    string;
  updated_at:    string;
}

export interface ItemSize {
  id:             string;
  menu_item_id:   string;
  label:          string;
  price_override: number;
  display_order:  number;
  is_active:      boolean;
}

export interface DrinkOptionItemFull {
  id:             string;
  group_id:       string;
  addon_item_id:  string;
  price_override: number | null;
  display_order:  number;
  is_active:      boolean;
  name:           string;
  default_price:  number;
  addon_type:     AddonType;
}

export interface DrinkOptionGroupFull {
  id:             string;
  menu_item_id:   string;
  group_type:     AddonType;
  selection_type: "single" | "multi";
  is_required:    boolean;
  min_selections: number;
  display_order:  number;
  items:          DrinkOptionItemFull[];
}

export interface MenuItem {
  id:            string;
  org_id:        string;
  category_id:   string | null;
  name:          string;
  description:   string | null;
  image_url:     string | null;
  base_price:    number;
  is_active:     boolean;
  display_order: number;
  created_at:    string;
  updated_at:    string;
}

export interface MenuItemFull extends MenuItem {
  sizes:         ItemSize[];
  option_groups: DrinkOptionGroupFull[];
}

// ── Recipes ───────────────────────────────────────────────────
export interface MenuItemRecipe {
  id:                string;
  menu_item_id:      string;
  size_label:        string;
  org_ingredient_id: string;
  ingredient_name:   string;
  unit:              string;
  quantity_used:     number;
}

export interface AddonIngredient {
  id:                string;
  addon_item_id:     string;
  org_ingredient_id: string;
  ingredient_name:   string;
  unit:              string;
  quantity_used:     number;
}

export interface DrinkOptionOverride {
  id:                   string;
  drink_option_item_id: string;
  size_label:           string | null;
  org_ingredient_id:    string;
  ingredient_name:      string;
  unit:                 string;
  quantity_used:        number;
}

// ── Orders ────────────────────────────────────────────────────
export type PaymentMethod =
  | "cash" | "card" | "digital_wallet" | "mixed"
  | "talabat_online" | "talabat_cash";

export type OrderStatus = "completed" | "voided";

export interface OrderItemAddon {
  id:            string;
  order_item_id: string;
  addon_item_id: string;
  addon_name:    string;
  unit_price:    number;
  quantity:      number;
  line_total:    number;
}

export interface OrderItem {
  id:           string;
  order_id:     string;
  menu_item_id: string;
  item_name:    string;
  size_label:   string | null;
  unit_price:   number;
  quantity:     number;
  line_total:   number;
  notes:        string | null;
  addons:       OrderItemAddon[];
}

export interface Order {
  id:              string;
  branch_id:       string;
  shift_id:        string;
  teller_id:       string;
  teller_name:     string;
  order_number:    number;
  status:          OrderStatus;
  payment_method:  PaymentMethod;
  subtotal:        number;
  discount_type:   "percentage" | "fixed" | null;
  discount_value:  number;
  discount_amount: number;
  tax_amount:      number;
  total_amount:    number;
  customer_name:   string | null;
  notes:           string | null;
  amount_tendered: number | null;
  change_given:    number | null;
  tip_amount:      number;
  discount_id:     string | null;
  voided_at:       string | null;
  void_reason:     string | null;
  voided_by:       string | null;
  created_at:      string;
  items?:          OrderItem[];
}

// ── Shifts ────────────────────────────────────────────────────
export type ShiftStatus = "open" | "closed" | "force_closed";

export interface Shift {
  id:                        string;
  branch_id:                 string;
  teller_id:                 string;
  teller_name:               string;
  status:                    ShiftStatus;
  opening_cash:              number;
  opening_cash_original:     number | null;
  opening_cash_was_edited:   boolean;
  opening_cash_edit_reason:  string | null;
  closing_cash_declared:     number | null;
  closing_cash_system:       number | null;
  cash_discrepancy:          number | null;
  opened_at:                 string;
  closed_at:                 string | null;
  closed_by:                 string | null;
  force_closed_by:           string | null;
  force_closed_at:           string | null;
  force_close_reason:        string | null;
  notes:                     string | null;
}

export interface ShiftPreFill {
  has_open_shift:         boolean;
  open_shift:             Shift | null;
  suggested_opening_cash: number;
}

export interface CashMovement {
  id:            string;
  shift_id:      string;
  amount:        number;
  note:          string;
  moved_by:      string;
  moved_by_name: string;
  created_at:    string;
}

export interface PaymentSummaryRow {
  payment_method: PaymentMethod;
  total:          number;
  order_count:    number;
}

export interface CashMovementSummaryRow {
  amount:        number;
  note:          string;
  moved_by_name: string;
  created_at:    string;
}

export interface ShiftReport {
  shift:               Shift;
  payment_summary:     PaymentSummaryRow[];
  total_payments:      number;
  total_returns:       number;
  net_payments:        number;
  cash_movements:      CashMovementSummaryRow[];
  cash_movements_in:   number;
  cash_movements_out:  number;
  cash_movements_net:  number;
  printed_at:          string;
}

// ── Reports ───────────────────────────────────────────────────
export interface ItemSales {
  menu_item_id:  string;
  item_name:     string;
  quantity_sold: number;
  revenue:       number;
}

export interface CategorySales {
  category_id:   string | null;
  category_name: string | null;
  item_count:    number;
  quantity_sold: number;
  revenue:       number;
  items:         ItemSales[];
}

export interface BranchSalesReport {
  branch_id:              string;
  branch_name:            string;
  from:                   string | null;
  to:                     string | null;
  total_orders:           number;
  voided_orders:          number;
  subtotal:               number;
  total_discount:         number;
  total_tax:              number;
  total_revenue:          number;
  cash_revenue:           number;
  card_revenue:           number;
  digital_wallet_revenue: number;
  mixed_revenue:          number;
  talabat_online_revenue: number;
  talabat_cash_revenue:   number;
  top_items:              ItemSales[];
  by_category:            CategorySales[];
}

export interface TimeseriesPoint {
  period:                 string;
  orders:                 number;
  revenue:                number;
  voided:                 number;
  discount:               number;
  tax:                    number;
  cash_revenue:           number;
  card_revenue:           number;
  digital_wallet_revenue: number;
  mixed_revenue:          number;
  talabat_online_revenue: number;
  talabat_cash_revenue:   number;
}

export interface TellerStats {
  teller_id:       string;
  teller_name:     string;
  orders:          number;
  revenue:         number;
  avg_order_value: number;
  voided:          number;
  shifts:          number;
}

export interface AddonSalesRow {
  addon_item_id: string;
  addon_name:    string;
  addon_type:    AddonType;
  quantity_sold: number;
  revenue:       number;
}

export interface BranchComparison {
  branch_id:              string;
  branch_name:            string;
  total_orders:           number;
  voided_orders:          number;
  total_revenue:          number;
  cash_revenue:           number;
  card_revenue:           number;
  digital_wallet_revenue: number;
  mixed_revenue:          number;
  talabat_online_revenue: number;
  talabat_cash_revenue:   number;
  avg_order_value:        number;
  void_rate_pct:          number;
}

export interface OrgComparisonReport {
  org_id:   string;
  from:     string | null;
  to:       string | null;
  branches: BranchComparison[];
}

export interface StockRow {
  inventory_item_id: string;
  item_name:         string;
  unit:              string;
  current_stock:     number;
  reorder_threshold: number;
  cost_per_unit:     number | null;
  below_reorder:     boolean;
  is_active:         boolean;
}

export interface BranchStockReport {
  branch_id:   string;
  branch_name: string;
  items:       StockRow[];
}

// ── Discounts ─────────────────────────────────────────────────
export interface Discount {
  id:         string;
  org_id:     string;
  name:       string;
  dtype:      "percentage" | "fixed";
  value:      number;
  is_active:  boolean;
  created_at: string;
  updated_at: string;
}
EOF

# ── src/api/inventory.ts ──────────────────────────────────────
cat > src/api/inventory.ts << 'EOF'
import client from "@/lib/client";
import type {
  OrgIngredient, BranchInventory, InventoryAdjustment, TransferResponse
} from "@/types";

// Org ingredient catalog
export const getOrgIngredients = (orgId: string) =>
  client.get<OrgIngredient[]>(`/inventory/orgs/${orgId}/ingredients`);

export const createOrgIngredient = (orgId: string, data: { name: string; unit: string }) =>
  client.post<OrgIngredient>(`/inventory/orgs/${orgId}/ingredients`, data);

export const updateOrgIngredient = (id: string, data: { name?: string; unit?: string }) =>
  client.patch<OrgIngredient>(`/inventory/ingredients/${id}`, data);

export const deleteOrgIngredient = (id: string) =>
  client.delete(`/inventory/ingredients/${id}`);

// Branch inventory
export const getBranchInventory = (branchId: string) =>
  client.get<BranchInventory[]>(`/inventory/branches/${branchId}`);

export const addToBranch = (branchId: string, data: {
  org_ingredient_id: string;
  current_stock?:    number;
  reorder_threshold?: number;
  cost_per_unit?:    number;
}) => client.post<BranchInventory>(`/inventory/branches/${branchId}`, data);

export const updateBranchInventory = (id: string, data: {
  reorder_threshold?: number;
  cost_per_unit?:     number;
  is_active?:         boolean;
}) => client.patch<BranchInventory>(`/inventory/branch-inventory/${id}`, data);

export const removeFromBranch = (id: string) =>
  client.delete(`/inventory/branch-inventory/${id}`);

// Adjustments
export const adjustStock = (id: string, data: {
  adjustment_type: "add" | "remove";
  quantity:        number;
  note:            string;
}) => client.post<InventoryAdjustment>(`/inventory/branch-inventory/${id}/adjust`, data);

export const getAdjustments = (branchId: string) =>
  client.get<InventoryAdjustment[]>(`/inventory/branches/${branchId}/adjustments`);

// Transfer
export const transferStock = (data: {
  source_branch_id:      string;
  destination_branch_id: string;
  branch_inventory_id:   string;
  quantity:              number;
  note?:                 string;
}) => client.post<TransferResponse>(`/inventory/transfer`, data);
EOF

# ── src/api/recipes.ts ────────────────────────────────────────
cat > src/api/recipes.ts << 'EOF'
import client from "@/lib/client";
import type { MenuItemRecipe, AddonIngredient, DrinkOptionOverride } from "@/types";

export const getDrinkRecipes = (menuItemId: string) =>
  client.get<MenuItemRecipe[]>(`/recipes/drinks/${menuItemId}`);

export const upsertDrinkRecipe = (menuItemId: string, data: {
  size_label:        string;
  org_ingredient_id: string;
  quantity_used:     number;
}) => client.post<MenuItemRecipe>(`/recipes/drinks/${menuItemId}`, data);

export const deleteDrinkRecipe = (menuItemId: string, size: string, orgIngredientId: string) =>
  client.delete(`/recipes/drinks/${menuItemId}/${size}`, {
    params: { org_ingredient_id: orgIngredientId }
  });

export const getAddonIngredients = (addonItemId: string) =>
  client.get<AddonIngredient[]>(`/recipes/addons/${addonItemId}`);

export const upsertAddonIngredient = (addonItemId: string, data: {
  org_ingredient_id: string;
  quantity_used:     number;
}) => client.post<AddonIngredient>(`/recipes/addons/${addonItemId}`, data);

export const deleteAddonIngredient = (addonItemId: string, orgIngredientId: string) =>
  client.delete(`/recipes/addons/${addonItemId}`, {
    params: { org_ingredient_id: orgIngredientId }
  });

export const getOverrides = (drinkOptionItemId: string) =>
  client.get<DrinkOptionOverride[]>(`/recipes/overrides/${drinkOptionItemId}`);

export const upsertOverride = (drinkOptionItemId: string, data: {
  size_label?:       string;
  org_ingredient_id: string;
  quantity_used:     number;
}) => client.post<DrinkOptionOverride>(`/recipes/overrides/${drinkOptionItemId}`, data);

export const deleteOverride = (drinkOptionItemId: string, orgIngredientId: string) =>
  client.delete(`/recipes/overrides/${drinkOptionItemId}`, {
    params: { org_ingredient_id: orgIngredientId }
  });
EOF

# ── src/utils/format.ts (add UNIT_LABELS) ────────────────────
cat >> src/utils/format.ts << 'EOF'

export const UNIT_LABELS: Record<string, string> = {
  g:   "Grams",
  kg:  "Kilograms",
  ml:  "Milliliters",
  l:   "Liters",
  pcs: "Pieces",
};
EOF

# ── src/pages/inventory/Inventory.tsx ────────────────────────
mkdir -p src/pages/inventory
cat > src/pages/inventory/Inventory.tsx << 'EOF'
import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Plus, Pencil, Trash2, Package, AlertTriangle, ArrowRightLeft } from "lucide-react";
import { type ColumnDef } from "@tanstack/react-table";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as inventoryApi from "@/api/inventory";
import * as branchesApi from "@/api/branches";
import type { OrgIngredient, BranchInventory, InventoryAdjustment } from "@/types";
import { egp, fmtDateTime, UNIT_LABELS } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { DataTable } from "@/components/shared/DataTable";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";

export default function Inventory() {
  const user   = useAuthStore((s) => s.user);
  const orgId  = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const qc     = useQueryClient();
  const [tab, setTab] = useState("catalog");

  // Branch selection for stock tab
  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => branchesApi.getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });
  const [selBranch, setSelBranch] = useState("");
  React.useEffect(() => {
    if (branches.length > 0 && !selBranch) setSelBranch(branches[0].id);
  }, [branches, selBranch]);

  // ── Org Ingredient Catalog ────────────────────────────────

  const { data: ingredients = [], isLoading: ingLoading } = useQuery({
    queryKey: ["org-ingredients", orgId],
    queryFn:  () => inventoryApi.getOrgIngredients(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const [ingDialog, setIngDialog] = useState(false);
  const [editIng,   setEditIng]   = useState<OrgIngredient | null>(null);
  const [ingForm,   setIngForm]   = useState({ name: "", unit: "g" });

  const openIngDialog = (ing?: OrgIngredient) => {
    setEditIng(ing ?? null);
    setIngForm({ name: ing?.name ?? "", unit: ing?.unit ?? "g" });
    setIngDialog(true);
  };

  const ingMutation = useMutation({
    mutationFn: () => editIng
      ? inventoryApi.updateOrgIngredient(editIng.id, ingForm)
      : inventoryApi.createOrgIngredient(orgId, ingForm),
    onSuccess: () => {
      toast.success(editIng ? "Ingredient updated" : "Ingredient created");
      qc.invalidateQueries({ queryKey: ["org-ingredients"] });
      setIngDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const delIngMutation = useMutation({
    mutationFn: (id: string) => inventoryApi.deleteOrgIngredient(id),
    onSuccess: () => {
      toast.success("Ingredient deleted");
      qc.invalidateQueries({ queryKey: ["org-ingredients"] });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const ingCols: ColumnDef<OrgIngredient, any>[] = [
    {
      accessorKey: "name",
      header: "Name",
      cell: ({ row }) => <span className="font-semibold">{row.original.name}</span>,
    },
    {
      accessorKey: "unit",
      header: "Unit",
      cell: ({ row }) => (
        <Badge variant="outline">{UNIT_LABELS[row.original.unit] ?? row.original.unit}</Badge>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <div className="flex items-center gap-1 justify-end">
          <Button variant="ghost" size="icon-sm" onClick={() => openIngDialog(row.original)}>
            <Pencil size={13} />
          </Button>
          <Button
            variant="ghost" size="icon-sm"
            className="text-destructive"
            onClick={() => {
              if (confirm(`Delete "${row.original.name}"? This will fail if it is used in any recipe.`))
                delIngMutation.mutate(row.original.id);
            }}
          >
            <Trash2 size={13} />
          </Button>
        </div>
      ),
    },
  ];

  // ── Branch Stock ──────────────────────────────────────────

  const { data: branchInv = [], isLoading: invLoading } = useQuery({
    queryKey: ["branch-inventory", selBranch],
    queryFn:  () => inventoryApi.getBranchInventory(selBranch).then((r) => r.data),
    enabled:  !!selBranch,
  });

  const { data: adjustments = [] } = useQuery({
    queryKey: ["adjustments", selBranch],
    queryFn:  () => inventoryApi.getAdjustments(selBranch).then((r) => r.data),
    enabled:  !!selBranch,
  });

  // Add ingredient to branch dialog
  const [addDialog,  setAddDialog]  = useState(false);
  const [addForm,    setAddForm]    = useState({
    org_ingredient_id: "",
    current_stock:     "",
    reorder_threshold: "",
    cost_per_unit:     "",
  });

  // Already-tracked ingredient IDs for this branch
  const trackedIds = new Set(branchInv.map((b) => b.org_ingredient_id));
  const untrackedIngredients = ingredients.filter((i) => !trackedIds.has(i.id));

  const addMutation = useMutation({
    mutationFn: () => inventoryApi.addToBranch(selBranch, {
      org_ingredient_id: addForm.org_ingredient_id,
      current_stock:     parseFloat(addForm.current_stock) || 0,
      reorder_threshold: parseFloat(addForm.reorder_threshold) || 0,
      cost_per_unit:     Math.round((parseFloat(addForm.cost_per_unit) || 0) * 100),
    }),
    onSuccess: () => {
      toast.success("Ingredient added to branch");
      qc.invalidateQueries({ queryKey: ["branch-inventory"] });
      setAddDialog(false);
      setAddForm({ org_ingredient_id: "", current_stock: "", reorder_threshold: "", cost_per_unit: "" });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // Adjust stock dialog
  const [adjDialog, setAdjDialog] = useState(false);
  const [adjItem,   setAdjItem]   = useState<BranchInventory | null>(null);
  const [adjForm,   setAdjForm]   = useState({
    adjustment_type: "add" as "add" | "remove",
    quantity: "",
    note: "",
  });

  const adjMutation = useMutation({
    mutationFn: () => inventoryApi.adjustStock(adjItem!.id, {
      adjustment_type: adjForm.adjustment_type,
      quantity:        parseFloat(adjForm.quantity),
      note:            adjForm.note,
    }),
    onSuccess: () => {
      toast.success("Stock adjusted");
      qc.invalidateQueries({ queryKey: ["branch-inventory"] });
      qc.invalidateQueries({ queryKey: ["adjustments"] });
      setAdjDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // Transfer dialog
  const [transDialog, setTransDialog] = useState(false);
  const [transItem,   setTransItem]   = useState<BranchInventory | null>(null);
  const [transForm,   setTransForm]   = useState({
    destination_branch_id: "",
    quantity:              "",
    note:                  "",
  });

  const transMutation = useMutation({
    mutationFn: () => inventoryApi.transferStock({
      source_branch_id:      selBranch,
      destination_branch_id: transForm.destination_branch_id,
      branch_inventory_id:   transItem!.id,
      quantity:              parseFloat(transForm.quantity),
      note:                  transForm.note || undefined,
    }),
    onSuccess: () => {
      toast.success("Transfer complete");
      qc.invalidateQueries({ queryKey: ["branch-inventory"] });
      qc.invalidateQueries({ queryKey: ["adjustments"] });
      setTransDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const removeInvMutation = useMutation({
    mutationFn: (id: string) => inventoryApi.removeFromBranch(id),
    onSuccess: () => {
      toast.success("Removed");
      qc.invalidateQueries({ queryKey: ["branch-inventory"] });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const lowStock = branchInv.filter(
    (i) => parseFloat(String(i.current_stock)) <= parseFloat(String(i.reorder_threshold))
  );

  const invCols: ColumnDef<BranchInventory, any>[] = [
    {
      accessorKey: "ingredient_name",
      header: "Ingredient",
      cell: ({ row }) => (
        <div className="flex items-center gap-2">
          {parseFloat(String(row.original.current_stock)) <= parseFloat(String(row.original.reorder_threshold)) && (
            <AlertTriangle size={13} className="text-amber-500 flex-shrink-0" />
          )}
          <span className="font-semibold">{row.original.ingredient_name}</span>
        </div>
      ),
    },
    {
      accessorKey: "unit",
      header: "Unit",
      cell: ({ row }) => <Badge variant="outline">{row.original.unit}</Badge>,
    },
    {
      accessorKey: "current_stock",
      header: "Stock",
      cell: ({ row }) => {
        const curr  = parseFloat(String(row.original.current_stock));
        const thresh = parseFloat(String(row.original.reorder_threshold));
        const low   = curr <= thresh;
        return (
          <span className={`font-semibold tabular-nums text-sm ${low ? "text-amber-600" : ""}`}>
            {curr} {row.original.unit}
          </span>
        );
      },
    },
    {
      accessorKey: "reorder_threshold",
      header: "Reorder At",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground">
          {parseFloat(String(row.original.reorder_threshold))} {row.original.unit}
        </span>
      ),
    },
    {
      accessorKey: "cost_per_unit",
      header: "Cost/Unit",
      cell: ({ row }) => (
        <span className="text-xs tabular-nums">
          {row.original.cost_per_unit ? egp(row.original.cost_per_unit) : "—"}
        </span>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <div className="flex items-center gap-1 justify-end">
          <Button
            variant="ghost" size="sm" className="h-7 text-xs"
            onClick={() => { setAdjItem(row.original); setAdjDialog(true); }}
          >
            Adjust
          </Button>
          <Button
            variant="ghost" size="icon-sm"
            onClick={() => { setTransItem(row.original); setTransDialog(true); }}
          >
            <ArrowRightLeft size={13} />
          </Button>
          <Button
            variant="ghost" size="icon-sm" className="text-destructive"
            onClick={() => {
              if (confirm(`Remove "${row.original.ingredient_name}" from this branch?`))
                removeInvMutation.mutate(row.original.id);
            }}
          >
            <Trash2 size={13} />
          </Button>
        </div>
      ),
    },
  ];

  const adjCols: ColumnDef<InventoryAdjustment, any>[] = [
    {
      accessorKey: "ingredient_name",
      header: "Ingredient",
      cell: ({ row }) => <span className="font-semibold text-sm">{row.original.ingredient_name}</span>,
    },
    {
      accessorKey: "adjustment_type",
      header: "Type",
      cell: ({ row }) => (
        <Badge variant={row.original.adjustment_type === "add" ? "success" : "warning"}>
          {row.original.adjustment_type}
        </Badge>
      ),
    },
    {
      accessorKey: "quantity",
      header: "Qty",
      cell: ({ row }) => (
        <span className="tabular-nums text-sm">
          {parseFloat(String(row.original.quantity))} {row.original.unit}
        </span>
      ),
    },
    {
      accessorKey: "note",
      header: "Note",
      cell: ({ row }) => <span className="text-xs text-muted-foreground">{row.original.note}</span>,
    },
    {
      accessorKey: "adjusted_by_name",
      header: "By",
      cell: ({ row }) => <span className="text-xs">{row.original.adjusted_by_name}</span>,
    },
    {
      accessorKey: "created_at",
      header: "Date",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground">{fmtDateTime(row.original.created_at)}</span>
      ),
    },
  ];

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader
        title="Inventory"
        sub="Manage ingredient catalog and branch stock"
      />

      <Tabs value={tab} onValueChange={setTab}>
        <TabsList className="mb-6">
          <TabsTrigger value="catalog">
            <Package size={14} /> Org Catalog ({ingredients.length})
          </TabsTrigger>
          <TabsTrigger value="stock">
            Stock{lowStock.length > 0 && (
              <Badge variant="warning" className="ml-1 h-4 text-[10px]">{lowStock.length}</Badge>
            )}
          </TabsTrigger>
          <TabsTrigger value="adjustments">History</TabsTrigger>
        </TabsList>

        {/* ── Catalog tab ── */}
        <TabsContent value="catalog">
          <div className="flex justify-end mb-4">
            <Button onClick={() => openIngDialog()}>
              <Plus size={14} /> Add Ingredient
            </Button>
          </div>
          {ingLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-12 rounded-xl" />
              ))}
            </div>
          ) : ingredients.length === 0 ? (
            <EmptyState
              icon={Package}
              title="No ingredients yet"
              sub="Add ingredients that your branches can track and recipes can reference"
              action={<Button onClick={() => openIngDialog()}><Plus size={13} /> Add First Ingredient</Button>}
            />
          ) : (
            <DataTable
              data={ingredients}
              columns={ingCols}
              searchPlaceholder="Search ingredients…"
            />
          )}
        </TabsContent>

        {/* ── Stock tab ── */}
        <TabsContent value="stock">
          <div className="flex items-center gap-3 mb-4 flex-wrap">
            {branches.length > 1 && (
              <Select value={selBranch} onValueChange={setSelBranch}>
                <SelectTrigger className="w-48 h-9">
                  <SelectValue placeholder="Select branch…" />
                </SelectTrigger>
                <SelectContent>
                  {branches.map((b) => (
                    <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
            <Button
              size="sm"
              onClick={() => setAddDialog(true)}
              disabled={untrackedIngredients.length === 0}
            >
              <Plus size={13} /> Add Ingredient to Branch
            </Button>
          </div>

          {lowStock.length > 0 && (
            <div className="mb-4 flex items-center gap-3 bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800 rounded-xl px-4 py-3">
              <AlertTriangle size={16} className="text-amber-500 flex-shrink-0" />
              <p className="text-sm font-medium text-amber-800 dark:text-amber-200">
                {lowStock.length} item{lowStock.length > 1 ? "s" : ""} below reorder threshold:{" "}
                <span className="font-bold">{lowStock.map((i) => i.ingredient_name).join(", ")}</span>
              </p>
            </div>
          )}

          {invLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-12 rounded-xl" />
              ))}
            </div>
          ) : branchInv.length === 0 ? (
            <EmptyState
              icon={Package}
              title="No ingredients tracked at this branch"
              sub="Add ingredients from the org catalog to start tracking stock"
            />
          ) : (
            <DataTable
              data={branchInv}
              columns={invCols}
              searchPlaceholder="Search stock…"
            />
          )}
        </TabsContent>

        {/* ── History tab ── */}
        <TabsContent value="adjustments">
          <div className="flex items-center gap-3 mb-4">
            {branches.length > 1 && (
              <Select value={selBranch} onValueChange={setSelBranch}>
                <SelectTrigger className="w-48 h-9">
                  <SelectValue placeholder="Select branch…" />
                </SelectTrigger>
                <SelectContent>
                  {branches.map((b) => (
                    <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          </div>
          {adjustments.length === 0 ? (
            <EmptyState icon={Package} title="No adjustment history" />
          ) : (
            <DataTable
              data={adjustments}
              columns={adjCols}
              searchPlaceholder="Search history…"
            />
          )}
        </TabsContent>
      </Tabs>

      {/* Add ingredient to catalog */}
      <Dialog open={ingDialog} onOpenChange={setIngDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editIng ? "Edit Ingredient" : "New Ingredient"}</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Name</Label>
              <Input
                value={ingForm.name}
                onChange={(e) => setIngForm((f) => ({ ...f, name: e.target.value }))}
                placeholder="e.g. Whole Milk"
              />
            </div>
            <div className="space-y-1.5">
              <Label>Unit</Label>
              <Select value={ingForm.unit} onValueChange={(v) => setIngForm((f) => ({ ...f, unit: v }))}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {Object.entries(UNIT_LABELS).map(([k, v]) => (
                    <SelectItem key={k} value={k}>{v}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIngDialog(false)}>Cancel</Button>
            <Button loading={ingMutation.isPending} onClick={() => ingMutation.mutate()} disabled={!ingForm.name}>
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Add ingredient to branch */}
      <Dialog open={addDialog} onOpenChange={setAddDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add Ingredient to Branch</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Ingredient</Label>
              <Select
                value={addForm.org_ingredient_id}
                onValueChange={(v) => setAddForm((f) => ({ ...f, org_ingredient_id: v }))}
              >
                <SelectTrigger><SelectValue placeholder="Select ingredient…" /></SelectTrigger>
                <SelectContent>
                  {untrackedIngredients.map((i) => (
                    <SelectItem key={i.id} value={i.id}>
                      {i.name} ({i.unit})
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label>Opening Stock</Label>
                <Input
                  type="number" step="0.01"
                  value={addForm.current_stock}
                  onChange={(e) => setAddForm((f) => ({ ...f, current_stock: e.target.value }))}
                />
              </div>
              <div className="space-y-1.5">
                <Label>Reorder At</Label>
                <Input
                  type="number" step="0.01"
                  value={addForm.reorder_threshold}
                  onChange={(e) => setAddForm((f) => ({ ...f, reorder_threshold: e.target.value }))}
                />
              </div>
            </div>
            <div className="space-y-1.5">
              <Label>Cost per Unit (EGP)</Label>
              <Input
                type="number" step="0.01"
                value={addForm.cost_per_unit}
                onChange={(e) => setAddForm((f) => ({ ...f, cost_per_unit: e.target.value }))}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAddDialog(false)}>Cancel</Button>
            <Button
              loading={addMutation.isPending}
              onClick={() => addMutation.mutate()}
              disabled={!addForm.org_ingredient_id}
            >
              Add
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Adjust stock */}
      <Dialog open={adjDialog} onOpenChange={setAdjDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Adjust Stock - {adjItem?.ingredient_name}</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Type</Label>
              <Select
                value={adjForm.adjustment_type}
                onValueChange={(v: "add" | "remove") => setAdjForm((f) => ({ ...f, adjustment_type: v }))}
              >
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="add">Add</SelectItem>
                  <SelectItem value="remove">Remove</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Quantity ({adjItem?.unit})</Label>
              <Input
                type="number" step="0.01"
                value={adjForm.quantity}
                onChange={(e) => setAdjForm((f) => ({ ...f, quantity: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Note (required)</Label>
              <Input
                value={adjForm.note}
                onChange={(e) => setAdjForm((f) => ({ ...f, note: e.target.value }))}
                placeholder="Reason for adjustment"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAdjDialog(false)}>Cancel</Button>
            <Button
              loading={adjMutation.isPending}
              onClick={() => adjMutation.mutate()}
              disabled={!adjForm.quantity || !adjForm.note}
            >
              Adjust
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Transfer */}
      <Dialog open={transDialog} onOpenChange={setTransDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Transfer - {transItem?.ingredient_name}</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Destination Branch</Label>
              <Select
                value={transForm.destination_branch_id}
                onValueChange={(v) => setTransForm((f) => ({ ...f, destination_branch_id: v }))}
              >
                <SelectTrigger><SelectValue placeholder="Select destination…" /></SelectTrigger>
                <SelectContent>
                  {branches.filter((b) => b.id !== selBranch).map((b) => (
                    <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Quantity ({transItem?.unit})</Label>
              <Input
                type="number" step="0.01"
                value={transForm.quantity}
                onChange={(e) => setTransForm((f) => ({ ...f, quantity: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <Label>Note (optional)</Label>
              <Input
                value={transForm.note}
                onChange={(e) => setTransForm((f) => ({ ...f, note: e.target.value }))}
                placeholder="Transfer reason"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setTransDialog(false)}>Cancel</Button>
            <Button
              loading={transMutation.isPending}
              onClick={() => transMutation.mutate()}
              disabled={!transForm.destination_branch_id || !transForm.quantity}
            >
              Transfer
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
EOF

echo "=== Frontend patch complete ==="
echo "Run 'npm install' if needed, then 'npm run build'"