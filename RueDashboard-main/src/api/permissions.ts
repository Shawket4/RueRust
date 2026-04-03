import client from "@/lib/client";
import type { Permission, RolePermission, PermissionMatrix } from "@/types";

export const getMatrix           = (userId: string) => client.get<PermissionMatrix[]>(`/permissions/matrix/${userId}`);
export const getUserPermissions  = (userId: string) => client.get<Permission[]>(`/permissions/user/${userId}`);
export const upsertPermission    = (userId: string, data: { resource: string; action: string; granted: boolean }) =>
  client.put<Permission>(`/permissions/user/${userId}`, data);
export const deletePermission    = (userId: string, resource: string, action: string) =>
  client.delete(`/permissions/user/${userId}/${resource}/${action}`);
export const getRolePermissions  = ()     => client.get<RolePermission[]>("/permissions/roles");
export const upsertRolePermission = (data: { role: string; resource: string; action: string; granted: boolean }) =>
  client.put<RolePermission>("/permissions/roles", data);
