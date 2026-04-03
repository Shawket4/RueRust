import client from "@/lib/client";
import type { Branch } from "@/types";

export const getBranches  = (orgId: string)          => client.get<Branch[]>("/branches", { params: { org_id: orgId } });
export const getBranch    = (id: string)             => client.get<Branch>(`/branches/${id}`);
export const createBranch = (data: Partial<Branch> & { org_id: string; name: string }) =>
  client.post<Branch>("/branches", data);
export const updateBranch = (id: string, data: Partial<Branch> & {
  printer_brand?: string | null;
  printer_ip?:    string | null;
  printer_port?:  number | null;
}) => client.put<Branch>(`/branches/${id}`, data);
export const deleteBranch = (id: string) => client.delete(`/branches/${id}`);
