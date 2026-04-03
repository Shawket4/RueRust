import { Navigate } from "react-router-dom";
import { useAuthStore } from "@/store/auth";
import { Skeleton } from "@/components/ui/skeleton";

export default function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const user = useAuthStore((s) => s.user);

  // Zustand loads synchronously from localStorage — no async loading state needed
  if (!user) return <Navigate to="/login" replace />;
  return <>{children}</>;
}
