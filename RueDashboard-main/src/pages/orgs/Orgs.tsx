import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { type ColumnDef } from "@tanstack/react-table";
import { Plus, Building2, Edit2, Trash2, CheckCircle, XCircle } from "lucide-react";
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
import { getOrgs, createOrg } from "@/api/orgs";
import { getErrorMessage } from "@/lib/client";
import type { Org } from "@/types";

function OrgDialog({
  open, onClose,
}: { open: boolean; onClose: () => void }) {
  const qc = useQueryClient();
  const [name,     setName]     = useState("");
  const [slug,     setSlug]     = useState("");
  const [currency, setCurrency] = useState("EGP");
  const [taxRate,  setTaxRate]  = useState("0");

  const { mutate, isPending } = useMutation({
    mutationFn: () => createOrg({ name, slug, currency_code: currency, tax_rate: parseFloat(taxRate) || 0 }),
    onSuccess:  () => {
      qc.invalidateQueries({ queryKey: ["orgs"] });
      toast.success("Organization created");
      onClose();
      setName(""); setSlug(""); setCurrency("EGP"); setTaxRate("0");
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New Organization</DialogTitle>
          <DialogDescription>Create a new coffee brand or franchise.</DialogDescription>
        </DialogHeader>
        <div className="px-6 py-4 space-y-4">
          <div className="space-y-2">
            <Label htmlFor="org-name">Name</Label>
            <Input id="org-name" value={name} onChange={(e) => {
              setName(e.target.value);
              setSlug(e.target.value.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, ""));
            }} placeholder="The Rue Coffee" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="org-slug">Slug</Label>
            <Input id="org-slug" value={slug} onChange={(e) => setSlug(e.target.value)} placeholder="the-rue-coffee" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label>Currency</Label>
              <Input value={currency} onChange={(e) => setCurrency(e.target.value)} placeholder="EGP" />
            </div>
            <div className="space-y-2">
              <Label>Tax Rate (%)</Label>
              <Input type="number" value={taxRate} onChange={(e) => setTaxRate(e.target.value)} placeholder="14" />
            </div>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button loading={isPending} onClick={() => mutate()} disabled={!name || !slug}>
            Create Organization
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export default function Orgs() {
  const [dialogOpen, setDialogOpen] = useState(false);
  const { data: orgs = [], isLoading } = useQuery({
    queryKey: ["orgs"],
    queryFn:  () => getOrgs().then((r) => r.data),
  });

  const columns: ColumnDef<Org>[] = [
    {
      accessorKey: "name",
      header:      "Name",
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 brand-gradient rounded-xl flex items-center justify-center text-white font-bold text-xs flex-shrink-0">
            {row.original.name.slice(0, 2).toUpperCase()}
          </div>
          <div className="min-w-0">
            <p className="font-semibold truncate">{row.original.name}</p>
            <p className="text-xs text-muted-foreground">{row.original.slug}</p>
          </div>
        </div>
      ),
    },
    {
      accessorKey: "currency_code",
      header:      "Currency",
      cell: ({ getValue }) => (
        <Badge variant="outline" className="font-mono">{getValue() as string}</Badge>
      ),
    },
    {
      accessorKey: "tax_rate",
      header:      "Tax Rate",
      cell: ({ getValue }) => (
        <span className="font-mono text-sm">{getValue() as number}%</span>
      ),
    },
    {
      accessorKey: "is_active",
      header:      "Status",
      cell: ({ getValue }) => getValue()
        ? <Badge variant="success"><CheckCircle size={11} /> Active</Badge>
        : <Badge variant="destructive"><XCircle size={11} /> Inactive</Badge>,
    },
  ];

  return (
    <PageShell
      title="Organizations"
      description="Manage all coffee brands and franchises"
      action={
        <Button onClick={() => setDialogOpen(true)}>
          <Plus size={15} /> New Organization
        </Button>
      }
    >
      {/* Summary cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {[
          { label: "Total",    value: orgs.length,                             color: "text-primary"   },
          { label: "Active",   value: orgs.filter((o) => o.is_active).length,  color: "text-green-600" },
          { label: "Inactive", value: orgs.filter((o) => !o.is_active).length, color: "text-amber-600" },
          { label: "Avg Tax",  value: orgs.length ? `${(orgs.reduce((s, o) => s + o.tax_rate, 0) / orgs.length).toFixed(1)}%` : "—", color: "text-muted-foreground" },
        ].map(({ label, value, color }) => (
          <Card key={label} className="p-4">
            <p className={`text-2xl font-extrabold ${color}`}>{isLoading ? "—" : value}</p>
            <p className="text-xs text-muted-foreground mt-1">{label}</p>
          </Card>
        ))}
      </div>

      <DataTable
        columns={columns}
        data={orgs}
        isLoading={isLoading}
        searchKey="name"
        searchPlaceholder="Search organizations…"
        emptyState={
          <div className="flex flex-col items-center gap-2 py-4">
            <Building2 size={32} className="text-muted-foreground/40" />
            <p>No organizations yet</p>
            <Button size="sm" onClick={() => setDialogOpen(true)}><Plus size={13} /> Create one</Button>
          </div>
        }
      />

      <OrgDialog open={dialogOpen} onClose={() => setDialogOpen(false)} />
    </PageShell>
  );
}
