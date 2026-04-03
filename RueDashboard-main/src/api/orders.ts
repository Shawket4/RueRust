import client from "@/lib/client";
import type { Order } from "@/types";

export interface OrdersQuery {
    branch_id?:      string;
    shift_id?:       string;
    page?:           number;
    per_page?:       number;
    teller_name?:    string;
    payment_method?: string;
    status?:         string;
    from?:           string;
    to?:             string;
  }
  
  export interface PaginatedOrders {
    data:        Order[];
    total:       number;
    page:        number;
    per_page:    number;
    total_pages: number;
  }

  export const getOrders = (params: OrdersQuery) =>
    client.get<PaginatedOrders>("/orders", { params });

export const getOrder    = (id: string)                      => client.get<Order>(`/orders/${id}`);
export const createOrder = (data: Record<string, unknown>)  => client.post<Order>("/orders", data);
export const voidOrder   = (id: string, data: Record<string, unknown>) => client.post<Order>(`/orders/${id}/void`, data);
