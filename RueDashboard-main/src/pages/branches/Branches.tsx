import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { type ColumnDef } from "@tanstack/react-table";
import {
  Plus, GitBranch, Edit2, Trash2, Printer,
  CheckCircle, XCircle, MapPin, Phone, Wifi,
} from "lucide-react";
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
import { getBranches, createBranch, updateBranch, deleteBranch } from "@/api/branches";
import { getOrgs } from "@/api/orgs";
import { getErrorMessage } from "@/lib/client";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import type { Branch, PrinterBrand } from "@/types";

const PRINTER_BRANDS: { value: PrinterBrand; label: string }[] = [
  { value: "star",  label: "Star TSP100" },
  { value: "epson", label: "Epson TM-T88" },
];

// ── Branch form dialog ────────────────────────────────────────────────────────
function BranchFormDialog({
  open, onClose, orgId, editBranch,
}: {
  open:         boolean;
  onClose:      () => void;
  orgId:        string;
  editBranch?:  Branch | null;
}) {
  const qc = useQueryClient();
  const [name,         setName]         = useState(editBranch?.name         ?? "");
  const [address,      setAddress]      = useState(editBranch?.address      ?? "");
  const [phone,        setPhone]        = useState(editBranch?.phone        ?? "");
  const [timezone,     setTimezone]     = useState(editBranch?.timezone     ?? "Africa/Cairo");
  const [isActive,     setIsActive]     = useState(editBranch?.is_active    ?? true);
  const [printerBrand, setPrinterBrand] = useState<PrinterBrand | "none">(editBranch?.printer_brand ?? "none");
  const [printerIp,    setPrinterIp]    = useState(editBranch?.printer_ip   ?? "");
  const [printerPort,  setPrinterPort]  = useState(String(editBranch?.printer_port ?? 9100));

  React.useEffect(() => {
    if (editBranch) {
      setName(editBranch.name); setAddress(editBranch.address ?? "");
      setPhone(editBranch.phone ?? ""); setTimezone(editBranch.timezone);
      setIsActive(editBranch.is_active);
      setPrinterBrand(editBranch.printer_brand ?? "none");
      setPrinterIp(editBranch.printer_ip ?? "");
      setPrinterPort(String(editBranch.printer_port ?? 9100));
    } else {
      setName(""); setAddress(""); setPhone(""); setTimezone("Africa/Cairo");
      setIsActive(true); setPrinterBrand("none"); setPrinterIp(""); setPrinterPort("9100");
    }
  }, [editBranch, open]);

  const { mutate, isPending } = useMutation({
    mutationFn: () => {
      const hasPrinter = printerBrand !== "none" && printerIp;
      const payload = {
        org_id:        orgId,
        name, address, phone, timezone, is_active: isActive,
        printer_brand: hasPrinter ? printerBrand : null,
        printer_ip:    hasPrinter ? printerIp    : null,
        printer_port:  hasPrinter ? parseInt(printerPort, 10) : null,
      };
      return editBranch
        ? updateBranch(editBranch.id, payload)
        : createBranch(payload as Parameters<typeof createBranch>[0]);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["branches"] });
      toast.success(editBranch ? "Branch updated" : "Branch created");
      onClose();
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>{editBranch ? "Edit Branch" : "New Branch"}</DialogTitle>
          <DialogDescription>
            {editBranch ? "Update branch details." : "Add a new branch location."}
          </DialogDescription>
        </DialogHeader>
        <div className="px-6 py-4 space-y-4">
          <div className="space-y-2">
            <Label>Branch Name</Label>
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Maadi Branch" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label>Phone</Label>
              <Input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+20 2 xxxx xxxx" />
            </div>
            <div className="space-y-2">
              <Label>Timezone</Label>
              <Input value={timezone} onChange={(e) => setTimezone(e.target.value)} placeholder="Africa/Cairo" />
            </div>
          </div>
          <div className="space-y-2">
            <Label>Address</Label>
            <Input value={address} onChange={(e) => setAddress(e.target.value)} placeholder="123 Road St, Cairo" />
          </div>

          {/* Printer config */}
          <div className="space-y-3 rounded-xl border border-border p-3">
            <div className="flex items-center gap-2 mb-1">
              <Printer size={13} className="text-muted-foreground" />
              <p className="text-sm font-semibold">Printer Configuration</p>
            </div>
            <div className="space-y-2">
              <Label>Printer Model</Label>
              <Select value={printerBrand} onValueChange={(v) => setPrinterBrand(v as PrinterBrand | "none")}>
                <SelectTrigger>
                  <SelectValue placeholder="None" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">None (no printer)</SelectItem>
                  {PRINTER_BRANDS.map((p) => (
                    <SelectItem key={p.value} value={p.value}>{p.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            {printerBrand !== "none" && (
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-2">
                  <Label>Printer IP</Label>
                  <Input
                    value={printerIp}
                    onChange={(e) => setPrinterIp(e.target.value)}
                    placeholder="192.168.1.100"
                    className="font-mono"
                  />
                </div>
                <div className="space-y-2">
                  <Label>Port</Label>
                  <Input
                    type="number"
                    value={printerPort}
                    onChange={(e) => setPrinterPort(e.target.value)}
                    placeholder="9100"
                    className="font-mono"
                  />
                </div>
              </div>
            )}
          </div>

          {editBranch && (
            <div className="flex items-center justify-between rounded-xl bg-muted p-3">
              <div>
                <p className="text-sm font-medium">Active Branch</p>
                <p className="text-xs text-muted-foreground">Inactive branches are hidden from tellers</p>
              </div>
              <Switch checked={isActive} onCheckedChange={setIsActive} />
            </div>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button loading={isPending} onClick={() => mutate()} disabled={!name}>
            {editBranch ? "Save Changes" : "Create Branch"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ── Main Branches page ────────────────────────────────────────────────────────
export default function Branches() {
  const [formOpen,   setFormOpen]   = useState(false);
  const [editBranch, setEditBranch] = useState<Branch | null>(null);
  const qc           = useQueryClient();
  const authUser     = useAuthStore((s) => s.user);
  const selectedOrg  = useAppStore((s) => s.selectedOrgId);
  const orgId        = selectedOrg ?? authUser?.org_id ?? "";

  const { data: branches = [], isLoading } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const { mutate: del } = useMutation({
    mutationFn: (id: string) => deleteBranch(id),
    onSuccess:  () => { qc.invalidateQueries({ queryKey: ["branches"] }); toast.success("Branch deleted"); },
    onError:    (e) => toast.error(getErrorMessage(e)),
  });

  const columns: ColumnDef<Branch>[] = [
    {
      accessorKey: "name",
      header:      "Branch",
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
            <GitBranch size={14} className="text-primary" />
          </div>
          <div className="min-w-0">
            <p className="font-semibold text-sm truncate">{row.original.name}</p>
            {row.original.address && (
              <p className="text-xs text-muted-foreground truncate flex items-center gap-1">
                <MapPin size={9} /> {row.original.address}
              </p>
            )}
          </div>
        </div>
      ),
    },
    {
      accessorKey: "phone",
      header:      "Phone",
      cell: ({ row }) => row.original.phone
        ? <span className="text-sm font-mono flex items-center gap-1"><Phone size={11} />{row.original.phone}</span>
        : <span className="text-muted-foreground text-sm">—</span>,
    },
    {
      accessorKey: "printer_brand",
      header:      "Printer",
      cell: ({ row }) => row.original.printer_brand
        ? (
          <div className="flex items-center gap-1.5">
            <Printer size={12} className="text-muted-foreground" />
            <div>
              <p className="text-xs font-semibold capitalize">{row.original.printer_brand}</p>
              <p className="text-[10px] text-muted-foreground font-mono">{row.original.printer_ip}:{row.original.printer_port}</p>
            </div>
          </div>
        )
        : <span className="text-muted-foreground text-xs">No printer</span>,
    },
    {
      accessorKey: "is_active",
      header:      "Status",
      cell: ({ getValue }) => getValue()
        ? <Badge variant="success"><CheckCircle size={11} /> Active</Badge>
        : <Badge variant="destructive"><XCircle size={11} /> Inactive</Badge>,
    },
    {
      id:   "actions",
      header: "",
      cell: ({ row }) => (
        <div className="flex items-center gap-1 justify-end" onClick={(e) => e.stopPropagation()}>
          <Button
            variant="ghost" size="icon-sm"
            onClick={() => { setEditBranch(row.original); setFormOpen(true); }}
          >
            <Edit2 size={13} />
          </Button>
          <Button
            variant="ghost" size="icon-sm"
            className="text-destructive hover:text-destructive"
            onClick={() => {
              if (confirm(`Delete branch "${row.original.name}"?`)) del(row.original.id);
            }}
          >
            <Trash2 size={13} />
          </Button>
        </div>
      ),
    },
  ];

  return (
    <PageShell
      title="Branches"
      description="Manage your branch locations and printer config"
      action={
        <Button onClick={() => { setEditBranch(null); setFormOpen(true); }}>
          <Plus size={15} /> New Branch
        </Button>
      }
    >
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[
          { label: "Total",     value: branches.length,                               color: "text-primary"   },
          { label: "Active",    value: branches.filter((b) => b.is_active).length,    color: "text-green-600" },
          { label: "With Printer", value: branches.filter((b) => b.printer_brand).length, color: "text-violet-600" },
          { label: "Inactive",  value: branches.filter((b) => !b.is_active).length,   color: "text-amber-600" },
        ].map(({ label, value, color }) => (
          <Card key={label} className="p-4">
            <p className={`text-2xl font-extrabold ${color}`}>{isLoading ? "—" : value}</p>
            <p className="text-xs text-muted-foreground mt-1">{label}</p>
          </Card>
        ))}
      </div>

      <DataTable
        columns={columns}
        data={branches}
        isLoading={isLoading}
        searchKey="name"
        searchPlaceholder="Search branches…"
        emptyState={
          <div className="flex flex-col items-center gap-2 py-4">
            <GitBranch size={32} className="text-muted-foreground/40" />
            <p>No branches yet</p>
            <Button size="sm" onClick={() => setFormOpen(true)}><Plus size={13} /> Add branch</Button>
          </div>
        }
      />

      <BranchFormDialog
        open={formOpen}
        onClose={() => { setFormOpen(false); setEditBranch(null); }}
        orgId={orgId}
        editBranch={editBranch}
      />
    </PageShell>
  );
}
