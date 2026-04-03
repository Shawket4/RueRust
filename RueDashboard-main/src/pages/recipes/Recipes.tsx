import React, { useState, useMemo } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Plus, Trash2, BookOpen, Coffee, Package, Search, ChevronsUpDown, Check } from "lucide-react";
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
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList,
} from "@/components/ui/command";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";
import type { OrgIngredient } from "@/types";

// ── Searchable ingredient combobox ────────────────────────────────────────────
function IngredientPicker({
  items,
  value,
  onSelect,
  placeholder = "Select ingredient…",
}: {
  items: OrgIngredient[];
  value: string;
  onSelect: (ing: OrgIngredient) => void;
  placeholder?: string;
}) {
  const [open, setOpen] = useState(false);
  const selected = items.find((i) => i.name === value);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className="w-full justify-between h-8 text-xs font-normal"
        >
          <span className="truncate">
            {selected ? `${selected.name} (${fmtUnit(selected.unit)})` : placeholder}
          </span>
          <ChevronsUpDown size={12} className="ml-2 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-[280px] p-0" align="start">
        <Command>
          <CommandInput placeholder="Search ingredients…" className="h-8 text-xs" />
          <CommandList>
            <CommandEmpty className="py-4 text-xs text-center text-muted-foreground">
              No ingredients found
            </CommandEmpty>
            <CommandGroup>
              {items.map((ing) => (
                <CommandItem
                  key={ing.id}
                  value={ing.name}
                  onSelect={() => { onSelect(ing); setOpen(false); }}
                  className="text-xs"
                >
                  <Check
                    size={12}
                    className={`mr-2 ${ing.name === value ? "opacity-100" : "opacity-0"}`}
                  />
                  {ing.name}
                  <span className="ml-auto text-muted-foreground">{fmtUnit(ing.unit)}</span>
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}

// Optional "Replaces" picker — null-able, has a clear option
function ReplacePicker({
  items,
  value,
  onChange,
}: {
  items: OrgIngredient[];
  value: string | null;
  onChange: (id: string | null, name: string | null) => void;
}) {
  const [open, setOpen] = useState(false);
  const selected = items.find((i) => i.id === value);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className="w-full justify-between h-8 text-xs font-normal"
        >
          <span className="truncate text-muted-foreground">
            {selected ? selected.name : "None (additive)"}
          </span>
          <ChevronsUpDown size={12} className="ml-2 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-[280px] p-0" align="start">
        <Command>
          <CommandInput placeholder="Search ingredient to replace…" className="h-8 text-xs" />
          <CommandList>
            <CommandEmpty className="py-4 text-xs text-center text-muted-foreground">No match</CommandEmpty>
            <CommandGroup>
              <CommandItem
                value="__none__"
                onSelect={() => { onChange(null, null); setOpen(false); }}
                className="text-xs text-muted-foreground"
              >
                <Check size={12} className={`mr-2 ${!value ? "opacity-100" : "opacity-0"}`} />
                None (additive)
              </CommandItem>
              {items.map((ing) => (
                <CommandItem
                  key={ing.id}
                  value={ing.name}
                  onSelect={() => { onChange(ing.id, ing.name); setOpen(false); }}
                  className="text-xs"
                >
                  <Check size={12} className={`mr-2 ${ing.id === value ? "opacity-100" : "opacity-0"}`} />
                  {ing.name}
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}

// ── Recipe row ────────────────────────────────────────────────────────────────
function RecipeRow({ recipe, onDelete }: { recipe: DrinkRecipe; onDelete: () => void }) {
  return (
    <div className="flex items-center gap-3 py-2 px-3 rounded-lg hover:bg-muted/50 group">
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium">{recipe.ingredient_name}</p>
        <p className="text-xs text-muted-foreground">
          {recipe.quantity_used} {fmtUnit(recipe.unit)} · {SIZE_LABELS[recipe.size_label] ?? recipe.size_label}
        </p>
      </div>
      <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100 text-destructive" onClick={onDelete}>
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
    queryFn:  () => recipesApi.getDrinkRecipes(item.id).then((r) => r.data),
  });

  const { data: invItems = [] } = useQuery({
    queryKey: ["org-catalog", orgId],
    queryFn:  () => inventoryApi.getCatalog(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const [form, setForm] = useState({
    size_label:      "medium",
    ingredient_name: "",
    ingredient_unit: "",
    quantity_used:   "",
  });

  const addMutation = useMutation({
    mutationFn: () => recipesApi.upsertDrinkRecipe(item.id, {
      size_label:      form.size_label,
      ingredient_name: form.ingredient_name,
      ingredient_unit: form.ingredient_unit,
      quantity_used:   parseFloat(form.quantity_used),
    }),
    onSuccess: () => {
      toast.success("Recipe saved");
      qc.invalidateQueries({ queryKey: ["drink-recipes", item.id] });
      setForm((f) => ({ ...f, ingredient_name: "", ingredient_unit: "", quantity_used: "" }));
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const delMutation = useMutation({
    mutationFn: ({ size, ingredientName }: { size: string; ingredientName: string }) =>
      recipesApi.deleteDrinkRecipe(item.id, size, ingredientName),
    onSuccess: () => { toast.success("Removed"); qc.invalidateQueries({ queryKey: ["drink-recipes", item.id] }); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const uniqueInvItems = useMemo(
    () => Array.from(new Map(invItems.map((i) => [i.name, i])).values()),
    [invItems],
  );

  return (
    <div className="p-4 space-y-4">
      <div className="space-y-1">
        {isLoading ? <Skeleton className="h-20" />
          : recipes.length === 0
            ? <p className="text-sm text-muted-foreground py-4 text-center">No ingredients yet</p>
            : recipes.map((r) => (
                <RecipeRow
                  key={`${r.size_label}-${r.ingredient_name}`}
                  recipe={r}
                  onDelete={() => delMutation.mutate({ size: r.size_label, ingredientName: r.ingredient_name })}
                />
              ))
        }
      </div>
      <Separator />
      <div className="grid grid-cols-2 gap-2">
        <div className="space-y-1">
          <Label className="text-xs">Size</Label>
          <Select value={form.size_label} onValueChange={(v) => setForm((f) => ({ ...f, size_label: v }))}>
            <SelectTrigger className="h-8 text-xs"><SelectValue /></SelectTrigger>
            <SelectContent>
              {Object.entries(SIZE_LABELS).map(([k, v]) => <SelectItem key={k} value={k}>{v}</SelectItem>)}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1">
          <Label className="text-xs">Qty</Label>
          <Input
            className="h-8 text-xs" type="number" step="0.1" placeholder="e.g. 200"
            value={form.quantity_used}
            onChange={(e) => setForm((f) => ({ ...f, quantity_used: e.target.value }))}
          />
        </div>
        <div className="col-span-2 space-y-1">
          <Label className="text-xs">Ingredient</Label>
          <IngredientPicker
            items={uniqueInvItems}
            value={form.ingredient_name}
            onSelect={(ing) => setForm((f) => ({ ...f, ingredient_name: ing.name, ingredient_unit: ing.unit }))}
          />
        </div>
        <div className="col-span-2">
          <Button size="sm" className="w-full" loading={addMutation.isPending}
            disabled={!form.ingredient_name || !form.quantity_used}
            onClick={() => addMutation.mutate()}>
            <Plus size={13} /> Add Ingredient
          </Button>
        </div>
      </div>
    </div>
  );
}

// ── Addon recipe panel ────────────────────────────────────────────────────────
function AddonRecipePanel({ addon, orgId }: { addon: AddonItem; orgId: string }) {
  const qc = useQueryClient();

  const { data: ingredients = [], isLoading } = useQuery({
    queryKey: ["addon-ingredients", addon.id],
    queryFn:  () => recipesApi.getAddonIngredients(addon.id).then((r) => r.data),
  });

  const { data: invItems = [] } = useQuery({
    queryKey: ["org-catalog", orgId],
    queryFn:  () => inventoryApi.getCatalog(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const [form, setForm] = useState({
    ingredient_name:            "",
    ingredient_unit:            "",
    quantity_used:              "",
    replaces_org_ingredient_id: null as string | null,
  });

  const uniqueInvItems = useMemo(
    () => Array.from(new Map(invItems.map((i) => [i.name, i])).values()),
    [invItems],
  );

  const addMutation = useMutation({
    mutationFn: () => recipesApi.upsertAddonIngredient(addon.id, {
      ingredient_name:            form.ingredient_name,
      ingredient_unit:            form.ingredient_unit,
      quantity_used:              parseFloat(form.quantity_used),
      replaces_org_ingredient_id: form.replaces_org_ingredient_id ?? undefined,
    }),
    onSuccess: () => {
      toast.success("Saved");
      qc.invalidateQueries({ queryKey: ["addon-ingredients", addon.id] });
      setForm((f) => ({ ...f, ingredient_name: "", ingredient_unit: "", quantity_used: "", replaces_org_ingredient_id: null }));
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const delMutation = useMutation({
    mutationFn: (ingredientName: string) => recipesApi.deleteAddonIngredient(addon.id, ingredientName),
    onSuccess: () => { toast.success("Removed"); qc.invalidateQueries({ queryKey: ["addon-ingredients", addon.id] }); },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // Find the human-readable name for the replaces_id of a row
  const replacesName = (ing: AddonIngredient) => {
    if (!ing.replaces_org_ingredient_id) return null;
    return invItems.find((i) => i.id === ing.replaces_org_ingredient_id)?.name ?? "Unknown";
  };

  return (
    <div className="p-4 space-y-4">
      <div className="space-y-1">
        {isLoading ? <Skeleton className="h-16" />
          : ingredients.length === 0
            ? <p className="text-sm text-muted-foreground py-4 text-center">No ingredients</p>
            : ingredients.map((r) => (
                <div key={r.ingredient_name} className="flex items-center gap-3 py-2 px-3 rounded-lg hover:bg-muted/50 group">
                  <div className="flex-1">
                    <p className="text-sm font-medium">{r.ingredient_name}</p>
                    <p className="text-xs text-muted-foreground">
                      {r.quantity_used} {fmtUnit(r.unit)}
                      {replacesName(r) && (
                        <span className="ml-2 text-amber-600 dark:text-amber-400">
                          · replaces {replacesName(r)}
                        </span>
                      )}
                    </p>
                  </div>
                  <Button variant="ghost" size="icon-sm" className="opacity-0 group-hover:opacity-100 text-destructive" onClick={() => delMutation.mutate(r.ingredient_name)}>
                    <Trash2 size={13} />
                  </Button>
                </div>
              ))
        }
      </div>
      <Separator />
      <div className="space-y-2">
        <div className="space-y-1">
          <Label className="text-xs">Ingredient</Label>
          <IngredientPicker
            items={uniqueInvItems}
            value={form.ingredient_name}
            onSelect={(ing) => setForm((f) => ({ ...f, ingredient_name: ing.name, ingredient_unit: ing.unit }))}
          />
        </div>
        <div className="space-y-1">
          <Label className="text-xs">
            {form.replaces_org_ingredient_id ? "Quantity (Fallback / Splash amount)" : "Quantity"}
          </Label>
          <Input
            className="h-8 text-xs" type="number" step="0.1" placeholder="e.g. 200"
            value={form.quantity_used}
            onChange={(e) => setForm((f) => ({ ...f, quantity_used: e.target.value }))}
          />
        </div>
        <div className="space-y-1">
          <Label className="text-xs">
            Replaces base ingredient{" "}
            <span className="text-muted-foreground font-normal">(milk-type substitution)</span>
          </Label>
          <ReplacePicker
            items={uniqueInvItems}
            value={form.replaces_org_ingredient_id}
            onChange={(id) => setForm((f) => ({ ...f, replaces_org_ingredient_id: id }))}
          />
        </div>
        <Button size="sm" className="w-full" loading={addMutation.isPending}
          disabled={!form.ingredient_name || !form.quantity_used}
          onClick={() => addMutation.mutate()}>
          <Plus size={13} /> Add
        </Button>
      </div>
    </div>
  );
}

// ── Main page ─────────────────────────────────────────────────────────────────
export default function Recipes() {
  const user  = useAuthStore((s) => s.user);
  const orgId = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const [tab, setTab]         = useState("drinks");
  const [selItem, setSelItem] = useState<MenuItem | null>(null);
  const [selAddon, setSelAddon] = useState<AddonItem | null>(null);
  const [drinkSearch, setDrinkSearch] = useState("");
  const [addonSearch, setAddonSearch] = useState("");

  const { data: items = [], isLoading: itemsLoading } = useQuery({
    queryKey: ["menu-items", orgId],
    queryFn:  () => menuApi.getMenuItems(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const { data: addons = [], isLoading: addonsLoading } = useQuery({
    queryKey: ["addon-items", orgId],
    queryFn:  () => menuApi.getAddonItems(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const filteredItems  = useMemo(
    () => items.filter((i) => i.name.toLowerCase().includes(drinkSearch.toLowerCase())),
    [items, drinkSearch],
  );
  const filteredAddons = useMemo(
    () => addons.filter((a) => a.name.toLowerCase().includes(addonSearch.toLowerCase())),
    [addons, addonSearch],
  );

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader title="Recipes" sub="Configure ingredient deductions per drink and addon" />

      <Tabs value={tab} onValueChange={(v) => { setTab(v); setSelItem(null); setSelAddon(null); }}>
        <TabsList className="mb-6">
          <TabsTrigger value="drinks"><Coffee size={14} /> Drinks ({items.length})</TabsTrigger>
          <TabsTrigger value="addons"><Package size={14} /> Addons ({addons.length})</TabsTrigger>
        </TabsList>

        {/* ── Drinks ── */}
        <TabsContent value="drinks">
          <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-4">
            <div className="rounded-2xl border overflow-hidden">
              <div className="p-3 border-b bg-muted/30 space-y-2">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Menu Items</p>
                <div className="relative">
                  <Search size={12} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
                  <Input
                    value={drinkSearch}
                    onChange={(e) => setDrinkSearch(e.target.value)}
                    placeholder="Search drinks…"
                    className="h-7 pl-7 text-xs"
                  />
                </div>
              </div>
              <ScrollArea className="h-[500px]">
                {itemsLoading
                  ? <div className="p-3 space-y-2">{Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-10" />)}</div>
                  : filteredItems.length === 0
                    ? <EmptyState icon={Coffee} title="No items" className="h-40" />
                    : filteredItems.map((item) => (
                        <button
                          key={item.id}
                          onClick={() => setSelItem(item)}
                          className={`w-full text-left px-4 py-3 border-b border-border/50 hover:bg-muted/40 transition-colors ${selItem?.id === item.id ? "bg-accent" : ""}`}
                        >
                          <p className="text-sm font-medium">{item.name}</p>
                          <p className="text-xs text-muted-foreground">{egp(item.base_price)}</p>
                        </button>
                      ))
                }
              </ScrollArea>
            </div>

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
                  <DrinkRecipePanel item={selItem} orgId={orgId} />
                </>
              ) : (
                <EmptyState icon={BookOpen} title="Select a drink" sub="Choose a menu item to configure its recipe" className="h-[500px]" />
              )}
            </div>
          </div>
        </TabsContent>

        {/* ── Addons ── */}
        <TabsContent value="addons">
          <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-4">
            <div className="rounded-2xl border overflow-hidden">
              <div className="p-3 border-b bg-muted/30 space-y-2">
                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Addon Items</p>
                <div className="relative">
                  <Search size={12} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground" />
                  <Input
                    value={addonSearch}
                    onChange={(e) => setAddonSearch(e.target.value)}
                    placeholder="Search addons…"
                    className="h-7 pl-7 text-xs"
                  />
                </div>
              </div>
              <ScrollArea className="h-[500px]">
                {addonsLoading
                  ? <div className="p-3 space-y-2">{Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-10" />)}</div>
                  : filteredAddons.length === 0
                    ? <EmptyState icon={Package} title="No addons" className="h-40" />
                    : filteredAddons.map((addon) => (
                        <button
                          key={addon.id}
                          onClick={() => setSelAddon(addon)}
                          className={`w-full text-left px-4 py-3 border-b border-border/50 hover:bg-muted/40 transition-colors ${selAddon?.id === addon.id ? "bg-accent" : ""}`}
                        >
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
                  <AddonRecipePanel addon={selAddon} orgId={orgId} />
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
