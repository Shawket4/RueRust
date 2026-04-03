import client from "@/lib/client";
import type { DrinkRecipe, AddonIngredient, DrinkOptionOverride } from "@/types";

export const getDrinkRecipes     = (menuItemId: string)                                    => client.get<DrinkRecipe[]>(`/recipes/drinks/${menuItemId}`);
export const upsertDrinkRecipe   = (menuItemId: string, data: Record<string, unknown>)     => client.post<DrinkRecipe>(`/recipes/drinks/${menuItemId}`, data);
export const deleteDrinkRecipe = (itemId: string, size: string, ingredientName: string) =>
  client.delete(`/recipes/drinks/${itemId}/${size}`, { params: { ingredient_name: ingredientName } });

export const getAddonIngredients   = (addonItemId: string)                                 => client.get<AddonIngredient[]>(`/recipes/addons/${addonItemId}`);
export const upsertAddonIngredient = (addonItemId: string, data: Record<string, unknown>)  => client.post<AddonIngredient>(`/recipes/addons/${addonItemId}`, data);


export const deleteAddonIngredient = (addonId: string, ingredientName: string) =>
  client.delete(`/recipes/addons/${addonId}`, { params: { ingredient_name: ingredientName } });

export const getOverrides   = (drinkOptionItemId: string)                                  => client.get<DrinkOptionOverride[]>(`/recipes/overrides/${drinkOptionItemId}`);
export const upsertOverride = (drinkOptionItemId: string, data: Record<string, unknown>)   => client.post<DrinkOptionOverride>(`/recipes/overrides/${drinkOptionItemId}`, data);
export const deleteOverride = (drinkOptionItemId: string, invId: string, size?: string)    =>
  client.delete(`/recipes/overrides/${drinkOptionItemId}/${invId}`, { params: size ? { size } : {} });
