import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import ProtectedRoute from "@/components/layout/ProtectedRoute";
import Layout from "@/components/layout/Layout";

// Pages — lazy loaded for code splitting
import { lazy, Suspense } from "react";
import { Skeleton } from "@/components/ui/skeleton";

const Login = lazy(() => import("@/pages/auth/Login"));
const Dashboard = lazy(() => import("@/pages/dashboard/Dashboard"));
const Orgs = lazy(() => import("@/pages/orgs/Orgs"));
const Users = lazy(() => import("@/pages/users/Users"));
const Branches = lazy(() => import("@/pages/branches/Branches"));
const Menu = lazy(() => import("@/pages/menu/Menu"));
const Inventory = lazy(() => import("@/pages/inventory/Inventory"));
const Recipes = lazy(() => import("@/pages/recipes/Recipes"));
const Shifts = lazy(() => import("@/pages/shifts/Shifts"));
const Analytics = lazy(() => import("@/pages/analytics/Analytics"));
const Permissions = lazy(() => import("@/pages/permissions/Permissions"));
const Discounts = lazy(() => import("@/pages/discounts/Discounts"));
const Orders = lazy(() => import("@/pages/orders/Orders"));

function PageLoader() {
  return (
    <div className="p-6 space-y-4">
      <Skeleton className="h-8 w-48" />
      <Skeleton className="h-4 w-72" />
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mt-6">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-28 rounded-2xl" />
        ))}
      </div>
      <Skeleton className="h-64 rounded-2xl" />
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={<PageLoader />}>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />
            <Route path="orgs" element={<Orgs />} />
            <Route path="users" element={<Users />} />
            <Route path="branches" element={<Branches />} />
            <Route path="menu" element={<Menu />} />
            <Route path="inventory" element={<Inventory />} />
            <Route path="recipes" element={<Recipes />} />
            <Route path="shifts" element={<Shifts />} />
            <Route path="analytics" element={<Analytics />} />
            <Route path="discounts" element={<Discounts />} />
            <Route path="orders" element={<Orders />} />
            <Route path="permissions/:userId" element={<Permissions />} />
            <Route path="permissions/select" element={<Permissions />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}
