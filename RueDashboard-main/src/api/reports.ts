import client from "@/lib/client";
import type {
  ShiftSummary, BranchSalesReport, BranchStockReport,
  TimeseriesPoint, TellerStats, AddonSalesRow,
  OrgComparisonReport, InventoryDiscrepancy,
} from "@/types";

export const getShiftSummary    = (shiftId: string)          => client.get<ShiftSummary>(`/reports/shifts/${shiftId}/summary`);
export const getShiftInventory  = (shiftId: string)          => client.get<InventoryDiscrepancy[]>(`/reports/shifts/${shiftId}/inventory`);
export const getBranchSales     = (branchId: string, params: Record<string, unknown>) =>
  client.get<BranchSalesReport>(`/reports/branches/${branchId}/sales`, { params });
export const getBranchTimeseries = (branchId: string, params: Record<string, unknown>) =>
  client.get<TimeseriesPoint[]>(`/reports/branches/${branchId}/sales/timeseries`, { params });
export const getBranchTellers   = (branchId: string, params: Record<string, unknown>) =>
  client.get<TellerStats[]>(`/reports/branches/${branchId}/tellers`, { params });
export const getBranchAddonSales = (branchId: string, params: Record<string, unknown>) =>
  client.get<AddonSalesRow[]>(`/reports/branches/${branchId}/addons`, { params });
export const getBranchStock     = (branchId: string)         => client.get<BranchStockReport>(`/reports/branches/${branchId}/stock`);
export const getOrgComparison   = (orgId: string, params: Record<string, unknown>) =>
  client.get<OrgComparisonReport>(`/reports/orgs/${orgId}/comparison`, { params });
