import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Plus, Trash2, BookOpen, Coffee, Package } from "lucide-react";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as menuApi from "@/api/menu";
import * as recipesApi from "@/api/recipes";
import * as inventoryApi from "@/api/inventory";
import type {
  MenuItem,
  DrinkRecipe,
  AddonItem,
  AddonIngredient,
} from "@/types";
import { egp, fmtUnit, SIZE_LABELS } from "@/utils/format";
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";

// ── Recipe row (drink) ────────────────────────────────────────────────────────
function RecipeRow({
  recipe,
  onDelete,
}: {
  recipe: DrinkRecipe;
  onDelete: () => void;
}) {
  return (
    <div className="flex items-center gap-3 py-2 px-3 rounded-lg hover:bg-muted/50 group">
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium">{recipe.ingredient_name}</p>
        <p className="text-xs text-muted-foreground">
          {recipe.quantity_used} {fmtUnit(recipe.unit)} ·{" "}
          {SIZE_LABELS[recipe.size_label] ?? recipe.size_label}
        </p>
      </div>
      <Button
        variant="ghost"
        size="icon-sm"
        className="opacity-0 group-hover:opacity-100 text-destructive"
        onClick={onDelete}
      >
        <Trash2 size={13} />
      </Button>
    </div>
  );
}

