import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  Plus,
  Pencil,
  Trash2,
  Coffee,
  Tag,
  Package,
  ToggleLeft,
  ToggleRight,
  Download,
} from "lucide-react";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { DataTable } from "@/components/shared/DataTable";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";

// ── XLSX Export ───────────────────────────────────────────────────────────────
async function exportMenuXLSX({
  orgId,
  branchName,
  items,
  cats,
  addons,
}: {
  orgId: string;
  branchName: string;
  items: MenuItem[];
  cats: Category[];
  addons: AddonItem[];
}) {
  try {
    toast.loading("Generating Excel file…");

    const ExcelJS = (await import("exceljs")).default;
    const wb = new ExcelJS.Workbook();
    wb.creator = "Rue POS";
    wb.created = new Date();

    // ── Palette ─────────────────────────────────────────────────────────────
    const C = {
      logoBlue: "FF0039BF",
      white: "FFFFFFFF",
      rowEven: "FFF9FAFB",
      border: "FFE5E7EB",
      textDark: "FF111827",
      textMuted: "FF6B7280",
      green: "FF16A34A",
      red: "FFDC2626",
      amber: "FFD97706",
      violet: "FF7C3AED",
      teal: "FF0D9488",
    };

    const border = (cell: any, color = C.border) => {
      const s = { style: "thin" as const, color: { argb: color } };
      cell.border = { top: s, bottom: s, left: s, right: s };
    };

    const catMap = Object.fromEntries(cats.map((c) => [c.id, c.name]));
    const now = new Date().toLocaleString("en-EG");

    // ── Helper: build standard banner rows (logo + subtitle + spacer) ────────
    async function addBanner(ws: any, lastCol: string, subtitle: string) {
      ws.mergeCells(`A1:${lastCol}1`);
      ws.getRow(1).height = 65;
      const titleCell = ws.getCell("A1");
      titleCell.value = subtitle;
      titleCell.font = {
        name: "Cairo",
        size: 16,
        bold: true,
        color: { argb: C.logoBlue },
      };
      titleCell.alignment = {
        horizontal: "right",
        vertical: "middle",
        indent: 2,
      };

      try {
        const res = await fetch("/TheRue.png");
        const buf = await res.arrayBuffer();
        const logoId = wb.addImage({ buffer: buf, extension: "png" });
        ws.addImage(logoId, {
          tl: { col: 0.2, row: 0.35 },
          ext: { width: 135, height: 57 },
        });
      } catch {
        /* logo optional */
      }

      ws.mergeCells(`A2:${lastCol}2`);
      const sub = ws.getCell("A2");
      sub.value = `Generated: ${now}`;
      sub.font = { name: "Cairo", size: 9, color: { argb: C.textMuted } };
      sub.alignment = { horizontal: "center", vertical: "middle" };
      ws.getRow(2).height = 20;

      ws.mergeCells(`A3:${lastCol}3`);
      ws.getRow(3).height = 8;
    }

    // ── Helper: stat pills (rows 4–5) ────────────────────────────────────────
    function addStats(
      ws: any,
      lastCol: string,
      stats: {
        label: string;
        value: number | string;
        color: string;
        fmt?: string;
      }[],
    ) {
      const cols = ["A", "C", "E", "G", "I", "K"];
      const ends = ["B", "D", "F", "H", "J", "L"];
      stats.forEach(({ label, value, color, fmt }, i) => {
        ws.mergeCells(`${cols[i]}4:${ends[i]}4`);
        const lc = ws.getCell(`${cols[i]}4`);
        lc.value = label;
        lc.font = { name: "Cairo", size: 8, color: { argb: C.textMuted } };
        lc.alignment = { horizontal: "center", vertical: "middle" };

        ws.mergeCells(`${cols[i]}5:${ends[i]}5`);
        const vc = ws.getCell(`${cols[i]}5`);
        vc.value = value;
        vc.font = {
          name: "Cairo",
          size: 12,
          bold: true,
          color: { argb: color },
        };
        vc.alignment = { horizontal: "center", vertical: "middle" };
        if (fmt) vc.numFmt = fmt;
      });

      ws.mergeCells(`A6:${lastCol}6`);
      ws.getRow(6).height = 8;
    }

    // ── Helper: header row (row 7) ───────────────────────────────────────────
    function addHeaderRow(ws: any, headers: string[]) {
      const headerRow = ws.addRow(headers);
      headerRow.height = 30;
      headerRow.eachCell((cell: any) => {
        cell.font = {
          name: "Cairo",
          size: 10,
          bold: true,
          color: { argb: C.white },
        };
        cell.fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: C.logoBlue },
        };
        cell.alignment = { horizontal: "center", vertical: "middle" };
        border(cell);
      });
      return headerRow;
    }

    // ── Helper: totals row ───────────────────────────────────────────────────
    function addTotalsRow(
      ws: any,
      values: (string | { formula: string } | null)[],
      numCols: number[],
    ) {
      const row = ws.addRow(values);
      row.height = 28;
      row.eachCell({ includeEmpty: true }, (cell: any, colNum: number) => {
        cell.fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: C.logoBlue },
        };
        cell.font = {
          name: "Cairo",
          size: 10,
          bold: true,
          color: { argb: C.white },
        };
        cell.alignment = { vertical: "middle", horizontal: "center" };
        border(cell);
        if (numCols.includes(colNum)) cell.numFmt = "#,##0.00";
      });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SHEET 1 — Menu Items
    // ─────────────────────────────────────────────────────────────────────────
    const wsItems = wb.addWorksheet("Menu Items", {
      pageSetup: { fitToPage: true, fitToWidth: 1, orientation: "landscape" },
      views: [{ state: "frozen", ySplit: 7 }],
    });

    wsItems.columns = [
      { key: "name", width: 28 },
      { key: "description", width: 36 },
      { key: "category", width: 20 },
      { key: "price", width: 16 },
      { key: "active", width: 12 },
    ];

    await addBanner(wsItems, "E", "Menu Items");

    const activeItems = items.filter((i) => i.is_active);
    const inactiveItems = items.filter((i) => !i.is_active);
    const avgPrice =
      items.length > 0
        ? items.reduce((s, i) => s + i.base_price, 0) / items.length / 100
        : 0;

    addStats(wsItems, "E", [
      { label: "Total Items", value: items.length, color: C.logoBlue },
      { label: "Active", value: activeItems.length, color: C.green },
      { label: "Inactive", value: inactiveItems.length, color: C.red },
      {
        label: "Avg Price",
        value: avgPrice,
        color: C.amber,
        fmt: '#,##0.00 "EGP"',
      },
    ]);

    addHeaderRow(wsItems, [
      "Name",
      "Description",
      "Category",
      "Price (EGP)",
      "Status",
    ]);

    const DATA_START_ITEMS = 8;
    items.forEach((item, idx) => {
      const rowBg = idx % 2 === 0 ? C.rowEven : C.white;
      const row = wsItems.addRow([
        item.name,
        item.description ?? "—",
        catMap[item.category_id ?? ""] ?? "Uncategorised",
        item.base_price / 100,
        item.is_active ? "Active" : "Inactive",
      ]);
      row.height = 24;
      row.eachCell({ includeEmpty: true }, (cell: any, colNum: number) => {
        cell.font = {
          name: "Cairo",
          size: 10,
          color: { argb: item.is_active ? C.textDark : C.textMuted },
          italic: !item.is_active,
        };
        cell.fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: rowBg },
        };
        cell.alignment = {
          vertical: "middle",
          horizontal: colNum === 4 ? "center" : "left",
          indent: colNum <= 3 ? 1 : 0,
        };
        border(cell);
        if (colNum === 4) cell.numFmt = "#,##0.00";
        if (colNum === 5) {
          cell.font = {
            name: "Cairo",
            size: 9,
            bold: true,
            color: { argb: item.is_active ? C.green : C.red },
          };
        }
      });
    });

    addTotalsRow(
      wsItems,
      [
        "",
        "TOTALS",
        "",
        { formula: `=SUM(D${DATA_START_ITEMS}:D${wsItems.rowCount})` },
        "",
      ],
      [4],
    );

    // ─────────────────────────────────────────────────────────────────────────
    // SHEET 2 — Categories
    // ─────────────────────────────────────────────────────────────────────────
    const wsCats = wb.addWorksheet("Categories", {
      pageSetup: { fitToPage: true, fitToWidth: 1 },
      views: [{ state: "frozen", ySplit: 7 }],
    });

    wsCats.columns = [
      { key: "name", width: 30 },
      { key: "display_order", width: 18 },
      { key: "active", width: 14 },
    ];

    await addBanner(wsCats, "C", "Categories");

    const activeCats = cats.filter((c) => c.is_active);

    addStats(wsCats, "C", [
      { label: "Total Categories", value: cats.length, color: C.logoBlue },
      { label: "Active", value: activeCats.length, color: C.green },
      {
        label: "Inactive",
        value: cats.length - activeCats.length,
        color: C.red,
      },
    ]);

    addHeaderRow(wsCats, ["Name", "Display Order", "Status"]);

    const DATA_START_CATS = 8;
    cats.forEach((cat, idx) => {
      const rowBg = idx % 2 === 0 ? C.rowEven : C.white;
      const row = wsCats.addRow([
        cat.name,
        cat.display_order,
        cat.is_active ? "Active" : "Inactive",
      ]);
      row.height = 24;
      row.eachCell({ includeEmpty: true }, (cell: any, colNum: number) => {
        cell.font = { name: "Cairo", size: 10, color: { argb: C.textDark } };
        cell.fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: rowBg },
        };
        cell.alignment = {
          vertical: "middle",
          horizontal: colNum === 1 ? "left" : "center",
          indent: colNum === 1 ? 1 : 0,
        };
        border(cell);
        if (colNum === 3) {
          cell.font = {
            name: "Cairo",
            size: 9,
            bold: true,
            color: { argb: cat.is_active ? C.green : C.red },
          };
        }
      });
    });

    // No numeric totals for categories — just a count footer
    const catFooter = wsCats.addRow([
      `${cats.length} categories total`,
      "",
      "",
    ]);
    catFooter.height = 28;
    catFooter.eachCell({ includeEmpty: true }, (cell: any) => {
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: C.logoBlue },
      };
      cell.font = {
        name: "Cairo",
        size: 10,
        bold: true,
        color: { argb: C.white },
      };
      cell.alignment = { vertical: "middle", horizontal: "center" };
      border(cell);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // SHEET 3 — Addons
    // ─────────────────────────────────────────────────────────────────────────
    const wsAddons = wb.addWorksheet("Addons", {
      pageSetup: { fitToPage: true, fitToWidth: 1, orientation: "landscape" },
      views: [{ state: "frozen", ySplit: 7 }],
    });

    wsAddons.columns = [
      { key: "name", width: 28 },
      { key: "addon_type", width: 20 },
      { key: "default_price", width: 18 },
      { key: "display_order", width: 16 },
      { key: "active", width: 12 },
    ];

    await addBanner(wsAddons, "E", "Addon Items");

    const activeAddons = addons.filter((a) => a.is_active);
    const avgAddonPrice =
      addons.length > 0
        ? addons.reduce((s, a) => s + a.default_price, 0) / addons.length / 100
        : 0;

    const ADDON_TYPE_ARGB: Record<string, string> = {
      coffee_type: "FF7C3AED",
      milk_type: "FF0D9488",
      extra: "FFD97706",
    };

    addStats(wsAddons, "E", [
      { label: "Total Addons", value: addons.length, color: C.logoBlue },
      { label: "Active", value: activeAddons.length, color: C.green },
      {
        label: "Inactive",
        value: addons.length - activeAddons.length,
        color: C.red,
      },
      {
        label: "Avg Price",
        value: avgAddonPrice,
        color: C.amber,
        fmt: '#,##0.00 "EGP"',
      },
    ]);

    addHeaderRow(wsAddons, [
      "Name",
      "Type",
      "Default Price (EGP)",
      "Display Order",
      "Status",
    ]);

    const DATA_START_ADDONS = 8;
    addons.forEach((addon, idx) => {
      const rowBg = idx % 2 === 0 ? C.rowEven : C.white;
      const row = wsAddons.addRow([
        addon.name,
        fmtAddonType(addon.addon_type),
        addon.default_price / 100,
        addon.display_order,
        addon.is_active ? "Active" : "Inactive",
      ]);
      row.height = 24;
      row.eachCell({ includeEmpty: true }, (cell: any, colNum: number) => {
        cell.font = {
          name: "Cairo",
          size: 10,
          color: { argb: addon.is_active ? C.textDark : C.textMuted },
          italic: !addon.is_active,
        };
        cell.fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: rowBg },
        };
        cell.alignment = {
          vertical: "middle",
          horizontal: [3, 4].includes(colNum)
            ? "center"
            : colNum === 1
              ? "left"
              : "center",
          indent: colNum === 1 ? 1 : 0,
        };
        border(cell);
        if (colNum === 2) {
          cell.font = {
            name: "Cairo",
            size: 9,
            bold: true,
            color: { argb: ADDON_TYPE_ARGB[addon.addon_type] ?? C.logoBlue },
          };
        }
        if (colNum === 3) cell.numFmt = "#,##0.00";
        if (colNum === 5) {
          cell.font = {
            name: "Cairo",
            size: 9,
            bold: true,
            color: { argb: addon.is_active ? C.green : C.red },
          };
        }
      });
    });

    addTotalsRow(
      wsAddons,
      [
        "",
        "TOTALS",
        { formula: `=SUM(C${DATA_START_ADDONS}:C${wsAddons.rowCount})` },
        "",
        "",
      ],
      [3],
    );

    // ─────────────────────────────────────────────────────────────────────────
    // Download
    // ─────────────────────────────────────────────────────────────────────────
    toast.dismiss();
    toast.loading("Downloading file…");

    const buffer = await wb.xlsx.writeBuffer();
    const blob = new Blob([buffer], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `Menu-Export-${new Date().toISOString().slice(0, 10)}.xlsx`;
    a.click();
    URL.revokeObjectURL(url);

    toast.dismiss();
    toast.success(
      `Exported ${items.length} items, ${cats.length} categories, ${addons.length} addons`,
    );
  } catch (err) {
    toast.dismiss();
    toast.error("Export failed");
    console.error(err);
  }
}

