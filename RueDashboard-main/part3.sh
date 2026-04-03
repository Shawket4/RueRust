#!/usr/bin/env bash
# =============================================================================
#  Rue POS Dashboard — Frontend Rewrite Part 3: Management Pages
#  Run from the React project root AFTER part1.sh + part2.sh
#
#  Creates:
#   - src/pages/orgs/Orgs.tsx
#   - src/pages/users/Users.tsx
#   - src/pages/branches/Branches.tsx
#   - src/pages/permissions/Permissions.tsx
#   - src/components/ui/data-table.tsx   (reusable TanStack Table wrapper)
#   - src/components/ui/page-shell.tsx   (reusable page header + container)
# =============================================================================
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; RESET='\033[0m'
log() { echo -e "${CYAN}[part3]${RESET} $*"; }
ok()  { echo -e "${GREEN}[done] ${RESET} $*"; }

if [[ ! -f "package.json" ]]; then
  echo "ERROR: Run from the React project root."; exit 1
fi

mkdir -p src/pages/{orgs,users,branches,permissions} src/components/ui

# ===========================================================================
#  src/components/ui/page-shell.tsx  — reusable page header + container
# ===========================================================================
log "Writing shared components ..."
cat > src/components/ui/page-shell.tsx << 'TSX'
import React from "react";
import { cn } from "@/lib/utils";

interface PageShellProps {
  title:       string;
  description?: string;
  action?:     React.ReactNode;
  children:    React.ReactNode;
  className?:  string;
}

export function PageShell({ title, description, action, children, className }: PageShellProps) {
  return (
    <div className={cn("p-4 sm:p-6 lg:p-8 max-w-[1400px] mx-auto space-y-5 animate-fade-in", className)}>
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div className="min-w-0">
          <h1 className="text-xl sm:text-2xl font-extrabold tracking-tight">{title}</h1>
          {description && (
            <p className="text-muted-foreground text-sm mt-1">{description}</p>
          )}
        </div>
        {action && <div className="flex-shrink-0">{action}</div>}
      </div>
      {children}
    </div>
  );
}

export function Card({ children, className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn("bg-card rounded-2xl border border-border shadow-sm", className)}
      {...props}
    >
      {children}
    </div>
  );
}
TSX

# ===========================================================================
#  src/components/ui/data-table.tsx  — TanStack Table wrapper
# ===========================================================================
cat > src/components/ui/data-table.tsx << 'TSX'
import React, { useState } from "react";
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
  type VisibilityState,
} from "@tanstack/react-table";
import { ChevronUp, ChevronDown, ChevronsUpDown, ChevronLeft, ChevronRight, Search } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";

interface DataTableProps<TData, TValue> {
  columns:      ColumnDef<TData, TValue>[];
  data:         TData[];
  isLoading?:   boolean;
  searchKey?:   string;
  searchPlaceholder?: string;
  pageSize?:    number;
  toolbar?:     React.ReactNode;
  emptyState?:  React.ReactNode;
  onRowClick?:  (row: TData) => void;
}

