import client from "@/lib/client";
import type { Shift, ShiftPreFill, CashMovement, ShiftReport } from "@/types";

export const getCurrentShift  = (branchId: string)             => client.get<ShiftPreFill>(`/shifts/branches/${branchId}/current`);
export const getBranchShifts  = (branchId: string)             => client.get<Shift[]>(`/shifts/branches/${branchId}`);
export const getShift         = (id: string)                   => client.get<Shift>(`/shifts/${id}`);
export const openShift        = (branchId: string, data: Record<string, unknown>) => client.post<Shift>(`/shifts/branches/${branchId}/open`, data);
export const closeShift       = (id: string, data: Record<string, unknown>) => client.post(`/shifts/${id}/close`, data);
export const forceCloseShift  = (id: string, data: Record<string, unknown>) => client.post<Shift>(`/shifts/${id}/force-close`, data);
export const getCashMovements = (id: string)                   => client.get<CashMovement[]>(`/shifts/${id}/cash-movements`);
export const addCashMovement  = (id: string, data: Record<string, unknown>) => client.post<CashMovement>(`/shifts/${id}/cash-movements`, data);
export const getShiftReport   = (id: string)                   => client.get<ShiftReport>(`/shifts/${id}/report`);
