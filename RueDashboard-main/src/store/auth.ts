import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { UserPublic } from "@/types";

interface AuthState {
  user:   UserPublic | null;
  token:  string | null;
  signIn: (token: string, user: UserPublic) => void;
  signOut: () => void;
  setUser: (user: UserPublic) => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user:  null,
      token: null,

      signIn: (token, user) => {
        localStorage.setItem("rue_token", token);
        set({ token, user });
      },

      signOut: () => {
        localStorage.removeItem("rue_token");
        set({ token: null, user: null });
      },

      setUser: (user) => set({ user }),
    }),
    {
      name:    "rue_auth",
      partialize: (s) => ({ user: s.user, token: s.token }),
    },
  ),
);