export function DataTable<TData, TValue>({
  columns,
  data,
  isLoading,
  searchKey,
  searchPlaceholder = "Search…",
  pageSize = 20,
  toolbar,
  emptyState,
  onRowClick,
}: DataTableProps<TData, TValue>) {
  const [sorting,         setSorting]         = useState<SortingState>([]);
  const [columnFilters,   setColumnFilters]   = useState<ColumnFiltersState>([]);
  const [columnVisibility,setColumnVisibility]= useState<VisibilityState>({});
  const [globalFilter,    setGlobalFilter]    = useState("");

  const table = useReactTable({
    data,
    columns,
    onSortingChange:         setSorting,
    onColumnFiltersChange:   setColumnFilters,
    onColumnVisibilityChange:setColumnVisibility,
    getCoreRowModel:         getCoreRowModel(),
    getSortedRowModel:       getSortedRowModel(),
    getFilteredRowModel:     getFilteredRowModel(),
    getPaginationRowModel:   getPaginationRowModel(),
    state:                   { sorting, columnFilters, columnVisibility, globalFilter },
    onGlobalFilterChange:    setGlobalFilter,
    initialState:            { pagination: { pageSize } },
  });

  return (
    <div className="space-y-3">
      {/* Toolbar */}
      {(searchKey || toolbar) && (
        <div className="flex items-center gap-3 flex-wrap">
          {searchKey && (
            <div className="relative flex-1 min-w-[200px] max-w-xs">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder={searchPlaceholder}
                value={(table.getColumn(searchKey)?.getFilterValue() as string) ?? ""}
                onChange={(e) => table.getColumn(searchKey)?.setFilterValue(e.target.value)}
                className="pl-9 h-9"
              />
            </div>
          )}
          {toolbar}
        </div>
      )}

      {/* Table */}
      <div className="rounded-2xl border border-border overflow-hidden bg-card">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              {table.getHeaderGroups().map((hg) => (
                <tr key={hg.id} className="border-b border-border bg-muted/50">
                  {hg.headers.map((header) => (
                    <th
                      key={header.id}
                      className={cn(
                        "px-4 py-3 text-left text-xs font-bold text-muted-foreground uppercase tracking-wide whitespace-nowrap",
                        header.column.getCanSort() && "cursor-pointer select-none hover:text-foreground",
                      )}
                      onClick={header.column.getToggleSortingHandler()}
                    >
                      {header.isPlaceholder ? null : (
                        <div className="flex items-center gap-1.5">
                          {flexRender(header.column.columnDef.header, header.getContext())}
                          {header.column.getCanSort() && (
                            <span className="text-muted-foreground">
                              {header.column.getIsSorted() === "asc"  ? <ChevronUp size={12} />   :
                               header.column.getIsSorted() === "desc" ? <ChevronDown size={12} /> :
                               <ChevronsUpDown size={12} />}
                            </span>
                          )}
                        </div>
                      )}
                    </th>
                  ))}
                </tr>
              ))}
            </thead>
            <tbody>
              {isLoading ? (
                Array.from({ length: 6 }).map((_, i) => (
                  <tr key={i} className="border-b border-border last:border-0">
                    {columns.map((_, j) => (
                      <td key={j} className="px-4 py-3">
                        <Skeleton className="h-4 w-full" />
                      </td>
                    ))}
                  </tr>
                ))
              ) : table.getRowModel().rows.length === 0 ? (
                <tr>
                  <td colSpan={columns.length} className="px-4 py-16 text-center text-muted-foreground text-sm">
                    {emptyState ?? "No results found."}
                  </td>
                </tr>
              ) : (
                table.getRowModel().rows.map((row) => (
                  <tr
                    key={row.id}
                    className={cn(
                      "border-b border-border last:border-0 transition-colors",
                      onRowClick
                        ? "cursor-pointer hover:bg-muted/50"
                        : "hover:bg-muted/30",
                    )}
                    onClick={() => onRowClick?.(row.original)}
                  >
                    {row.getVisibleCells().map((cell) => (
                      <td key={cell.id} className="px-4 py-3 whitespace-nowrap">
                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                      </td>
                    ))}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {table.getPageCount() > 1 && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-border bg-muted/30">
            <p className="text-xs text-muted-foreground">
              {table.getFilteredRowModel().rows.length} row{table.getFilteredRowModel().rows.length !== 1 ? "s" : ""}
              {" · "}Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}
            </p>
            <div className="flex items-center gap-1">
              <Button
                variant="outline"
                size="icon-sm"
                onClick={() => table.previousPage()}
                disabled={!table.getCanPreviousPage()}
              >
                <ChevronLeft size={14} />
              </Button>
              <Button
                variant="outline"
                size="icon-sm"
                onClick={() => table.nextPage()}
                disabled={!table.getCanNextPage()}
              >
                <ChevronRight size={14} />
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
TSX
ok "Shared components"

# ===========================================================================
#  src/pages/orgs/Orgs.tsx
# ===========================================================================
log "Writing Orgs page ..."
cat > src/pages/orgs/Orgs.tsx << 'TSX'
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
TSX
ok "Orgs page"

# ===========================================================================
#  src/pages/users/Users.tsx
# ===========================================================================
log "Writing Users page ..."
cat > src/pages/users/Users.tsx << 'TSX'
import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { type ColumnDef } from "@tanstack/react-table";
import { Plus, Users as UsersIcon, Edit2, Trash2, GitBranch, CheckCircle, XCircle, Shield } from "lucide-react";
import { toast } from "sonner";
import { useNavigate } from "react-router-dom";
import { PageShell, Card } from "@/components/ui/page-shell";
import { DataTable } from "@/components/ui/data-table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Separator } from "@/components/ui/separator";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle,
  DialogFooter, DialogDescription,
} from "@/components/ui/dialog";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem,
  DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { getUsers, createUser, updateUser, deleteUser, getUserBranches, assignBranch, unassignBranch } from "@/api/users";
import { getBranches } from "@/api/branches";
import { getOrgs } from "@/api/orgs";
import { getErrorMessage } from "@/lib/client";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import { fmtRole, ROLE_COLORS, ROLE_LABELS, initials, fmtDateTime } from "@/utils/format";
import type { UserPublic, UserRole } from "@/types";

const ROLES: UserRole[] = ["org_admin", "branch_manager", "teller"];
const SUPER_ROLES: UserRole[] = ["super_admin", ...ROLES];

// ── Create / Edit User Dialog ─────────────────────────────────────────────────
function UserFormDialog({
  open, onClose, editUser,
}: {
  open:      boolean;
  onClose:   () => void;
  editUser?: UserPublic | null;
}) {
  const qc        = useQueryClient();
  const authUser  = useAuthStore((s) => s.user);
  const isSA      = authUser?.role === "super_admin";

  const [name,     setName]     = useState(editUser?.name     ?? "");
  const [email,    setEmail]    = useState(editUser?.email    ?? "");
  const [phone,    setPhone]    = useState(editUser?.phone    ?? "");
  const [pin,      setPin]      = useState("");
  const [password, setPassword] = useState("");
  const [role,     setRole]     = useState<UserRole>(editUser?.role ?? "teller");
  const [orgId,    setOrgId]    = useState(editUser?.org_id ?? authUser?.org_id ?? "");
  const [isActive, setIsActive] = useState(editUser?.is_active ?? true);

  const { data: orgs = [] } = useQuery({
    queryKey: ["orgs"],
    queryFn:  () => getOrgs().then((r) => r.data),
    enabled:  isSA,
  });

  React.useEffect(() => {
    if (editUser) {
      setName(editUser.name); setEmail(editUser.email ?? "");
      setPhone(editUser.phone ?? ""); setRole(editUser.role);
      setOrgId(editUser.org_id ?? authUser?.org_id ?? "");
      setIsActive(editUser.is_active);
    } else {
      setName(""); setEmail(""); setPhone(""); setPin(""); setPassword("");
      setRole("teller"); setOrgId(authUser?.org_id ?? ""); setIsActive(true);
    }
  }, [editUser, open]);

  const { mutate, isPending } = useMutation({
    mutationFn: () => {
      const payload: Record<string, unknown> = { name, phone, role, is_active: isActive };
      if (email)    payload.email    = email;
      if (!editUser) {
        payload.org_id = orgId;
        if (pin)      payload.pin      = pin;
        if (password) payload.password = password;
      }
      return editUser
        ? updateUser(editUser.id, payload)
        : createUser(payload);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["users"] });
      toast.success(editUser ? "User updated" : "User created");
      onClose();
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const roles = isSA ? SUPER_ROLES : ROLES;

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{editUser ? "Edit User" : "New User"}</DialogTitle>
          <DialogDescription>
            {editUser ? "Update user details and role." : "Create a new staff account."}
          </DialogDescription>
        </DialogHeader>
        <div className="px-6 py-4 space-y-4">
          <div className="space-y-2">
            <Label>Full Name</Label>
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Ahmed Hassan" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label>Email</Label>
              <Input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="ahmed@theruecoffe.com" />
            </div>
            <div className="space-y-2">
              <Label>Phone</Label>
              <Input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+20 10 xxxx xxxx" />
            </div>
          </div>

          {!editUser && (
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>PIN (4 digits)</Label>
                <Input
                  type="password"
                  inputMode="numeric"
                  maxLength={4}
                  value={pin}
                  onChange={(e) => setPin(e.target.value.replace(/\D/g, "").slice(0, 4))}
                  placeholder="••••"
                />
              </div>
              <div className="space-y-2">
                <Label>Password</Label>
                <Input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Optional"
                />
              </div>
            </div>
          )}

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label>Role</Label>
              <Select value={role} onValueChange={(v) => setRole(v as UserRole)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {roles.map((r) => (
                    <SelectItem key={r} value={r}>{ROLE_LABELS[r]}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            {isSA && !editUser && (
              <div className="space-y-2">
                <Label>Organization</Label>
                <Select value={orgId} onValueChange={setOrgId}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select org" />
                  </SelectTrigger>
                  <SelectContent>
                    {orgs.map((o) => (
                      <SelectItem key={o.id} value={o.id}>{o.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            )}
          </div>

          {editUser && (
            <div className="flex items-center justify-between rounded-xl bg-muted p-3">
              <div>
                <p className="text-sm font-medium">Active Account</p>
                <p className="text-xs text-muted-foreground">Inactive users cannot log in</p>
              </div>
              <Switch checked={isActive} onCheckedChange={setIsActive} />
            </div>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          <Button loading={isPending} onClick={() => mutate()} disabled={!name}>
            {editUser ? "Save Changes" : "Create User"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ── Branch Assignment Dialog ──────────────────────────────────────────────────
function BranchAssignDialog({
  open, onClose, user,
}: { open: boolean; onClose: () => void; user: UserPublic | null }) {
  const qc     = useQueryClient();
  const authUser = useAuthStore((s) => s.user);
  const orgId  = user?.org_id ?? authUser?.org_id ?? "";

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn:  () => getBranches(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const { data: assigned = [] } = useQuery({
    queryKey: ["user-branches", user?.id],
    queryFn:  () => getUserBranches(user!.id).then((r) => r.data),
    enabled:  !!user,
  });

  const assignedIds = new Set(assigned.map((a) => a.branch_id));

  const { mutate: toggle, isPending } = useMutation({
    mutationFn: ({ branchId, isAssigned }: { branchId: string; isAssigned: boolean }) =>
      isAssigned
        ? unassignBranch(user!.id, branchId)
        : assignBranch(user!.id, branchId),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["user-branches", user?.id] }),
    onError:   (e) => toast.error(getErrorMessage(e)),
  });

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Branch Access</DialogTitle>
          <DialogDescription>Toggle branch access for {user?.name}</DialogDescription>
        </DialogHeader>
        <div className="px-6 py-4 space-y-2">
          {branches.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-4">No branches in this org</p>
          ) : branches.map((branch) => {
            const isAssigned = assignedIds.has(branch.id);
            return (
              <div
                key={branch.id}
                className="flex items-center justify-between rounded-xl p-3 border border-border hover:bg-muted/50 transition-colors"
              >
                <div className="min-w-0">
                  <p className="text-sm font-medium truncate">{branch.name}</p>
                  {branch.address && (
                    <p className="text-xs text-muted-foreground truncate">{branch.address}</p>
                  )}
                </div>
                <Switch
                  checked={isAssigned}
                  disabled={isPending}
                  onCheckedChange={() => toggle({ branchId: branch.id, isAssigned })}
                />
              </div>
            );
          })}
        </div>
        <DialogFooter>
          <Button onClick={onClose}>Done</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ── Main Users page ───────────────────────────────────────────────────────────
export default function Users() {
  const [formOpen,     setFormOpen]     = useState(false);
  const [branchOpen,   setBranchOpen]   = useState(false);
  const [editUser,     setEditUser]     = useState<UserPublic | null>(null);
  const [branchUser,   setBranchUser]   = useState<UserPublic | null>(null);
  const navigate   = useNavigate();
  const qc         = useQueryClient();
  const authUser   = useAuthStore((s) => s.user);
  const orgId      = useAppStore((s) => s.selectedOrgId) ?? authUser?.org_id ?? null;

  const { data: users = [], isLoading } = useQuery({
    queryKey: ["users", orgId],
    queryFn:  () => getUsers(orgId).then((r) => r.data),
  });

  const { mutate: del } = useMutation({
    mutationFn: (id: string) => deleteUser(id),
    onSuccess:  () => { qc.invalidateQueries({ queryKey: ["users"] }); toast.success("User deleted"); },
    onError:    (e) => toast.error(getErrorMessage(e)),
  });

  const columns: ColumnDef<UserPublic>[] = [
    {
      accessorKey: "name",
      header:      "User",
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <Avatar className="h-8 w-8 flex-shrink-0">
            <AvatarFallback className="text-xs">{initials(row.original.name)}</AvatarFallback>
          </Avatar>
          <div className="min-w-0">
            <p className="font-semibold text-sm truncate">{row.original.name}</p>
            <p className="text-xs text-muted-foreground truncate">{row.original.email ?? "—"}</p>
          </div>
        </div>
      ),
    },
    {
      accessorKey: "phone",
      header:      "Phone",
      cell: ({ getValue }) => (
        <span className="text-sm font-mono">{getValue() as string ?? "—"}</span>
      ),
    },
    {
      accessorKey: "role",
      header:      "Role",
      cell: ({ getValue }) => (
        <span className={`text-[11px] font-bold px-2 py-1 rounded-full border ${ROLE_COLORS[getValue() as string] ?? ""}`}>
          {fmtRole(getValue() as string)}
        </span>
      ),
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
            onClick={() => { navigate(`/permissions/${row.original.id}`); }}
          >
            <Shield size={13} />
          </Button>
          {(row.original.role === "branch_manager" || row.original.role === "teller") && (
            <Button
              variant="ghost" size="icon-sm"
              onClick={() => { setBranchUser(row.original); setBranchOpen(true); }}
            >
              <GitBranch size={13} />
            </Button>
          )}
          <Button
            variant="ghost" size="icon-sm"
            onClick={() => { setEditUser(row.original); setFormOpen(true); }}
          >
            <Edit2 size={13} />
          </Button>
          <Button
            variant="ghost" size="icon-sm"
            className="text-destructive hover:text-destructive"
            onClick={() => {
              if (confirm(`Delete ${row.original.name}?`)) del(row.original.id);
            }}
          >
            <Trash2 size={13} />
          </Button>
        </div>
      ),
    },
  ];

  const roleCount = (r: string) => users.filter((u) => u.role === r).length;

  return (
    <PageShell
      title="Users"
      description="Manage staff accounts and access"
      action={
        <Button onClick={() => { setEditUser(null); setFormOpen(true); }}>
          <Plus size={15} /> New User
        </Button>
      }
    >
      {/* Summary */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[
          { label: "Total Users",      value: users.length,                             color: "text-primary"   },
          { label: "Org Admins",       value: roleCount("org_admin"),                   color: "text-violet-600" },
          { label: "Branch Managers",  value: roleCount("branch_manager"),              color: "text-blue-600"  },
          { label: "Tellers",          value: roleCount("teller"),                      color: "text-green-600" },
        ].map(({ label, value, color }) => (
          <Card key={label} className="p-4">
            <p className={`text-2xl font-extrabold ${color}`}>{isLoading ? "—" : value}</p>
            <p className="text-xs text-muted-foreground mt-1">{label}</p>
          </Card>
        ))}
      </div>

      <DataTable
        columns={columns}
        data={users}
        isLoading={isLoading}
        searchKey="name"
        searchPlaceholder="Search users…"
        toolbar={
          <p className="text-xs text-muted-foreground ml-auto hidden sm:block">
            Click <Shield size={10} className="inline" /> to manage permissions
          </p>
        }
        emptyState={
          <div className="flex flex-col items-center gap-2 py-4">
            <UsersIcon size={32} className="text-muted-foreground/40" />
            <p>No users found</p>
            <Button size="sm" onClick={() => setFormOpen(true)}><Plus size={13} /> Add user</Button>
          </div>
        }
      />

      <UserFormDialog
        open={formOpen}
        onClose={() => { setFormOpen(false); setEditUser(null); }}
        editUser={editUser}
      />
      <BranchAssignDialog
        open={branchOpen}
        onClose={() => setBranchOpen(false)}
        user={branchUser}
      />
    </PageShell>
  );
}
TSX
ok "Users page"

# ===========================================================================
#  src/pages/branches/Branches.tsx
# ===========================================================================
log "Writing Branches page ..."
cat > src/pages/branches/Branches.tsx << 'TSX'
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
TSX
ok "Branches page"

# ===========================================================================
#  src/pages/permissions/Permissions.tsx
# ===========================================================================
log "Writing Permissions page ..."
cat > src/pages/permissions/Permissions.tsx << 'TSX'
import React, { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Shield, CheckCircle2, XCircle, Minus, ChevronRight,
  Info, RotateCcw, Users, Search,
} from "lucide-react";
import { toast } from "sonner";
import { PageShell, Card } from "@/components/ui/page-shell";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Tooltip, TooltipContent, TooltipTrigger, TooltipProvider,
} from "@/components/ui/tooltip";
import {
  getMatrix, upsertPermission, deletePermission,
  getRolePermissions, upsertRolePermission,
} from "@/api/permissions";
import { getUsers, getUser } from "@/api/users";
import { getErrorMessage } from "@/lib/client";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import { fmtRole, ROLE_COLORS, initials } from "@/utils/format";
import type { PermissionMatrix, RolePermission, UserPublic } from "@/types";

// Resources and actions available in the system
const RESOURCES = [
  { resource: "orders",       label: "Orders",         actions: ["read","create","update","delete","void"] },
  { resource: "shifts",       label: "Shifts",         actions: ["read","create","update","delete","force_close"] },
  { resource: "inventory",    label: "Inventory",       actions: ["read","create","update","delete"] },
  { resource: "menu",         label: "Menu",           actions: ["read","create","update","delete"] },
  { resource: "categories",   label: "Categories",     actions: ["read","create","update","delete"] },
  { resource: "branches",     label: "Branches",       actions: ["read","create","update","delete"] },
  { resource: "users",        label: "Users",          actions: ["read","create","update","delete"] },
  { resource: "permissions",  label: "Permissions",    actions: ["read","create","update","delete"] },
  { resource: "reports",      label: "Reports",        actions: ["read"] },
  { resource: "shift_counts", label: "Shift Counts",   actions: ["read","create"] },
];

// ── Permission cell ───────────────────────────────────────────────────────────
interface CellProps {
  effective:     boolean | null;
  roleDefault:   boolean | null;
  userOverride:  boolean | null;
  onGrant:       () => void;
  onDeny:        () => void;
  onReset:       () => void;
  loading?:      boolean;
}

function PermCell({ effective, roleDefault, userOverride, onGrant, onDeny, onReset, loading }: CellProps) {
  const hasOverride = userOverride !== null;

  const icon = effective === true
    ? <CheckCircle2 size={14} className="text-green-600" />
    : effective === false
    ? <XCircle size={14} className="text-red-500" />
    : <Minus size={14} className="text-muted-foreground" />;

  return (
    <TooltipProvider delayDuration={0}>
      <Tooltip>
        <TooltipTrigger asChild>
          <div className="flex items-center justify-center gap-0.5 group">
            <button
              disabled={loading}
              onClick={() => {
                if      (effective === true  && !hasOverride) onDeny();
                else if (effective === false && !hasOverride) onGrant();
                else if (hasOverride)                         onReset();
                else if (effective === true)                  onDeny();
                else                                          onGrant();
              }}
              className={`
                flex items-center justify-center w-7 h-7 rounded-lg transition-all
                ${hasOverride
                  ? "ring-2 ring-offset-1 ring-primary/50 bg-primary/10"
                  : "hover:bg-muted"}
                disabled:opacity-50
              `}
            >
              {loading ? (
                <span className="w-3 h-3 border-2 border-current border-t-transparent rounded-full animate-spin" />
              ) : icon}
            </button>
          </div>
        </TooltipTrigger>
        <TooltipContent>
          <p className="font-semibold">{effective ? "Allowed" : "Denied"}</p>
          <p className="text-xs text-muted-foreground">
            Role default: {roleDefault === null ? "none" : roleDefault ? "allow" : "deny"}
          </p>
          {hasOverride && (
            <p className="text-xs text-primary font-medium">
              User override: {userOverride ? "allow" : "deny"} · Click to reset
            </p>
          )}
          {!hasOverride && (
            <p className="text-xs text-muted-foreground">Click to override</p>
          )}
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}

// ── User permissions matrix ───────────────────────────────────────────────────
function UserPermMatrix({ userId }: { userId: string }) {
  const qc = useQueryClient();
  const [loadingKey, setLoadingKey] = useState<string | null>(null);

  const { data: matrix = [], isLoading } = useQuery({
    queryKey: ["perm-matrix", userId],
    queryFn:  () => getMatrix(userId).then((r) => r.data),
  });

  const { data: user } = useQuery({
    queryKey: ["user", userId],
    queryFn:  () => getUser(userId).then((r) => r.data),
  });

  const matrixMap = new Map(
    matrix.map((m) => [`${m.resource}:${m.action}`, m]),
  );

  const grant = (resource: string, action: string) => {
    const key = `${resource}:${action}`;
    setLoadingKey(key);
    upsertPermission(userId, { resource, action, granted: true })
      .then(() => qc.invalidateQueries({ queryKey: ["perm-matrix", userId] }))
      .catch((e) => toast.error(getErrorMessage(e)))
      .finally(() => setLoadingKey(null));
  };

  const deny = (resource: string, action: string) => {
    const key = `${resource}:${action}`;
    setLoadingKey(key);
    upsertPermission(userId, { resource, action, granted: false })
      .then(() => qc.invalidateQueries({ queryKey: ["perm-matrix", userId] }))
      .catch((e) => toast.error(getErrorMessage(e)))
      .finally(() => setLoadingKey(null));
  };

  const reset = (resource: string, action: string) => {
    const key = `${resource}:${action}`;
    setLoadingKey(key);
    deletePermission(userId, resource, action)
      .then(() => qc.invalidateQueries({ queryKey: ["perm-matrix", userId] }))
      .catch((e) => toast.error(getErrorMessage(e)))
      .finally(() => setLoadingKey(null));
  };

  if (isLoading) {
    return (
      <div className="space-y-3">
        {Array.from({ length: 5 }).map((_, i) => (
          <Skeleton key={i} className="h-12 w-full" />
        ))}
      </div>
    );
  }

  // All unique actions across resources
  const allActions = ["read", "create", "update", "delete", "void", "force_close"];

  return (
    <div className="space-y-4">
      {/* User info */}
      {user && (
        <div className="flex items-center gap-3 p-4 rounded-2xl bg-muted/50 border border-border">
          <Avatar className="h-10 w-10">
            <AvatarFallback>{initials(user.name)}</AvatarFallback>
          </Avatar>
          <div className="min-w-0">
            <p className="font-bold truncate">{user.name}</p>
            <p className={`text-[11px] font-semibold px-2 py-0.5 rounded-full border inline-block mt-0.5 ${ROLE_COLORS[user.role] ?? ""}`}>
              {fmtRole(user.role)}
            </p>
          </div>
          <div className="ml-auto flex items-center gap-2 text-xs text-muted-foreground">
            <span className="w-2 h-2 rounded-full bg-green-500 ring-2 ring-green-200" /> Allowed
            <span className="w-2 h-2 rounded-full bg-red-500 ring-2 ring-red-200 ml-2" /> Denied
            <span className="w-2 h-2 rounded-full bg-muted-foreground ring-2 ring-muted ml-2" /> Default
          </div>
        </div>
      )}

      {/* Matrix */}
      <div className="rounded-2xl border border-border overflow-hidden bg-card">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/50">
                <th className="px-4 py-3 text-left text-xs font-bold text-muted-foreground uppercase tracking-wide sticky left-0 bg-muted/50 min-w-[140px]">
                  Resource
                </th>
                {allActions.map((a) => (
                  <th key={a} className="px-2 py-3 text-center text-xs font-bold text-muted-foreground uppercase tracking-wide">
                    {a.replace("_", " ")}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {RESOURCES.map(({ resource, label, actions }) => (
                <tr key={resource} className="border-b border-border last:border-0 hover:bg-muted/20 transition-colors">
                  <td className="px-4 py-3 sticky left-0 bg-card font-medium text-sm whitespace-nowrap">
                    {label}
                  </td>
                  {allActions.map((action) => {
                    const supported = actions.includes(action);
                    if (!supported) {
                      return <td key={action} className="px-2 py-3 text-center"><span className="text-muted-foreground/30 text-xs">—</span></td>;
                    }
                    const key  = `${resource}:${action}`;
                    const perm = matrixMap.get(key);
                    return (
                      <td key={action} className="px-2 py-3 text-center">
                        <PermCell
                          effective={perm?.effective ?? null}
                          roleDefault={perm?.role_default ?? null}
                          userOverride={perm?.user_override ?? null}
                          loading={loadingKey === key}
                          onGrant={() => grant(resource, action)}
                          onDeny={() => deny(resource, action)}
                          onReset={() => reset(resource, action)}
                        />
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <p className="text-xs text-muted-foreground flex items-center gap-1.5">
        <Info size={11} /> Highlighted cells have user-specific overrides. Click any cell to toggle, click an override to reset to role default.
      </p>
    </div>
  );
}

// ── Role permissions matrix ───────────────────────────────────────────────────
function RolePermMatrix() {
  const qc = useQueryClient();
  const [loadingKey, setLoadingKey] = useState<string | null>(null);

  const { data: rolePerms = [], isLoading } = useQuery({
    queryKey: ["role-permissions"],
    queryFn:  () => getRolePermissions().then((r) => r.data),
  });

  const roles = ["org_admin", "branch_manager", "teller"];
  const allActions = ["read", "create", "update", "delete", "void", "force_close"];

  const permMap = new Map(
    rolePerms.map((p) => [`${p.role}:${p.resource}:${p.action}`, p]),
  );

  const toggle = (role: string, resource: string, action: string, current: boolean) => {
    const key = `${role}:${resource}:${action}`;
    setLoadingKey(key);
    upsertRolePermission({ role, resource, action, granted: !current })
      .then(() => qc.invalidateQueries({ queryKey: ["role-permissions"] }))
      .catch((e) => toast.error(getErrorMessage(e)))
      .finally(() => setLoadingKey(null));
  };

  if (isLoading) {
    return <div className="space-y-3">{Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-10 w-full" />)}</div>;
  }

  return (
    <div className="space-y-4">
      <div className="rounded-2xl border border-border overflow-hidden bg-card">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-muted/50">
                <th className="px-4 py-3 text-left text-xs font-bold text-muted-foreground uppercase tracking-wide sticky left-0 bg-muted/50 min-w-[140px]">Resource</th>
                <th className="px-2 py-3 text-center text-xs font-bold text-muted-foreground uppercase tracking-wide min-w-[60px]">Action</th>
                {roles.map((r) => (
                  <th key={r} className="px-3 py-3 text-center text-xs font-bold text-muted-foreground uppercase tracking-wide">
                    <span className={`px-2 py-0.5 rounded-full border ${ROLE_COLORS[r] ?? ""}`}>
                      {fmtRole(r)}
                    </span>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {RESOURCES.flatMap(({ resource, label, actions }) =>
                actions.map((action, idx) => (
                  <tr key={`${resource}:${action}`} className="border-b border-border last:border-0 hover:bg-muted/20">
                    <td className="px-4 py-2.5 sticky left-0 bg-card font-medium text-sm whitespace-nowrap">
                      {idx === 0 ? label : ""}
                    </td>
                    <td className="px-2 py-2.5 text-center">
                      <Badge variant="outline" className="text-[10px]">{action.replace("_", " ")}</Badge>
                    </td>
                    {roles.map((role) => {
                      const key    = `${role}:${resource}:${action}`;
                      const perm   = permMap.get(key);
                      const granted = perm?.granted ?? false;
                      const loading = loadingKey === key;
                      return (
                        <td key={role} className="px-3 py-2.5 text-center">
                          <button
                            disabled={loading}
                            onClick={() => toggle(role, resource, action, granted)}
                            className={`w-7 h-7 rounded-lg flex items-center justify-center mx-auto transition-all hover:opacity-80 disabled:opacity-50 ${
                              granted ? "bg-green-100 dark:bg-green-950" : "bg-red-50 dark:bg-red-950"
                            }`}
                          >
                            {loading
                              ? <span className="w-3 h-3 border-2 border-current border-t-transparent rounded-full animate-spin" />
                              : granted
                              ? <CheckCircle2 size={14} className="text-green-600" />
                              : <XCircle size={14} className="text-red-500" />}
                          </button>
                        </td>
                      );
                    })}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
      <p className="text-xs text-muted-foreground flex items-center gap-1.5">
        <Info size={11} /> These are the default permissions for each role. User-specific overrides on the User tab take precedence.
      </p>
    </div>
  );
}

// ── User selector ─────────────────────────────────────────────────────────────
function UserSelector({ onSelect }: { onSelect: (id: string) => void }) {
  const authUser = useAuthStore((s) => s.user);
  const orgId    = authUser?.org_id ?? null;
  const [search, setSearch] = useState("");

  const { data: users = [], isLoading } = useQuery({
    queryKey: ["users", orgId],
    queryFn:  () => getUsers(orgId).then((r) => r.data),
  });

  const filtered = users.filter((u) =>
    u.name.toLowerCase().includes(search.toLowerCase()) ||
    (u.email ?? "").toLowerCase().includes(search.toLowerCase()),
  );

  return (
    <Card className="overflow-hidden">
      <div className="p-4 border-b border-border">
        <div className="relative">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search users…"
            className="pl-9"
          />
        </div>
      </div>
      <div className="divide-y divide-border max-h-[60vh] overflow-y-auto">
        {isLoading
          ? Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="flex items-center gap-3 p-4">
                <Skeleton className="h-9 w-9 rounded-full" />
                <div className="space-y-1.5 flex-1">
                  <Skeleton className="h-3.5 w-32" />
                  <Skeleton className="h-3 w-20" />
                </div>
              </div>
            ))
          : filtered.map((u) => (
              <button
                key={u.id}
                className="w-full flex items-center gap-3 p-4 hover:bg-muted/50 transition-colors text-left"
                onClick={() => onSelect(u.id)}
              >
                <Avatar className="h-9 w-9 flex-shrink-0">
                  <AvatarFallback className="text-xs">{initials(u.name)}</AvatarFallback>
                </Avatar>
                <div className="flex-1 min-w-0">
                  <p className="font-semibold text-sm truncate">{u.name}</p>
                  <p className="text-xs text-muted-foreground truncate">{u.email ?? u.phone ?? "—"}</p>
                </div>
                <div className="flex items-center gap-2 flex-shrink-0">
                  <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded-full border ${ROLE_COLORS[u.role] ?? ""}`}>
                    {fmtRole(u.role)}
                  </span>
                  <ChevronRight size={13} className="text-muted-foreground" />
                </div>
              </button>
            ))
        }
      </div>
    </Card>
  );
}

// ── Main Permissions page ─────────────────────────────────────────────────────
export default function Permissions() {
  const { userId } = useParams<{ userId?: string }>();
  const navigate   = useNavigate();
  const authUser   = useAuthStore((s) => s.user);
  const isSA       = authUser?.role === "super_admin";
  const isOA       = authUser?.role === "org_admin";

  if (!isSA && !isOA) {
    return (
      <PageShell title="Permissions" description="Access control">
        <Card className="p-8 text-center">
          <Shield size={32} className="text-muted-foreground/40 mx-auto mb-3" />
          <p className="text-muted-foreground">You don't have permission to manage permissions.</p>
        </Card>
      </PageShell>
    );
  }

  if (!userId || userId === "select") {
    return (
      <PageShell title="Permissions" description="Select a user to manage their permissions">
        <Tabs defaultValue="user">
          <TabsList className="mb-4">
            <TabsTrigger value="user"><Users size={13} /> User Permissions</TabsTrigger>
            <TabsTrigger value="role"><Shield size={13} /> Role Defaults</TabsTrigger>
          </TabsList>
          <TabsContent value="user">
            <UserSelector onSelect={(id) => navigate(`/permissions/${id}`)} />
          </TabsContent>
          <TabsContent value="role">
            <RolePermMatrix />
          </TabsContent>
        </Tabs>
      </PageShell>
    );
  }

  return (
    <PageShell
      title="User Permissions"
      description="Manage individual user access overrides"
      action={
        <Button variant="outline" onClick={() => navigate("/permissions/select")}>
          <Users size={14} /> All Users
        </Button>
      }
    >
      <Tabs defaultValue="user">
        <TabsList className="mb-4">
          <TabsTrigger value="user"><Users size={13} /> User Overrides</TabsTrigger>
          <TabsTrigger value="role"><Shield size={13} /> Role Defaults</TabsTrigger>
        </TabsList>
        <TabsContent value="user">
          <UserPermMatrix userId={userId} />
        </TabsContent>
        <TabsContent value="role">
          <RolePermMatrix />
        </TabsContent>
      </Tabs>
    </PageShell>
  );
}
TSX
ok "Permissions page"

# ===========================================================================
#  Done
# ===========================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}  Part 3 complete! Management pages ready.${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo "  Created:"
echo "    ✓ src/components/ui/data-table.tsx"
echo "      - TanStack Table v8 wrapper"
echo "      - Sorting, filtering, pagination"
echo "      - Loading skeletons, empty states"
echo "      - Global search + per-column filter"
echo ""
echo "    ✓ src/components/ui/page-shell.tsx"
echo "      - Reusable page header + container"
echo "      - Card component"
echo ""
echo "    ✓ src/pages/orgs/Orgs.tsx"
echo "      - Create org dialog"
echo "      - Summary stat cards"
echo "      - Full sortable table"
echo ""
echo "    ✓ src/pages/users/Users.tsx"
echo "      - Create/Edit user dialog"
echo "      - PIN + password + role assignment"
echo "      - Branch access toggle dialog"
echo "      - Permissions shortcut button"
echo "      - Role summary cards"
echo ""
echo "    ✓ src/pages/branches/Branches.tsx"
echo "      - Create/Edit branch dialog"
echo "      - Printer config (brand, IP, port)"
echo "      - Nullable printer (clears config)"
echo "      - Active toggle"
echo ""
echo "    ✓ src/pages/permissions/Permissions.tsx"
echo "      - User permission matrix (resource × action)"
echo "      - Role default matrix"
echo "      - Per-cell toggle with override indicator"
echo "      - User selector with search"
echo "      - Tooltips explaining effective vs override"
echo ""
echo "  Run: bash frontend_part4.sh  (Menu + Recipes)"
echo ""