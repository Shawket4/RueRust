import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useParams, useNavigate } from "react-router-dom";
import { toast } from "sonner";
import { Shield, Check, X, ChevronRight } from "lucide-react";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import * as permissionsApi from "@/api/permissions";
import * as usersApi from "@/api/users";
import type { UserPublic, PermissionMatrix } from "@/types";
import { fmtRole, ROLE_COLORS } from "@/utils/format";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { ScrollArea } from "@/components/ui/scroll-area";
import { PageHeader } from "@/components/shared/PageHeader";
import { EmptyState } from "@/components/shared/EmptyState";
import { getErrorMessage } from "@/lib/client";
import { cn } from "@/lib/utils";

const RESOURCES = [
  "orders","shifts","branches","users","menu_items","categories","addon_items",
  "inventory","recipes","permissions","shift_counts",
];

const ACTIONS = ["read","create","update","delete"];

export default function Permissions() {
  const { userId } = useParams<{ userId?: string }>();
  const navigate   = useNavigate();
  const authUser   = useAuthStore((s) => s.user);
  const orgId      = useAppStore((s) => s.selectedOrgId) ?? authUser?.org_id ?? "";
  const qc         = useQueryClient();
  const [selUser, setSelUser] = useState<string | null>(userId ?? null);

  const { data: users = [], isLoading: usersLoading } = useQuery({
    queryKey: ["users", orgId],
    queryFn:  () => usersApi.getUsers(orgId).then((r) => r.data),
    enabled:  !!orgId,
  });

  const { data: matrix = [], isLoading: matrixLoading } = useQuery({
    queryKey: ["permissions-matrix", selUser],
    queryFn:  () => permissionsApi.getMatrix(selUser!).then((r) => r.data),
    enabled:  !!selUser,
  });

  const upsertMutation = useMutation({
    mutationFn: (data: { resource: string; action: string; granted: boolean }) =>
      permissionsApi.upsertPermission(selUser!, data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["permissions-matrix", selUser] }),
    onError:   (e) => toast.error(getErrorMessage(e)),
  });

  const deleteMutation = useMutation({
    mutationFn: ({ resource, action }: { resource: string; action: string }) =>
      permissionsApi.deletePermission(selUser!, resource, action),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["permissions-matrix", selUser] }),
    onError:   (e) => toast.error(getErrorMessage(e)),
  });

  const getCell = (resource: string, action: string): PermissionMatrix | undefined =>
    matrix.find((m) => m.resource === resource && m.action === action);

  const handleToggle = (resource: string, action: string, cell: PermissionMatrix | undefined) => {
    if (!cell) return;
    if (cell.user_override !== null) {
      // Remove override → revert to role default
      deleteMutation.mutate({ resource, action });
    } else {
      // Set override opposite to role default
      upsertMutation.mutate({ resource, action, granted: !cell.role_default });
    }
  };

  const selectedUser = users.find((u) => u.id === selUser);

  return (
    <div className="p-6 lg:p-8 max-w-7xl mx-auto">
      <PageHeader title="Permissions" sub="Manage per-user access overrides" />

      <div className="grid grid-cols-1 lg:grid-cols-[280px_1fr] gap-4">
        {/* User list */}
        <div className="rounded-2xl border overflow-hidden">
          <div className="p-3 border-b bg-muted/30">
            <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Select User</p>
          </div>
          <ScrollArea className="h-[600px]">
            {usersLoading
              ? <div className="p-3 space-y-2">{Array.from({length:5}).map((_,i)=><Skeleton key={i} className="h-12"/>)}</div>
              : users.filter((u) => u.id !== authUser?.id).map((u) => (
                  <button key={u.id} onClick={() => { setSelUser(u.id); navigate(`/permissions/${u.id}`); }}
                    className={cn(
                      "w-full text-left px-4 py-3 border-b border-border/50 hover:bg-muted/40 transition-colors flex items-center gap-3",
                      selUser === u.id && "bg-accent",
                    )}>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold truncate">{u.name}</p>
                      <p className={cn("text-[10px] font-semibold px-1.5 py-0.5 rounded-full border inline-block mt-0.5", ROLE_COLORS[u.role])}>
                        {fmtRole(u.role)}
                      </p>
                    </div>
                    {selUser === u.id && <ChevronRight size={14} className="text-primary flex-shrink-0" />}
                  </button>
                ))
            }
          </ScrollArea>
        </div>

        {/* Permission matrix */}
        <div className="rounded-2xl border overflow-hidden">
          {!selUser ? (
            <EmptyState icon={Shield} title="Select a user" sub="Choose a user to view and manage their permissions" className="h-[600px]" />
          ) : (
            <>
              <div className="p-4 border-b bg-muted/30 flex items-center justify-between">
                <div>
                  <p className="font-bold">{selectedUser?.name}</p>
                  <p className="text-xs text-muted-foreground">Overrides applied on top of role defaults</p>
                </div>
                {selectedUser && (
                  <Badge className={ROLE_COLORS[selectedUser.role]}>{fmtRole(selectedUser.role)}</Badge>
                )}
              </div>

              <ScrollArea className="h-[560px]">
                {matrixLoading ? (
                  <div className="p-4 space-y-2">{Array.from({length:8}).map((_,i)=><Skeleton key={i} className="h-10"/>)}</div>
                ) : (
                  <table className="w-full text-sm">
                    <thead className="sticky top-0 bg-background border-b z-10">
                      <tr>
                        <th className="text-left px-4 py-2.5 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Resource</th>
                        {ACTIONS.map((a) => (
                          <th key={a} className="text-center px-3 py-2.5 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{a}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {RESOURCES.map((resource) => (
                        <tr key={resource} className="border-b border-border/50 hover:bg-muted/30 transition-colors">
                          <td className="px-4 py-3 font-medium text-sm capitalize">{resource.replace("_"," ")}</td>
                          {ACTIONS.map((action) => {
                            const cell = getCell(resource, action);
                            if (!cell) return (
                              <td key={action} className="px-3 py-3 text-center">
                                <span className="text-muted-foreground">—</span>
                              </td>
                            );
                            const hasOverride = cell.user_override !== null;
                            const effective   = cell.effective;
                            return (
                              <td key={action} className="px-3 py-3 text-center">
                                <div className="flex flex-col items-center gap-1">
                                  <button
                                    onClick={() => handleToggle(resource, action, cell)}
                                    className={cn(
                                      "w-7 h-7 rounded-lg flex items-center justify-center transition-all border",
                                      hasOverride
                                        ? effective
                                          ? "bg-primary text-primary-foreground border-primary"
                                          : "bg-destructive/10 text-destructive border-destructive/30"
                                        : effective
                                          ? "bg-muted text-muted-foreground border-border"
                                          : "bg-muted text-muted-foreground/40 border-border",
                                    )}
                                    title={`${hasOverride ? "Override: " : "Default: "}${effective ? "Granted" : "Denied"}`}
                                  >
                                    {effective ? <Check size={12} /> : <X size={12} />}
                                  </button>
                                  {hasOverride && (
                                    <span className="text-[9px] font-bold text-primary uppercase">override</span>
                                  )}
                                </div>
                              </td>
                            );
                          })}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </ScrollArea>

              <div className="p-3 border-t bg-muted/20 flex items-center gap-4 text-xs text-muted-foreground">
                <div className="flex items-center gap-1.5"><div className="w-4 h-4 rounded bg-primary/20 border border-primary/30" /> Override granted</div>
                <div className="flex items-center gap-1.5"><div className="w-4 h-4 rounded bg-destructive/10 border border-destructive/30" /> Override denied</div>
                <div className="flex items-center gap-1.5"><div className="w-4 h-4 rounded bg-muted border border-border" /> Role default</div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
