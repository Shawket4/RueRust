import React from "react";
import { useQuery } from "@tanstack/react-query";
import { RefreshCw, CheckCircle2, XCircle, Loader2 } from "lucide-react";
import apiClient from "@/lib/client";

interface ServiceStatus {
  name: string;
  key: string;
}

const SERVICES: ServiceStatus[] = [
  { name: "API Server", key: "api" },
  { name: "Database", key: "db" },
  { name: "Auth Service", key: "auth" },
];

interface HealthResponse {
  status: string;
  services?: Record<string, string>;
}

function useHealth() {
  return useQuery<HealthResponse>({
    queryKey: ["health"],
    queryFn: async () => (await apiClient.get<HealthResponse>("/health")).data,
    refetchInterval: 30_000,
    retry: false,
    // Don't throw on error — we want to show "degraded" state
    throwOnError: false,
  });
}

function StatusDot({ ok }: { ok: boolean | null }) {
  if (ok === null)
    return <Loader2 size={12} className="animate-spin text-muted-foreground" />;
  return ok ? (
    <span className="flex items-center gap-1.5 text-green-600 dark:text-green-400 text-xs font-semibold">
      <CheckCircle2 size={13} /> Online
    </span>
  ) : (
    <span className="flex items-center gap-1.5 text-destructive text-xs font-semibold">
      <XCircle size={13} /> Degraded
    </span>
  );
}

export function SystemStatus() {
  const { data, isLoading, isError, refetch, isFetching } = useHealth();

  const getStatus = (key: string): boolean | null => {
    if (isLoading) return null;
    if (isError) return false;
    if (!data) return false;
    // If the API returns per-service statuses, use them; otherwise fall back to top-level
    if (data.services) {
      const s = data.services[key];
      return s
        ? s === "ok" || s === "healthy" || s === "up"
        : data.status === "ok" || data.status === "healthy";
    }
    return data.status === "ok" || data.status === "healthy";
  };

  return (
    <div className="p-5 sm:p-6">
      <div className="flex items-center justify-between gap-2 mb-4">
        <div className="flex items-center gap-2">
          <RefreshCw
            size={15}
            className={
              isFetching ? "animate-spin text-primary" : "text-primary"
            }
          />
          <h3 className="font-semibold">System Status</h3>
        </div>
        <button
          onClick={() => refetch()}
          className="text-xs text-muted-foreground hover:text-foreground transition-colors"
        >
          Refresh
        </button>
      </div>
      {SERVICES.map((s) => (
        <div
          key={s.key}
          className="flex items-center justify-between py-3 border-b border-border last:border-0"
        >
          <span className="text-sm text-foreground">{s.name}</span>
          <StatusDot ok={getStatus(s.key)} />
        </div>
      ))}
      {isError && (
        <p className="text-[11px] text-muted-foreground mt-2">
          Could not reach the health endpoint. The API may be unreachable.
        </p>
      )}
    </div>
  );
}
