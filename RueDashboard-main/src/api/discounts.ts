import client from "@/lib/client";
import type { Discount } from "@/types";

export const getDiscounts    = (orgId: string) =>
  client.get<Discount[]>("/discounts", { params: { org_id: orgId } });

export const createDiscount  = (data: {
  org_id: string; name: string; dtype: string; value: number; is_active?: boolean;
}) => client.post<Discount>("/discounts", data);

export const updateDiscount  = (id: string, data: {
  name?: string; dtype?: string; value?: number; is_active?: boolean;
}) => client.patch<Discount>(`/discounts/${id}`, data);

export const deleteDiscount  = (id: string) =>
  client.delete(`/discounts/${id}`);
