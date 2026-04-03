import React from "react";
import { createRoot } from "react-dom/client";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "sonner";
import "./index.css";
import App from "./App";
import { queryClient } from "./lib/query";
import { ThemeProvider } from "./components/layout/ThemeProvider";
import { useAppStore } from "./store/app";

// Apply persisted direction on initial load
const lang = useAppStore.getState().language;
document.documentElement.lang = lang;
document.documentElement.dir  = lang === "ar" ? "rtl" : "ltr";

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
      <QueryClientProvider client={queryClient}>
        <App />
        <Toaster
          position="top-right"
          richColors
          closeButton
          toastOptions={{
            style: { fontFamily: "Cairo, sans-serif" },
          }}
        />
      </QueryClientProvider>
    </ThemeProvider>
  </React.StrictMode>,
);
