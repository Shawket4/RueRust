import client from "@/lib/client";
import type {
  OrgIngredient,
  BranchInventoryItem,
  BranchInventoryAdjustment,
  BranchInventoryTransfer,
} from "@/types";

// ── Org-level catalog ─────────────────────────────────────────────────────────
export const getCatalog = (orgId: string) =>
  client.get<OrgIngredient[]>(`/inventory/orgs/${orgId}/catalog`);

export const createCatalogItem = (orgId: string, data: Record<string, unknown>) =>
  client.post<OrgIngredient>(`/inventory/orgs/${orgId}/catalog`, data);

export const updateCatalogItem = (orgId: string, id: string, data: Record<string, unknown>) =>
  client.patch<OrgIngredient>(`/inventory/orgs/${orgId}/catalog/${id}`, data);

export const deleteCatalogItem = (orgId: string, id: string) =>
  client.delete(`/inventory/orgs/${orgId}/catalog/${id}`);

// ── Branch-level stock ────────────────────────────────────────────────────────
export const getBranchStock = (branchId: string) =>
  client.get<BranchInventoryItem[]>(`/inventory/branches/${branchId}/stock`);

export const addToStock = (branchId: string, data: Record<string, unknown>) =>
  client.post<BranchInventoryItem>(`/inventory/branches/${branchId}/stock`, data);

export const updateStock = (branchId: string, id: string, data: Record<string, unknown>) =>
  client.patch<BranchInventoryItem>(`/inventory/branches/${branchId}/stock/${id}`, data);

export const removeFromStock = (branchId: string, id: string) =>
  client.delete(`/inventory/branches/${branchId}/stock/${id}`);

// ── Adjustments ───────────────────────────────────────────────────────────────
export const getAdjustments = (branchId: string) =>
  client.get<BranchInventoryAdjustment[]>(`/inventory/branches/${branchId}/adjustments`);

export const createAdjustment = (branchId: string, data: Record<string, unknown>) =>
  client.post<BranchInventoryAdjustment>(`/inventory/branches/${branchId}/adjustments`, data);

// ── Transfers ─────────────────────────────────────────────────────────────────
export const getTransfers = (branchId: string, direction?: string) =>
  client.get<BranchInventoryTransfer[]>(
    `/inventory/branches/${branchId}/transfers`,
    { params: direction ? { direction } : {} },
  );

export const createTransfer = (data: Record<string, unknown>) =>
  client.post<BranchInventoryTransfer>("/inventory/transfers", data);
