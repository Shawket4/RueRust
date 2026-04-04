import client from "@/lib/client";
import type { Category, MenuItem, MenuItemFull, AddonItem, ItemSize, MenuItemAddonSlot, MenuItemAddonOverride } from "@/types";

// Categories
export const getCategories  = (orgId: string)          => client.get<Category[]>("/categories", { params: { org_id: orgId } });
export const createCategory = (data: Record<string, unknown>) => client.post<Category>("/categories", data);
export const updateCategory = (id: string, data: Record<string, unknown>) => client.patch<Category>(`/categories/${id}`, data);
export const deleteCategory = (id: string)             => client.delete(`/categories/${id}`);

// Menu items
export const getMenuItems   = (orgId: string, catId?: string | null) =>
  client.get<MenuItem[]>("/menu-items", { params: { org_id: orgId, ...(catId ? { category_id: catId } : {}) } });
export const getMenuItem    = (id: string) => client.get<MenuItemFull>(`/menu-items/${id}`);
export const createMenuItem = (data: Record<string, unknown>) => client.post<MenuItemFull>("/menu-items", data);
export const updateMenuItem = (id: string, data: Record<string, unknown>) => client.patch<MenuItem>(`/menu-items/${id}`, data);
export const deleteMenuItem = (id: string) => client.delete(`/menu-items/${id}`);
export const uploadMenuItemImage = (id: string, file: File) => {
  const form = new FormData();
  form.append("image", file);
  return client.post<{ image_url: string }>(`/uploads/menu-items/${id}`, form, {
    headers: { "Content-Type": "multipart/form-data" },
  });
};

// Addon items
export const getAddonItems   = (orgId: string, type?: string | null) =>
  client.get<AddonItem[]>("/addon-items", { params: { org_id: orgId, ...(type ? { addon_type: type } : {}) } });
export const createAddonItem = (data: Record<string, unknown>) => client.post<AddonItem>("/addon-items", data);
export const updateAddonItem = (id: string, data: Record<string, unknown>) => client.patch<AddonItem>(`/addon-items/${id}`, data);
export const deleteAddonItem = (id: string) => client.delete(`/addon-items/${id}`);

// Addon Slots
export const createAddonSlot = (itemId: string, data: Record<string, unknown>) =>
  client.post<MenuItemAddonSlot>(`/menu-items/${itemId}/addon-slots`, data);
export const updateAddonSlot = (itemId: string, slotId: string, data: Record<string, unknown>) =>
  client.patch<MenuItemAddonSlot>(`/menu-items/${itemId}/addon-slots/${slotId}`, data);
export const deleteAddonSlot = (itemId: string, slotId: string) =>
  client.delete(`/menu-items/${itemId}/addon-slots/${slotId}`);

// Addon Overrides
export const upsertAddonOverride = (itemId: string, data: Record<string, unknown>) =>
  client.post<MenuItemAddonOverride>(`/menu-items/${itemId}/addon-overrides`, data);
export const deleteAddonOverride = (itemId: string, oid: string) =>
  client.delete(`/menu-items/${itemId}/addon-overrides/${oid}`);

// Sizes
export const upsertSize = (itemId: string, data: { label: string; price_override: number; display_order?: number }) =>
  client.post<ItemSize>(`/menu-items/${itemId}/sizes`, data);
export const deleteSize = (itemId: string, sid: string) => client.delete(`/menu-items/${itemId}/sizes/${sid}`);