// ── Drink recipe panel ────────────────────────────────────────────────────────
function DrinkRecipePanel({ item, orgId }: { item: MenuItem; orgId: string }) {
  const qc = useQueryClient();

  const { data: recipes = [], isLoading } = useQuery({
    queryKey: ["drink-recipes", item.id],
    queryFn: () => recipesApi.getDrinkRecipes(item.id).then((r) => r.data),
  });

  // Org-level catalog — used as a convenience picker so the user
  // doesn't have to type ingredient names manually.
  const { data: invItems = [] } = useQuery({
    queryKey: ["org-catalog", orgId],
    queryFn: () =>
      inventoryApi.getCatalog(orgId).then((r) => r.data),
    enabled: !!orgId,
  });

  const [form, setForm] = useState({
    size_label: "medium",
    ingredient_name: "",
    ingredient_unit: "",
    quantity_used: "",
  });

  const addMutation = useMutation({
    mutationFn: () =>
      recipesApi.upsertDrinkRecipe(item.id, {
        size_label: form.size_label,
        ingredient_name: form.ingredient_name,
        ingredient_unit: form.ingredient_unit,
        quantity_used: parseFloat(form.quantity_used),
      }),
    onSuccess: () => {
      toast.success("Recipe saved");
      qc.invalidateQueries({ queryKey: ["drink-recipes", item.id] });
      setForm((f) => ({
        ...f,
        ingredient_name: "",
        ingredient_unit: "",
        quantity_used: "",
      }));
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const delMutation = useMutation({
    mutationFn: ({
      size,
      ingredientName,
    }: {
      size: string;
      ingredientName: string;
    }) => recipesApi.deleteDrinkRecipe(item.id, size, ingredientName),
    onSuccess: () => {
      toast.success("Removed");
      qc.invalidateQueries({ queryKey: ["drink-recipes", item.id] });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const sizes = Object.entries(SIZE_LABELS);

  // Deduplicate by name — org-level list has one row per branch for the same
  // ingredient. We only need unique names for the picker.
  const uniqueInvItems = Array.from(
    new Map(invItems.map((i) => [i.name, i])).values(),
  );

  return (
    <div className="p-4 space-y-4">
      <div className="space-y-1">
        {isLoading ? (
          <Skeleton className="h-20" />
        ) : recipes.length === 0 ? (
          <p className="text-sm text-muted-foreground py-4 text-center">
            No ingredients yet
          </p>
        ) : (
          recipes.map((r) => (
            <RecipeRow
              key={`${r.size_label}-${r.ingredient_name}`}
              recipe={r}
              onDelete={() =>
                delMutation.mutate({
                  size: r.size_label,
                  ingredientName: r.ingredient_name,
                })
              }
            />
          ))
        )}
      </div>
      <Separator />
      <div className="grid grid-cols-2 gap-2">
        <div className="space-y-1">
          <Label>Size</Label>
          <Select
            value={form.size_label}
            onValueChange={(v) => setForm((f) => ({ ...f, size_label: v }))}
          >
            <SelectTrigger className="h-8 text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {sizes.map(([k, v]) => (
                <SelectItem key={k} value={k}>
                  {v}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1">
          <Label>Qty</Label>
          <Input
            className="h-8 text-xs"
            type="number"
            step="0.1"
            placeholder="e.g. 200"
            value={form.quantity_used}
            onChange={(e) =>
              setForm((f) => ({ ...f, quantity_used: e.target.value }))
            }
          />
        </div>
        <div className="col-span-2 space-y-1">
          <Label>Ingredient</Label>
          <Select
            value={form.ingredient_name}
            onValueChange={(name) => {
              const inv = uniqueInvItems.find((i) => i.name === name);
              setForm((f) => ({
                ...f,
                ingredient_name: name,
                ingredient_unit: inv?.unit ?? "",
              }));
            }}
          >
            <SelectTrigger className="h-8 text-xs">
              <SelectValue placeholder="Select ingredient…" />
            </SelectTrigger>
            <SelectContent>
              {uniqueInvItems.map((i) => (
                <SelectItem key={i.name} value={i.name}>
                  {i.name} ({fmtUnit(i.unit)})
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="col-span-2">
          <Button
            size="sm"
            className="w-full"
            loading={addMutation.isPending}
            disabled={!form.ingredient_name || !form.quantity_used}
            onClick={() => addMutation.mutate()}
          >
            <Plus size={13} /> Add Ingredient
          </Button>
        </div>
      </div>
    </div>
  );
}

// ── Addon recipe panel ────────────────────────────────────────────────────────
function AddonRecipePanel({
  addon,
  orgId,
}: {
  addon: AddonItem;
  orgId: string;
}) {
  const qc = useQueryClient();

  const { data: ingredients = [], isLoading } = useQuery({
    queryKey: ["addon-ingredients", addon.id],
    queryFn: () => recipesApi.getAddonIngredients(addon.id).then((r) => r.data),
  });

  const { data: invItems = [] } = useQuery({
    queryKey: ["org-catalog", orgId],
    queryFn: () =>
      inventoryApi.getCatalog(orgId).then((r) => r.data),
    enabled: !!orgId,
  });

  const [form, setForm] = useState({
    ingredient_name: "",
    ingredient_unit: "",
    quantity_used: "",
  });

  const addMutation = useMutation({
    mutationFn: () =>
      recipesApi.upsertAddonIngredient(addon.id, {
        ingredient_name: form.ingredient_name,
        ingredient_unit: form.ingredient_unit,
        quantity_used: parseFloat(form.quantity_used),
      }),
    onSuccess: () => {
      toast.success("Saved");
      qc.invalidateQueries({ queryKey: ["addon-ingredients", addon.id] });
      setForm((f) => ({
        ...f,
        ingredient_name: "",
        ingredient_unit: "",
        quantity_used: "",
      }));
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const delMutation = useMutation({
    mutationFn: (ingredientName: string) =>
      recipesApi.deleteAddonIngredient(addon.id, ingredientName),
    onSuccess: () => {
      toast.success("Removed");
      qc.invalidateQueries({ queryKey: ["addon-ingredients", addon.id] });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const uniqueInvItems = Array.from(
    new Map(invItems.map((i) => [i.name, i])).values(),
  );

  return (
    <div className="p-4 space-y-4">
      <div className="space-y-1">
        {isLoading ? (
          <Skeleton className="h-16" />
        ) : ingredients.length === 0 ? (
          <p className="text-sm text-muted-foreground py-4 text-center">
            No ingredients
          </p>
        ) : (
          ingredients.map((r) => (
            <div
              key={r.ingredient_name}
              className="flex items-center gap-3 py-2 px-3 rounded-lg hover:bg-muted/50 group"
            >
              <div className="flex-1">
                <p className="text-sm font-medium">{r.ingredient_name}</p>
                <p className="text-xs text-muted-foreground">
                  {r.quantity_used} {fmtUnit(r.unit)}
                </p>
              </div>
              <Button
                variant="ghost"
                size="icon-sm"
                className="opacity-0 group-hover:opacity-100 text-destructive"
                onClick={() => delMutation.mutate(r.ingredient_name)}
              >
                <Trash2 size={13} />
              </Button>
            </div>
          ))
        )}
      </div>
      <Separator />
      <div className="space-y-2">
        <div className="space-y-1">
          <Label>Ingredient</Label>
          <Select
            value={form.ingredient_name}
            onValueChange={(name) => {
              const inv = uniqueInvItems.find((i) => i.name === name);
              setForm((f) => ({
                ...f,
                ingredient_name: name,
                ingredient_unit: inv?.unit ?? "",
              }));
            }}
          >
            <SelectTrigger className="h-8 text-xs">
              <SelectValue placeholder="Select…" />
            </SelectTrigger>
            <SelectContent>
              {uniqueInvItems.map((i) => (
                <SelectItem key={i.name} value={i.name}>
                  {i.name} ({fmtUnit(i.unit)})
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1">
          <Label>Quantity</Label>
          <Input
            className="h-8 text-xs"
            type="number"
            step="0.1"
            placeholder="e.g. 30"
            value={form.quantity_used}
            onChange={(e) =>
              setForm((f) => ({ ...f, quantity_used: e.target.value }))
            }
          />
        </div>
        <Button
          size="sm"
          className="w-full"
          loading={addMutation.isPending}
          disabled={!form.ingredient_name || !form.quantity_used}
          onClick={() => addMutation.mutate()}
        >
          <Plus size={13} /> Add
        </Button>
      </div>
    </div>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────
export default function Recipes() {
  const user = useAuthStore((s) => s.user);
  const orgId = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const [tab, setTab] = useState("drinks");
  const [selItem, setSelItem] = useState<MenuItem | null>(null);
  const [selAddon, setSelAddon] = useState<AddonItem | null>(null);

  const { data: items = [], isLoading: itemsLoading } = useQuery({
    queryKey: ["menu-items", orgId],
    queryFn: () => menuApi.getMenuItems(orgId).then((r) => r.data),
    enabled: !!orgId,
  });

  const { data: addons = [], isLoading: addonsLoading } = useQuery({
    queryKey: ["addon-items", orgId],
    queryFn: () => menuApi.getAddonItems(orgId).then((r) => r.data),
    enabled: !!orgId,
  });

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader
        title="Recipes"
        sub="Configure ingredient deductions per drink and addon"
      />

      <Tabs
        value={tab}
        onValueChange={(v) => {
          setTab(v);
          setSelItem(null);
          setSelAddon(null);
        }}
      >
        <TabsList className="mb-6">
          <TabsTrigger value="drinks">
            <Coffee size={14} /> Drinks ({items.length})
          </TabsTrigger>
          <TabsTrigger value="addons">
            <Package size={14} /> Addons ({addons.length})
          </TabsTrigger>
        </TabsList>

        {/* ── Drinks tab ── */}
        <TabsContent value="drinks">
          <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-4">
            <div className="rounded-2xl border overflow-hidden">
              <div className="p-3 border-b bg-muted/30">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  Menu Items
                </p>
              </div>
              <ScrollArea className="h-[500px]">
                {itemsLoading ? (
                  <div className="p-3 space-y-2">
                    {Array.from({ length: 6 }).map((_, i) => (
                      <Skeleton key={i} className="h-10" />
                    ))}
                  </div>
                ) : items.length === 0 ? (
                  <EmptyState icon={Coffee} title="No items" className="h-40" />
                ) : (
                  items.map((item) => (
                    <button
                      key={item.id}
                      onClick={() => setSelItem(item)}
                      className={`w-full text-left px-4 py-3 border-b border-border/50 hover:bg-muted/40 transition-colors ${
                        selItem?.id === item.id ? "bg-accent" : ""
                      }`}
                    >
                      <p className="text-sm font-medium">{item.name}</p>
                      <p className="text-xs text-muted-foreground">
                        {egp(item.base_price)}
                      </p>
                    </button>
                  ))
                )}
              </ScrollArea>
            </div>

            <div className="rounded-2xl border overflow-hidden">
              {selItem ? (
                <>
                  <div className="p-4 border-b bg-muted/30 flex items-center justify-between">
                    <div>
                      <p className="font-semibold">{selItem.name}</p>
                      <p className="text-xs text-muted-foreground">
                        Ingredient deductions per size
                      </p>
                    </div>
                    <Badge variant="info">{egp(selItem.base_price)}</Badge>
                  </div>
                  <DrinkRecipePanel item={selItem} orgId={orgId} />
                </>
              ) : (
                <EmptyState
                  icon={BookOpen}
                  title="Select a drink"
                  sub="Choose a menu item to configure its recipe"
                  className="h-[500px]"
                />
              )}
            </div>
          </div>
        </TabsContent>

        {/* ── Addons tab ── */}
        <TabsContent value="addons">
          <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-4">
            <div className="rounded-2xl border overflow-hidden">
              <div className="p-3 border-b bg-muted/30">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  Addon Items
                </p>
              </div>
              <ScrollArea className="h-[500px]">
                {addonsLoading ? (
                  <div className="p-3 space-y-2">
                    {Array.from({ length: 6 }).map((_, i) => (
                      <Skeleton key={i} className="h-10" />
                    ))}
                  </div>
                ) : addons.length === 0 ? (
                  <EmptyState
                    icon={Package}
                    title="No addons"
                    className="h-40"
                  />
                ) : (
                  addons.map((addon) => (
                    <button
                      key={addon.id}
                      onClick={() => setSelAddon(addon)}
                      className={`w-full text-left px-4 py-3 border-b border-border/50 hover:bg-muted/40 transition-colors ${
                        selAddon?.id === addon.id ? "bg-accent" : ""
                      }`}
                    >
                      <p className="text-sm font-medium">{addon.name}</p>
                      <p className="text-xs text-muted-foreground">
                        {egp(addon.default_price)}
                      </p>
                    </button>
                  ))
                )}
              </ScrollArea>
            </div>

            <div className="rounded-2xl border overflow-hidden">
              {selAddon ? (
                <>
                  <div className="p-4 border-b bg-muted/30">
                    <p className="font-semibold">{selAddon.name}</p>
                    <p className="text-xs text-muted-foreground">
                      Ingredient deductions
                    </p>
                  </div>
                  <AddonRecipePanel addon={selAddon} orgId={orgId} />
                </>
              ) : (
                <EmptyState
                  icon={Package}
                  title="Select an addon"
                  sub="Choose an addon to configure its ingredients"
                  className="h-[500px]"
                />
              )}
            </div>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}
