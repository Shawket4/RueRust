import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { type ColumnDef } from "@tanstack/react-table";
import { Plus, Tag, Edit2, Trash2, CheckCircle, XCircle, Percent, DollarSign } from "lucide-react";
import { toast } from "sonner";
import { PageShell, Card } from "@/components/ui/page-shell";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle,
  DialogFooter, DialogDescription,
} from "@/components/ui/dialog";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import * as discountsApi from "@/api/discounts";
import { getErrorMessage } from "@/lib/client";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import { egp } from "@/utils/format";
import type { Discount } from "@/types";

// ── Form dialog ───────────────────────────────────────────────────────────────
function DiscountFormDialog({
  open, onClose, orgId, editDiscount,
}: {
  open:          boolean;
  onClose:       () => void;
  orgId:         string;
  editDiscount?: Discount | null;
}) {
  const qc = useQueryClient();
  const [name,      setName]      = useState(editDiscount?.name  ?? "");
  const [dtype,     setDtype]     = useState<"percentage" | "fixed">(
    (editDiscount?.dtype as "percentage" | "fixed") ?? "percentage"
  );
  const [value,     setValue]     = useState(
    editDiscount ? String(editDiscount.dtype === "percentage"
      ? editDiscount.value
      : editDiscount.value / 100)
    : ""
  );
  const [isActive,  setIsActive]  = useState(editDiscount?.is_active ?? true);

  React.useEffect(() => {
    if (editDiscount) {
      setName(editDiscount.name);
      setDtype(editDiscount.dtype as "percentage" | "fixed");
      setValue(editDiscount.dtype === "percentage"
        ? String(editDiscount.value)
        : String(editDiscount.value / 100));
      setIsActive(editDiscount.is_active);
    } else {
      setName(""); setDtype("percentage"); setValue(""); setIsActive(true);
    }
  }, [editDiscount, open]);

  const { mutate, isPending } = useMutation({
    mutationFn: () => {
      // value stored as integer: % direct, fixed as piastres
      const intValue = dtype === "percentage"
        ? parseInt(value, 10)
        : Math.round(parseFloat(value) * 100);

      const payload = { org_id: orgId, name, dtype, value: intValue, is_active: isActive };
      return editDiscount
        ? discountsApi.updateDiscount(editDiscount.id, { name, dtype, value: intValue, is_active: isActive })
        : discountsApi.createDiscount(payload);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["discounts"] });
      toast.success(editDiscount ? "Discount updated" : "Discount created");
      onClose();
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const displayValue = dtype === "percentage"
    ? `${value}% off`
    : value ? `EGP ${parseFloat(value).toFixed(0)} off` : "";

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{editDiscount ? "Edit Discount" : "New Discount"}</DialogTitle>
          <DialogDescription>
            {editDiscount ? "Update this discount preset." : "Create a reusable discount for tellers to apply at checkout."}
          </DialogDescription>
        </DialogHeader>
        <div className="px-6 py-4 space-y-4">
          {/* Name */}
          <div className="space-y-2">
            <Label>Discount Name</Label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Staff Discount, Promo 10%"
            />
          </div>

          {/* Type + Value */}
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label>Type</Label>
              <Select value={dtype} onValueChange={(v) => setDtype(v as "percentage" | "fixed")}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="percentage">
                    <span className="flex items-center gap-2"><Percent size={13} /> Percentage</span>
                  </SelectItem>
                  <SelectItem value="fixed">
                    <span className="flex items-center gap-2"><DollarSign size={13} /> Fixed Amount</span>
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>{dtype === "percentage" ? "Percentage (%)" : "Amount (EGP)"}</Label>
              <Input
                type="number"
                step={dtype === "percentage" ? "1" : "0.5"}
                min="0"
                max={dtype === "percentage" ? "100" : undefined}
                value={value}
                onChange={(e) => setValue(e.target.value)}
                placeholder={dtype === "percentage" ? "e.g. 10" : "e.g. 5.00"}
              />
            </div>
          </div>

          {/* Preview */}
          {displayValue && (
            <div className="bg-accent rounded-xl px-4 py-3 flex items-center gap-3">
              <Tag size={15} className="text-accent-foreground flex-shrink-0" />
              <div>
                <p className="text-sm font-semibold">{name || "Discount"}</p>
                <p className="text-xs text-muted-foreground">{displayValue}</p>
              </div>
            </div>
          )}

          {/* Active toggle */}
          <div className="flex items-center justify-between rounded-xl bg-muted p-3">
            <div>
              <p className="text-sm font-medium">Active</p>
              <p className="text-xs text-muted-foreground">Inactive discounts won't appear in the POS app</p>
            </div>
            <Switch checked={isActive} onCheckedChange={setIsActive} />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button
            loading={isPending}
            onClick={() => mutate()}
            disabled={!name || !value}
          >
            {editDiscount ? "Save Changes" : "Create Discount"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ── Main Discounts page ───────────────────────────────────────────────────────
export default function Discounts() {
  const [formOpen,      setFormOpen]      = useState(false);
  const [editDiscount,  setEditDiscount]  = useState<Discount | null>(null);

  const qc         = useQueryClient();
  const authUser   = useAuthStore((s) => s.user);
  const selectedOrg = useAppStore((s) => s.selectedOrgId);
  const orgId      = selectedOrg ?? authUser?.org_id ?? "";

  const { data: discounts = [], isLoading } = useQuery({
    queryKey: ["discounts", orgId],
    queryFn:  () => discountsApi.getDiscounts(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const { mutate: del } = useMutation({
    mutationFn: (id: string) => discountsApi.deleteDiscount(id),
    onSuccess:  () => { qc.invalidateQueries({ queryKey: ["discounts"] }); toast.success("Discount deleted"); },
    onError:    (e) => toast.error(getErrorMessage(e)),
  });

  const { mutate: toggleActive } = useMutation({
    mutationFn: (d: Discount) =>
      discountsApi.updateDiscount(d.id, { is_active: !d.is_active }),
    onSuccess:  () => qc.invalidateQueries({ queryKey: ["discounts"] }),
    onError:    (e) => toast.error(getErrorMessage(e)),
  });

  const columns: ColumnDef<Discount>[] = [
    {
      accessorKey: "name",
      header:      "Discount",
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <div className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 ${
            row.original.dtype === "percentage"
              ? "bg-violet-100 dark:bg-violet-950/50"
              : "bg-green-100 dark:bg-green-950/50"
          }`}>
            {row.original.dtype === "percentage"
              ? <Percent size={15} className="text-violet-600" />
              : <DollarSign size={15} className="text-green-600" />}
          </div>
          <div>
            <p className="font-semibold text-sm">{row.original.name}</p>
            <p className="text-xs text-muted-foreground">
              {row.original.dtype === "percentage"
                ? `${row.original.value}% off subtotal`
                : `${egp(row.original.value)} off subtotal`}
            </p>
          </div>
        </div>
      ),
    },
    {
      accessorKey: "dtype",
      header:      "Type",
      cell: ({ row }) => (
        <Badge variant={row.original.dtype === "percentage" ? "info" : "success"}>
          {row.original.dtype === "percentage" ? "Percentage" : "Fixed Amount"}
        </Badge>
      ),
    },
    {
      accessorKey: "value",
      header:      "Value",
      cell: ({ row }) => (
        <span className="font-semibold tabular-nums text-sm">
          {row.original.dtype === "percentage"
            ? `${row.original.value}%`
            : egp(row.original.value)}
        </span>
      ),
    },
    {
      accessorKey: "is_active",
      header:      "Status",
      cell: ({ row }) => (
        <button onClick={(e) => { e.stopPropagation(); toggleActive(row.original); }}>
          {row.original.is_active
            ? <Badge variant="success"><CheckCircle size={11} /> Active</Badge>
            : <Badge variant="outline"><XCircle size={11} /> Inactive</Badge>}
        </button>
      ),
    },
    {
      id:     "actions",
      header: "",
      cell:   ({ row }) => (
        <div className="flex items-center gap-1 justify-end" onClick={(e) => e.stopPropagation()}>
          <Button
            variant="ghost" size="icon-sm"
            onClick={() => { setEditDiscount(row.original); setFormOpen(true); }}
          >
            <Edit2 size={13} />
          </Button>
          <Button
            variant="ghost" size="icon-sm"
            className="text-destructive hover:text-destructive"
            onClick={() => {
              if (confirm(`Delete "${row.original.name}"?`)) del(row.original.id);
            }}
          >
            <Trash2 size={13} />
          </Button>
        </div>
      ),
    },
  ];

  const active   = discounts.filter((d) => d.is_active).length;
  const inactive = discounts.filter((d) => !d.is_active).length;
  const pct      = discounts.filter((d) => d.dtype === "percentage").length;
  const fixed    = discounts.filter((d) => d.dtype === "fixed").length;

  return (
    <PageShell
      title="Discounts"
      description="Manage discount presets available to tellers at checkout"
      action={
        <Button onClick={() => { setEditDiscount(null); setFormOpen(true); }}>
          <Plus size={15} /> New Discount
        </Button>
      }
    >
      {/* Summary cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[
          { label: "Total",       value: discounts.length, color: "text-primary"    },
          { label: "Active",      value: active,           color: "text-green-600"  },
          { label: "Percentage",  value: pct,              color: "text-violet-600" },
          { label: "Fixed",       value: fixed,            color: "text-amber-600"  },
        ].map(({ label, value, color }) => (
          <Card key={label} className="p-4">
            <p className={`text-2xl font-extrabold ${color}`}>{isLoading ? "—" : value}</p>
            <p className="text-xs text-muted-foreground mt-1">{label}</p>
          </Card>
        ))}
      </div>

      {discounts.length === 0 && !isLoading ? (
        <div className="rounded-2xl border bg-card p-12 flex flex-col items-center gap-3 text-center">
          <div className="w-14 h-14 rounded-2xl bg-muted flex items-center justify-center">
            <Tag size={24} className="text-muted-foreground" />
          </div>
          <p className="font-semibold">No discounts yet</p>
          <p className="text-sm text-muted-foreground max-w-xs">
            Create discount presets that tellers can apply when placing orders from the POS app.
          </p>
          <Button onClick={() => setFormOpen(true)}>
            <Plus size={14} /> Create First Discount
          </Button>
        </div>
      ) : (
        <DataTable
          columns={columns}
          data={discounts}
          isLoading={isLoading}
          searchKey="name"
          searchPlaceholder="Search discounts…"
        />
      )}

      <DiscountFormDialog
        open={formOpen}
        onClose={() => { setFormOpen(false); setEditDiscount(null); }}
        orgId={orgId}
        editDiscount={editDiscount}
      />
    </PageShell>
  );
}
