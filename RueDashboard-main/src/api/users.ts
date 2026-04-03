import client from "@/lib/client";
import type { UserPublic, UserBranch } from "@/types";

export const getUsers       = (orgId?: string | null) =>
  client.get<UserPublic[]>("/users", { params: orgId ? { org_id: orgId } : {} });
export const getUser        = (id: string)            => client.get<UserPublic>(`/users/${id}`);
export const createUser     = (data: Record<string, unknown>) => client.post<{ user: UserPublic }>("/users", data);
export const updateUser     = (id: string, data: Record<string, unknown>) => client.patch<UserPublic>(`/users/${id}`, data);
export const deleteUser     = (id: string)            => client.delete(`/users/${id}`);
export const assignBranch   = (userId: string, branchId: string) =>
  client.post(`/users/${userId}/branches`, { branch_id: branchId });
export const unassignBranch = (userId: string, branchId: string) =>
  client.delete(`/users/${userId}/branches/${branchId}`);
export const getUserBranches = (userId: string) =>
  client.get<UserBranch[]>(`/users/${userId}/branches`);
