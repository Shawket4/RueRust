import client from "@/lib/client";
import type { LoginResponse, UserPublic } from "@/types";

export const login = (data: { email?: string; password?: string; pin?: string; name?: string }) =>
  client.post<LoginResponse>("/auth/login", data);

export const getMe = () =>
  client.get<{ user: UserPublic }>("/auth/me");
