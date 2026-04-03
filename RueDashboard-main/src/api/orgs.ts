import client from "@/lib/client";
import type { Org } from "@/types";

export const getOrgs  = ()       => client.get<Org[]>("/orgs");
export const getOrg   = (id: string) => client.get<Org>(`/orgs/${id}`);
export const createOrg = (data: {
  name: string; slug: string;
  currency_code?: string; tax_rate?: number; receipt_footer?: string;
}) => client.post<Org>("/orgs", data);
