import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { type ColumnDef } from "@tanstack/react-table";
import {
  Plus,
  Users as UsersIcon,
  Edit2,
  Trash2,
  GitBranch,
  CheckCircle,
  XCircle,
  Shield,
} from "lucide-react";
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
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  getUsers,
  createUser,
  updateUser,
  deleteUser,
  getUserBranches,
  assignBranch,
  unassignBranch,
} from "@/api/users";
import { getBranches } from "@/api/branches";
import { getOrgs } from "@/api/orgs";
import { getErrorMessage } from "@/lib/client";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import {
  fmtRole,
  ROLE_COLORS,
  ROLE_LABELS,
  initials,
  fmtDateTime,
} from "@/utils/format";
import type { UserPublic, UserRole } from "@/types";

const ROLES: UserRole[] = ["org_admin", "branch_manager", "teller"];
const SUPER_ROLES: UserRole[] = ["super_admin", ...ROLES];

// ── Create / Edit User Dialog ─────────────────────────────────────────────────
function UserFormDialog({
  open,
  onClose,
  editUser,
}: {
  open: boolean;
  onClose: () => void;
  editUser?: UserPublic | null;
}) {
  const qc = useQueryClient();
  const authUser = useAuthStore((s) => s.user);
  const isSA = authUser?.role === "super_admin";

  const [name, setName] = useState(editUser?.name ?? "");
  const [email, setEmail] = useState(editUser?.email ?? "");
  const [phone, setPhone] = useState(editUser?.phone ?? "");
  const [pin, setPin] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState<UserRole>(editUser?.role ?? "teller");
  const [orgId, setOrgId] = useState(
    editUser?.org_id ?? authUser?.org_id ?? "",
  );
  const [isActive, setIsActive] = useState(editUser?.is_active ?? true);

  const { data: orgs = [] } = useQuery({
    queryKey: ["orgs"],
    queryFn: () => getOrgs().then((r) => r.data),
    enabled: isSA,
  });

  React.useEffect(() => {
    if (editUser) {
      setName(editUser.name);
      setEmail(editUser.email ?? "");
      setPhone(editUser.phone ?? "");
      setRole(editUser.role);
      setOrgId(editUser.org_id ?? authUser?.org_id ?? "");
      setIsActive(editUser.is_active);
    } else {
      setName("");
      setEmail("");
      setPhone("");
      setPin("");
      setPassword("");
      setRole("teller");
      setOrgId(authUser?.org_id ?? "");
      setIsActive(true);
    }
  }, [editUser, open]);

  const { mutate, isPending } = useMutation({
    mutationFn: async (): Promise<UserPublic> => {
      const payload: Record<string, unknown> = {
        name,
        phone,
        role,
        is_active: isActive,
      };
      if (email) payload.email = email;
      if (!editUser) {
        payload.org_id = orgId;
        if (pin) payload.pin = pin;
        if (password) payload.password = password;
      }
      if (editUser) {
        const res = await updateUser(editUser.id, payload);
        return res.data;
      }
      const res = await createUser(payload);
      return res.data.user;
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
            {editUser
              ? "Update user details and role."
              : "Create a new staff account."}
          </DialogDescription>
        </DialogHeader>
        <div className="px-6 py-4 space-y-4">
          <div className="space-y-2">
            <Label>Full Name</Label>
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ahmed Hassan"
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-2">
              <Label>Email</Label>
              <Input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="ahmed@theruecoffee.com"
              />
            </div>
            <div className="space-y-2">
              <Label>Phone</Label>
              <Input
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+20 10 xxxx xxxx"
              />
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
                  onChange={(e) =>
                    setPin(e.target.value.replace(/\D/g, "").slice(0, 4))
                  }
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
              <Select
                value={role}
                onValueChange={(v) => setRole(v as UserRole)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {roles.map((r) => (
                    <SelectItem key={r} value={r}>
                      {ROLE_LABELS[r]}
                    </SelectItem>
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
                      <SelectItem key={o.id} value={o.id}>
                        {o.name}
                      </SelectItem>
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
                <p className="text-xs text-muted-foreground">
                  Inactive users cannot log in
                </p>
              </div>
              <Switch checked={isActive} onCheckedChange={setIsActive} />
            </div>
          )}
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
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
  open,
  onClose,
  user,
}: {
  open: boolean;
  onClose: () => void;
  user: UserPublic | null;
}) {
  const qc = useQueryClient();
  const authUser = useAuthStore((s) => s.user);
  const orgId = user?.org_id ?? authUser?.org_id ?? "";

  const { data: branches = [] } = useQuery({
    queryKey: ["branches", orgId],
    queryFn: () => getBranches(orgId).then((r) => r.data),
    enabled: !!orgId,
  });

  const { data: assigned = [] } = useQuery({
    queryKey: ["user-branches", user?.id],
    queryFn: () => getUserBranches(user!.id).then((r) => r.data),
    enabled: !!user,
  });

  const assignedIds = new Set(assigned.map((a) => a.branch_id));

  const { mutate: toggle, isPending } = useMutation({
    mutationFn: ({
      branchId,
      isAssigned,
    }: {
      branchId: string;
      isAssigned: boolean;
    }) =>
      isAssigned
        ? unassignBranch(user!.id, branchId)
        : assignBranch(user!.id, branchId),
    onSuccess: () =>
      qc.invalidateQueries({ queryKey: ["user-branches", user?.id] }),
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Branch Access</DialogTitle>
          <DialogDescription>
            Toggle branch access for {user?.name}
          </DialogDescription>
        </DialogHeader>
        <div className="px-6 py-4 space-y-2">
          {branches.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-4">
              No branches in this org
            </p>
          ) : (
            branches.map((branch) => {
              const isAssigned = assignedIds.has(branch.id);
              return (
                <div
                  key={branch.id}
                  className="flex items-center justify-between rounded-xl p-3 border border-border hover:bg-muted/50 transition-colors"
                >
                  <div className="min-w-0">
                    <p className="text-sm font-medium truncate">
                      {branch.name}
                    </p>
                    {branch.address && (
                      <p className="text-xs text-muted-foreground truncate">
                        {branch.address}
                      </p>
                    )}
                  </div>
                  <Switch
                    checked={isAssigned}
                    disabled={isPending}
                    onCheckedChange={() =>
                      toggle({ branchId: branch.id, isAssigned })
                    }
                  />
                </div>
              );
            })
          )}
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
  const [formOpen, setFormOpen] = useState(false);
  const [branchOpen, setBranchOpen] = useState(false);
  const [editUser, setEditUser] = useState<UserPublic | null>(null);
  const [branchUser, setBranchUser] = useState<UserPublic | null>(null);
  const navigate = useNavigate();
  const qc = useQueryClient();
  const authUser = useAuthStore((s) => s.user);
  const orgId = useAppStore((s) => s.selectedOrgId) ?? authUser?.org_id ?? null;

  const { data: users = [], isLoading } = useQuery({
    queryKey: ["users", orgId],
    queryFn: () => getUsers(orgId).then((r) => r.data),
  });

  const { mutate: del } = useMutation({
    mutationFn: (id: string) => deleteUser(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["users"] });
      toast.success("User deleted");
    },
    onError: (e) => toast.error(getErrorMessage(e)),
  });

  const columns: ColumnDef<UserPublic>[] = [
    {
      accessorKey: "name",
      header: "User",
      cell: ({ row }) => (
        <div className="flex items-center gap-3">
          <Avatar className="h-8 w-8 flex-shrink-0">
            <AvatarFallback className="text-xs">
              {initials(row.original.name)}
            </AvatarFallback>
          </Avatar>
          <div className="min-w-0">
            <p className="font-semibold text-sm truncate">
              {row.original.name}
            </p>
            <p className="text-xs text-muted-foreground truncate">
              {row.original.email ?? "—"}
            </p>
          </div>
        </div>
      ),
    },
    {
      accessorKey: "phone",
      header: "Phone",
      cell: ({ getValue }) => (
        <span className="text-sm font-mono">
          {(getValue() as string) ?? "—"}
        </span>
      ),
    },
    {
      accessorKey: "role",
      header: "Role",
      cell: ({ getValue }) => (
        <span
          className={`text-[11px] font-bold px-2 py-1 rounded-full border ${ROLE_COLORS[getValue() as string] ?? ""}`}
        >
          {fmtRole(getValue() as string)}
        </span>
      ),
    },
    {
      accessorKey: "is_active",
      header: "Status",
      cell: ({ getValue }) =>
        getValue() ? (
          <Badge variant="success">
            <CheckCircle size={11} /> Active
          </Badge>
        ) : (
          <Badge variant="destructive">
            <XCircle size={11} /> Inactive
          </Badge>
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
            onClick={() => {
              navigate(`/permissions/${row.original.id}`);
            }}
          >
            <Shield size={13} />
          </Button>
          {(row.original.role === "branch_manager" ||
            row.original.role === "teller") && (
            <Button
              variant="ghost"
              size="icon-sm"
              onClick={() => {
                setBranchUser(row.original);
                setBranchOpen(true);
              }}
            >
              <GitBranch size={13} />
            </Button>
          )}
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => {
              setEditUser(row.original);
              setFormOpen(true);
            }}
          >
            <Edit2 size={13} />
          </Button>
          <Button
            variant="ghost"
            size="icon-sm"
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
        <Button
          onClick={() => {
            setEditUser(null);
            setFormOpen(true);
          }}
        >
          <Plus size={15} /> New User
        </Button>
      }
    >
      {/* Summary */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {[
          { label: "Total Users", value: users.length, color: "text-primary" },
          {
            label: "Org Admins",
            value: roleCount("org_admin"),
            color: "text-violet-600",
          },
          {
            label: "Branch Managers",
            value: roleCount("branch_manager"),
            color: "text-blue-600",
          },
          {
            label: "Tellers",
            value: roleCount("teller"),
            color: "text-green-600",
          },
        ].map(({ label, value, color }) => (
          <Card key={label} className="p-4">
            <p className={`text-2xl font-extrabold ${color}`}>
              {isLoading ? "—" : value}
            </p>
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
            <Button size="sm" onClick={() => setFormOpen(true)}>
              <Plus size={13} /> Add user
            </Button>
          </div>
        }
      />

      <UserFormDialog
        open={formOpen}
        onClose={() => {
          setFormOpen(false);
          setEditUser(null);
        }}
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