// ── Main component ────────────────────────────────────────────────────────────
export default function Menu() {
  const user = useAuthStore((s) => s.user);
  const orgId = useAppStore((s) => s.selectedOrgId) ?? user?.org_id ?? "";
  const qc = useQueryClient();
  const [tab, setTab] = useState("items");

  // ── Search state (per tab) ───────────────────────────────────────────────
  const [itemSearch, setItemSearch] = useState("");
  const [catSearch, setCatSearch] = useState("");
  const [addonSearch, setAddonSearch] = useState("");

  // ── Categories ────────────────────────────────────────────────────────────
  const { data: cats = [], isLoading: catsLoading } = useQuery({
    queryKey: ["categories", orgId],
    queryFn: () => menuApi.getCategories(orgId).then((r) => r.data),
    enabled: !!orgId,
  });

  // ── Menu items ────────────────────────────────────────────────────────────
  const [selCat, setSelCat] = useState<string | null>(null);
  const { data: items = [], isLoading: itemsLoading } = useQuery({
    queryKey: ["menu-items", orgId, selCat],
    queryFn: () => menuApi.getMenuItems(orgId, selCat).then((r) => r.data),
    enabled: !!orgId,
  });

  // ── Addon items ───────────────────────────────────────────────────────────
  const [selAddonType, setSelAddonType] = useState<string | null>(null);
  const { data: addons = [], isLoading: addonsLoading } = useQuery({
    queryKey: ["addon-items", orgId, selAddonType],
    queryFn: () =>
      menuApi.getAddonItems(orgId, selAddonType).then((r) => r.data),
    enabled: !!orgId,
  });

  // ── Filtered data ─────────────────────────────────────────────────────────
  const filteredItems = items.filter(
    (i) =>
      i.name.toLowerCase().includes(itemSearch.toLowerCase()) ||
      (i.description ?? "").toLowerCase().includes(itemSearch.toLowerCase()),
  );

  const filteredCats = cats.filter((c) =>
    c.name.toLowerCase().includes(catSearch.toLowerCase()),
  );

  const filteredAddons = addons.filter((a) =>
    a.name.toLowerCase().includes(addonSearch.toLowerCase()),
  );

  // ── Category dialog ───────────────────────────────────────────────────────
  const [catDialog, setCatDialog] = useState(false);
  const [editCat, setEditCat] = useState<Category | null>(null);
  const [catForm, setCatForm] = useState({ name: "", display_order: "0" });

  const openCatDialog = (cat?: Category) => {
    setEditCat(cat ?? null);
    setCatForm({
      name: cat?.name ?? "",
      display_order: String(cat?.display_order ?? 0),
    });
    setCatDialog(true);
  };

  const catMutation = useMutation({
    mutationFn: () =>
      editCat
        ? menuApi.updateCategory(editCat.id, {
            name: catForm.name,
            display_order: parseInt(catForm.display_order),
          })
        : menuApi.createCategory({
            org_id: orgId,
            name: catForm.name,
            display_order: parseInt(catForm.display_order),
          }),
    onSuccess: () => {
      toast.success(editCat ? "Category updated" : "Category created");
      qc.invalidateQueries({ queryKey: ["categories"] });
      setCatDialog(false);
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const deleteCatMutation = useMutation({
    mutationFn: (id: string) => menuApi.deleteCategory(id),
    onSuccess: () => {
      toast.success("Category deleted");
      qc.invalidateQueries({ queryKey: ["categories"] });
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Menu item dialog ──────────────────────────────────────────────────────
  const [itemDialog, setItemDialog] = useState(false);
  const [editItem, setEditItem] = useState<MenuItem | null>(null);
  const [itemForm, setItemForm] = useState({
    name: "",
    description: "",
    base_price: "",
    category_id: "",
    is_active: true,
  });

  const openItemDialog = (item?: MenuItem) => {
    setEditItem(item ?? null);
    setItemForm({
      name: item?.name ?? "",
      description: item?.description ?? "",
      base_price: item ? String(item.base_price / 100) : "",
      category_id: item?.category_id ?? "",
      is_active: item?.is_active ?? true,
    });
    setItemDialog(true);
  };

  const itemMutation = useMutation({
    mutationFn: () => {
      const payload = {
        org_id: orgId,
        name: itemForm.name,
        description: itemForm.description || null,
        base_price: Math.round(parseFloat(itemForm.base_price) * 100),
        category_id: itemForm.category_id || null,
        is_active: itemForm.is_active,
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
    mutationFn: (item: MenuItem) =>
      menuApi.updateMenuItem(item.id, { is_active: !item.is_active }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["menu-items"] }),
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  // ── Addon dialog ──────────────────────────────────────────────────────────
  const [addonDialog, setAddonDialog] = useState(false);
  const [editAddon, setEditAddon] = useState<AddonItem | null>(null);
  const [addonForm, setAddonForm] = useState({
    name: "",
    addon_type: "extra",
    default_price: "",
    display_order: "0",
  });

  const openAddonDialog = (addon?: AddonItem) => {
    setEditAddon(addon ?? null);
    setAddonForm({
      name: addon?.name ?? "",
      addon_type: addon?.addon_type ?? "extra",
      default_price: addon ? String(addon.default_price / 100) : "",
      display_order: String(addon?.display_order ?? 0),
    });
    setAddonDialog(true);
  };

  const addonMutation = useMutation({
    mutationFn: () => {
      const payload = {
        org_id: orgId,
        name: addonForm.name,
        addon_type: addonForm.addon_type,
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

  // ── Column definitions ────────────────────────────────────────────────────
  const itemCols: ColumnDef<MenuItem, any>[] = [
    {
      accessorKey: "name",
      header: "Name",
      cell: ({ row }) => (
        <div>
          <p className="font-semibold text-sm">{row.original.name}</p>
          {row.original.description && (
            <p className="text-xs text-muted-foreground truncate max-w-[200px]">
              {row.original.description}
            </p>
          )}
        </div>
      ),
    },
    {
      accessorKey: "base_price",
      header: "Price",
      cell: ({ row }) => (
        <span className="font-semibold tabular-nums">
          {egp(row.original.base_price)}
        </span>
      ),
    },
    {
      accessorKey: "category_id",
      header: "Category",
      cell: ({ row }) => {
        const cat = cats.find((c) => c.id === row.original.category_id);
        return cat ? (
          <Badge variant="outline">{cat.name}</Badge>
        ) : (
          <span className="text-muted-foreground text-xs">—</span>
        );
      },
    },
    {
      accessorKey: "is_active",
      header: "Active",
      cell: ({ row }) => (
        <button
          onClick={(e) => {
            e.stopPropagation();
            toggleItem.mutate(row.original);
          }}
        >
          {row.original.is_active ? (
            <ToggleRight size={20} className="text-green-500" />
          ) : (
            <ToggleLeft size={20} className="text-muted-foreground" />
          )}
        </button>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <div
          className="flex items-center gap-1 justify-end"
          onClick={(e) => e.stopPropagation()}
        >
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => openItemDialog(row.original)}
          >
            <Pencil size={13} />
          </Button>
        </div>
      ),
    },
  ];

  const catCols: ColumnDef<Category, any>[] = [
    {
      accessorKey: "name",
      header: "Name",
      cell: ({ row }) => (
        <span className="font-semibold">{row.original.name}</span>
      ),
    },
    { accessorKey: "display_order", header: "Order" },
    {
      accessorKey: "is_active",
      header: "Active",
      cell: ({ row }) => (
        <Badge variant={row.original.is_active ? "success" : "outline"}>
          {row.original.is_active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <div className="flex items-center gap-1 justify-end">
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => openCatDialog(row.original)}
          >
            <Pencil size={13} />
          </Button>
          <Button
            variant="ghost"
            size="icon-sm"
            className="text-destructive"
            onClick={() => deleteCatMutation.mutate(row.original.id)}
          >
            <Trash2 size={13} />
          </Button>
        </div>
      ),
    },
  ];

  const addonCols: ColumnDef<AddonItem, any>[] = [
    {
      accessorKey: "name",
      header: "Name",
      cell: ({ row }) => (
        <span className="font-semibold">{row.original.name}</span>
      ),
    },
    {
      accessorKey: "addon_type",
      header: "Type",
      cell: ({ row }) => (
        <Badge variant="info">{fmtAddonType(row.original.addon_type)}</Badge>
      ),
    },
    {
      accessorKey: "default_price",
      header: "Price",
      cell: ({ row }) => (
        <span className="tabular-nums">{egp(row.original.default_price)}</span>
      ),
    },
    {
      accessorKey: "is_active",
      header: "Active",
      cell: ({ row }) => (
        <Badge variant={row.original.is_active ? "success" : "outline"}>
          {row.original.is_active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <div className="flex justify-end">
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => openAddonDialog(row.original)}
          >
            <Pencil size={13} />
          </Button>
        </div>
      ),
    },
  ];

  const isExportReady = !itemsLoading && !catsLoading && !addonsLoading;

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader
        title="Menu"
        sub="Manage categories, items and addons"
        actions={
          <Button
            variant="outline"
            size="sm"
            disabled={
              !isExportReady ||
              (items.length === 0 && cats.length === 0 && addons.length === 0)
            }
            onClick={() =>
              exportMenuXLSX({ orgId, branchName: "", items, cats, addons })
            }
          >
            <Download size={13} /> Export Excel
          </Button>
        }
      />

      <Tabs value={tab} onValueChange={setTab}>
        <TabsList className="mb-6">
          <TabsTrigger value="items">
            <Coffee size={14} /> Items ({items.length})
          </TabsTrigger>
          <TabsTrigger value="categories">
            <Tag size={14} /> Categories ({cats.length})
          </TabsTrigger>
          <TabsTrigger value="addons">
            <Package size={14} /> Addons ({addons.length})
          </TabsTrigger>
        </TabsList>

        {/* ── Items tab ── */}
        <TabsContent value="items">
          <div className="mb-4 flex items-center gap-3 flex-wrap">
            <Input
              className="h-9 w-56"
              placeholder="Search items…"
              value={itemSearch}
              onChange={(e) => setItemSearch(e.target.value)}
            />
            <Select
              value={selCat ?? "all"}
              onValueChange={(v) => setSelCat(v === "all" ? null : v)}
            >
              <SelectTrigger className="w-48 h-9">
                <SelectValue placeholder="All categories" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All categories</SelectItem>
                {cats.map((c) => (
                  <SelectItem key={c.id} value={c.id}>
                    {c.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button
              size="sm"
              className="ml-auto"
              onClick={() => openItemDialog()}
            >
              <Plus size={14} /> Add Item
            </Button>
          </div>
          {itemsLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-14 rounded-xl" />
              ))}
            </div>
          ) : filteredItems.length === 0 ? (
            <EmptyState
              icon={Coffee}
              title="No items found"
              sub={
                itemSearch
                  ? "Try a different search term"
                  : "Add your first menu item"
              }
            />
          ) : (
            <DataTable
              data={filteredItems}
              columns={itemCols}
              searchPlaceholder="Search items…"
              onRowClick={openItemDialog}
            />
          )}
        </TabsContent>

        {/* ── Categories tab ── */}
        <TabsContent value="categories">
          <div className="mb-4 flex items-center gap-3 flex-wrap">
            <Input
              className="h-9 w-56"
              placeholder="Search categories…"
              value={catSearch}
              onChange={(e) => setCatSearch(e.target.value)}
            />
            <Button
              size="sm"
              className="ml-auto"
              onClick={() => openCatDialog()}
            >
              <Plus size={14} /> Add Category
            </Button>
          </div>
          {catsLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-12 rounded-xl" />
              ))}
            </div>
          ) : filteredCats.length === 0 ? (
            <EmptyState
              icon={Tag}
              title="No categories found"
              sub={
                catSearch
                  ? "Try a different search term"
                  : "Add your first category"
              }
            />
          ) : (
            <DataTable
              data={filteredCats}
              columns={catCols}
              searchPlaceholder="Search categories…"
            />
          )}
        </TabsContent>

        {/* ── Addons tab ── */}
        <TabsContent value="addons">
          <div className="mb-4 flex items-center gap-3 flex-wrap">
            <Input
              className="h-9 w-56"
              placeholder="Search addons…"
              value={addonSearch}
              onChange={(e) => setAddonSearch(e.target.value)}
            />
            <Select
              value={selAddonType ?? "all"}
              onValueChange={(v) => setSelAddonType(v === "all" ? null : v)}
            >
              <SelectTrigger className="w-44 h-9">
                <SelectValue placeholder="All types" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All types</SelectItem>
                {Object.entries(ADDON_TYPE_LABELS).map(([k, v]) => (
                  <SelectItem key={k} value={k}>
                    {v}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button
              size="sm"
              className="ml-auto"
              onClick={() => openAddonDialog()}
            >
              <Plus size={14} /> Add Addon
            </Button>
          </div>
          {addonsLoading ? (
            <div className="space-y-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-12 rounded-xl" />
              ))}
            </div>
          ) : filteredAddons.length === 0 ? (
            <EmptyState
              icon={Package}
              title="No addons found"
              sub={
                addonSearch
                  ? "Try a different search term"
                  : "Add your first addon"
              }
            />
          ) : (
            <DataTable
              data={filteredAddons}
              columns={addonCols}
              searchPlaceholder="Search addons…"
            />
          )}
        </TabsContent>
      </Tabs>

      {/* ── Category dialog ── */}
      <Dialog open={catDialog} onOpenChange={setCatDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {editCat ? "Edit Category" : "New Category"}
            </DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Name</Label>
              <Input
                value={catForm.name}
                onChange={(e) =>
                  setCatForm((f) => ({ ...f, name: e.target.value }))
                }
                placeholder="e.g. Hot Drinks"
              />
            </div>
            <div className="space-y-1.5">
              <Label>Display Order</Label>
              <Input
                type="number"
                value={catForm.display_order}
                onChange={(e) =>
                  setCatForm((f) => ({ ...f, display_order: e.target.value }))
                }
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCatDialog(false)}>
              Cancel
            </Button>
            <Button
              loading={catMutation.isPending}
              onClick={() => catMutation.mutate()}
            >
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Item dialog ── */}
      <Dialog open={itemDialog} onOpenChange={setItemDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editItem ? "Edit Item" : "New Item"}</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Name</Label>
              <Input
                value={itemForm.name}
                onChange={(e) =>
                  setItemForm((f) => ({ ...f, name: e.target.value }))
                }
                placeholder="e.g. Latte"
              />
            </div>
            <div className="space-y-1.5">
              <Label>Description</Label>
              <Input
                value={itemForm.description}
                onChange={(e) =>
                  setItemForm((f) => ({ ...f, description: e.target.value }))
                }
                placeholder="Optional"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label>Price (EGP)</Label>
                <Input
                  type="number"
                  step="0.5"
                  value={itemForm.base_price}
                  onChange={(e) =>
                    setItemForm((f) => ({ ...f, base_price: e.target.value }))
                  }
                  placeholder="0.00"
                />
              </div>
              <div className="space-y-1.5">
                <Label>Category</Label>
                <Select
                  value={itemForm.category_id || "none"}
                  onValueChange={(v) =>
                    setItemForm((f) => ({
                      ...f,
                      category_id: v === "none" ? "" : v,
                    }))
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder="None" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">No category</SelectItem>
                    {cats.map((c) => (
                      <SelectItem key={c.id} value={c.id}>
                        {c.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Switch
                checked={itemForm.is_active}
                onCheckedChange={(v) =>
                  setItemForm((f) => ({ ...f, is_active: v }))
                }
              />
              <Label>Active</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setItemDialog(false)}>
              Cancel
            </Button>
            <Button
              loading={itemMutation.isPending}
              onClick={() => itemMutation.mutate()}
            >
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ── Addon dialog ── */}
      <Dialog open={addonDialog} onOpenChange={setAddonDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{editAddon ? "Edit Addon" : "New Addon"}</DialogTitle>
          </DialogHeader>
          <div className="p-6 space-y-4">
            <div className="space-y-1.5">
              <Label>Name</Label>
              <Input
                value={addonForm.name}
                onChange={(e) =>
                  setAddonForm((f) => ({ ...f, name: e.target.value }))
                }
                placeholder="e.g. Oat Milk"
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <Label>Type</Label>
                <Select
                  value={addonForm.addon_type}
                  onValueChange={(v) =>
                    setAddonForm((f) => ({ ...f, addon_type: v }))
                  }
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {Object.entries(ADDON_TYPE_LABELS).map(([k, v]) => (
                      <SelectItem key={k} value={k}>
                        {v}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label>Default Price (EGP)</Label>
                <Input
                  type="number"
                  step="0.5"
                  value={addonForm.default_price}
                  onChange={(e) =>
                    setAddonForm((f) => ({
                      ...f,
                      default_price: e.target.value,
                    }))
                  }
                  placeholder="0.00"
                />
              </div>
            </div>
            <div className="space-y-1.5">
              <Label>Display Order</Label>
              <Input
                type="number"
                value={addonForm.display_order}
                onChange={(e) =>
                  setAddonForm((f) => ({ ...f, display_order: e.target.value }))
                }
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAddonDialog(false)}>
              Cancel
            </Button>
            <Button
              loading={addonMutation.isPending}
              onClick={() => addonMutation.mutate()}
            >
              Save
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
