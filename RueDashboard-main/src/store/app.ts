import { create } from "zustand";
import { persist } from "zustand/middleware";

type Language = "en" | "ar";

interface AppState {
  selectedOrgId:    string | null;
  selectedBranchId: string | null;
  language:         Language;
  sidebarOpen:      boolean;

  setSelectedOrg:    (id: string | null) => void;
  setSelectedBranch: (id: string | null) => void;
  setLanguage:       (lang: Language) => void;
  toggleSidebar:     () => void;
  setSidebarOpen:    (open: boolean) => void;
}

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      selectedOrgId:    null,
      selectedBranchId: null,
      language:         "en",
      sidebarOpen:      true,

      setSelectedOrg:    (id)   => set({ selectedOrgId: id }),
      setSelectedBranch: (id)   => set({ selectedBranchId: id }),
      setLanguage:       (lang) => {
        set({ language: lang });
        document.documentElement.lang = lang;
        document.documentElement.dir  = lang === "ar" ? "rtl" : "ltr";
      },
      toggleSidebar:  () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
      setSidebarOpen: (open) => set({ sidebarOpen: open }),
    }),
    {
      name:       "rue_app",
      version:    2,
      partialize: (s) => ({
        selectedOrgId:    s.selectedOrgId,
        selectedBranchId: s.selectedBranchId,
        language:         s.language,
      }),
      migrate: (persistedState, _version) => ({
        ...(persistedState as AppState),
        // Prevent stale persisted `sidebarOpen=false` from forcing the
        // sidebar into an icons-only view.
        sidebarOpen: true,
      }),
      merge: (persistedState, currentState) => ({
        ...currentState,
        ...(persistedState as AppState),
        // Always force expanded after hydration/rehydration.
        sidebarOpen: true,
      }),
    },
  ),
);
