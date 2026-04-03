#!/usr/bin/env bash
# =============================================================================
#  Rue POS Dashboard — Frontend Rewrite Part 1: Foundation
#  Run from the React project root (where package.json lives).
#
#  What this creates:
#   - package.json           (all deps: shadcn, TanStack, Zustand, Sonner, cmdk)
#   - vite.config.ts
#   - tsconfig.json
#   - tailwind.config.ts     (full theme, RTL, dark mode, CSS vars)
#   - src/index.css          (shadcn CSS variables, Cairo font, RTL utilities)
#   - src/types/             (all TypeScript interfaces matching Rust structs)
#   - src/lib/               (axios client typed, query client)
#   - src/store/             (useAuthStore, useAppStore)
#   - src/utils/             (formatters: egp, dates, payment methods, etc.)
#   - src/api/               (all API files fully typed)
#   - src/components/ui/     (shadcn primitives + custom composites)
#   - src/components/layout/ (Sidebar, Header, Layout, ThemeProvider, etc.)
#   - src/main.tsx
#   - src/App.tsx
# =============================================================================
set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RESET='\033[0m'
log()  { echo -e "${CYAN}[part1]${RESET} $*"; }
ok()   { echo -e "${GREEN}[done] ${RESET} $*"; }
warn() { echo -e "${YELLOW}[warn] ${RESET} $*"; }

if [[ ! -f "package.json" ]]; then
  echo "ERROR: Run from the React project root (where package.json lives)."; exit 1
fi

# ---------------------------------------------------------------------------
# Wipe src/ and recreate skeleton
# ---------------------------------------------------------------------------
log "Wiping src/ ..."
rm -rf src
mkdir -p src/{types,lib,store,utils,api,components/{ui,layout},pages/{auth,dashboard,orgs,users,branches,menu,inventory,recipes,shifts,analytics,permissions}}
ok "src/ skeleton created"

# ===========================================================================
#  package.json
# ===========================================================================
log "Writing package.json ..."
cat > package.json << 'JSON'
{
  "name": "rue-pos-dashboard",
  "private": true,
  "version": "2.0.0",
  "type": "module",
  "scripts": {
    "dev":     "vite",
    "build":   "tsc -b && vite build",
    "preview": "vite preview",
    "lint":    "eslint ."
  },
  "dependencies": {
    "@hookform/resolvers":          "^3.9.0",
    "@radix-ui/react-accordion":    "^1.2.0",
    "@radix-ui/react-alert-dialog": "^1.1.1",
    "@radix-ui/react-avatar":       "^1.1.0",
    "@radix-ui/react-checkbox":     "^1.1.1",
    "@radix-ui/react-dialog":       "^1.1.1",
    "@radix-ui/react-dropdown-menu":"^2.1.1",
    "@radix-ui/react-label":        "^2.1.0",
    "@radix-ui/react-popover":      "^1.1.1",
    "@radix-ui/react-progress":     "^1.1.0",
    "@radix-ui/react-scroll-area":  "^1.1.0",
    "@radix-ui/react-select":       "^2.1.1",
    "@radix-ui/react-separator":    "^1.1.0",
    "@radix-ui/react-slot":         "^1.1.0",
    "@radix-ui/react-switch":       "^1.1.0",
    "@radix-ui/react-tabs":         "^1.1.0",
    "@radix-ui/react-toast":        "^1.2.1",
    "@radix-ui/react-tooltip":      "^1.1.2",
    "@tanstack/react-query":        "^5.56.2",
    "@tanstack/react-table":        "^8.20.5",
    "axios":                        "^1.7.7",
    "class-variance-authority":     "^0.7.0",
    "clsx":                         "^2.1.1",
    "cmdk":                         "^1.0.0",
    "date-fns":                     "^3.6.0",
    "html2canvas":                  "^1.4.1",
    "jspdf":                        "^2.5.1",
    "lucide-react":                 "^0.446.0",
    "next-themes":                  "^0.3.0",
    "react":                        "^18.3.1",
    "react-day-picker":             "^8.10.1",
    "react-dom":                    "^18.3.1",
    "react-hook-form":              "^7.53.0",
    "react-router-dom":             "^6.26.2",
    "recharts":                     "^2.12.7",
    "sonner":                       "^1.5.0",
    "tailwind-merge":               "^2.5.2",
    "tailwindcss-animate":          "^1.0.7",
    "zod":                          "^3.23.8",
    "zustand":                      "^5.0.0"
  },
  "devDependencies": {
    "@eslint/js":                   "^9.9.0",
    "@types/node":                  "^22.5.5",
    "@types/react":                 "^18.3.5",
    "@types/react-dom":             "^18.3.0",
    "@vitejs/plugin-react":         "^4.3.1",
    "autoprefixer":                 "^10.4.20",
    "eslint":                       "^9.9.0",
    "eslint-plugin-react-hooks":    "^5.1.0-rc.0",
    "eslint-plugin-react-refresh":  "^0.4.11",
    "globals":                      "^15.9.0",
    "postcss":                      "^8.4.47",
    "tailwindcss":                  "^3.4.11",
    "typescript":                   "^5.5.3",
    "typescript-eslint":            "^8.0.1",
    "vite":                         "^5.4.8"
  }
}
JSON
ok "package.json"

# ===========================================================================
#  vite.config.ts
# ===========================================================================
cat > vite.config.ts << 'TS'
import path from "path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
});
TS
ok "vite.config.ts"

# ===========================================================================
#  tsconfig.json
# ===========================================================================
cat > tsconfig.json << 'JSON'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src"]
}
JSON
ok "tsconfig.json"

# ===========================================================================
#  postcss.config.js
# ===========================================================================
cat > postcss.config.js << 'JS'
export default {
  plugins: { tailwindcss: {}, autoprefixer: {} },
};
JS

# ===========================================================================
#  tailwind.config.ts
# ===========================================================================
log "Writing tailwind.config.ts ..."
cat > tailwind.config.ts << 'TS'
import type { Config } from "tailwindcss";
import animate from "tailwindcss-animate";

const config: Config = {
  darkMode: ["class"],
  content: ["./index.html", "./src/**/*.{ts,tsx,js,jsx}"],
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: { "2xl": "1400px" },
    },
    extend: {
      fontFamily: {
        sans: ["Cairo", "sans-serif"],
        cairo: ["Cairo", "sans-serif"],
      },
      colors: {
        border:      "hsl(var(--border))",
        input:       "hsl(var(--input))",
        ring:        "hsl(var(--ring))",
        background:  "hsl(var(--background))",
        foreground:  "hsl(var(--foreground))",
        primary: {
          DEFAULT:    "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT:    "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT:    "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT:    "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT:    "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT:    "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT:    "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
        // Brand colours
        brand: {
          50:  "#eff6ff",
          100: "#dbeafe",
          200: "#bfdbfe",
          300: "#93c5fd",
          400: "#60a5fa",
          500: "#3b82f6",
          600: "#1a56db",
          700: "#1d4ed8",
          800: "#1e40af",
          900: "#1e3a8a",
        },
        indigo: {
          600: "#3b28cc",
          700: "#3730a3",
        },
      },
      borderRadius: {
        lg:  "var(--radius)",
        md:  "calc(var(--radius) - 2px)",
        sm:  "calc(var(--radius) - 4px)",
        xl:  "calc(var(--radius) + 4px)",
        "2xl": "calc(var(--radius) + 8px)",
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to:   { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to:   { height: "0" },
        },
        "fade-in": {
          from: { opacity: "0", transform: "translateY(4px)" },
          to:   { opacity: "1", transform: "translateY(0)" },
        },
        "slide-in-right": {
          from: { transform: "translateX(100%)" },
          to:   { transform: "translateX(0)" },
        },
        "slide-in-left": {
          from: { transform: "translateX(-100%)" },
          to:   { transform: "translateX(0)" },
        },
      },
      animation: {
        "accordion-down":  "accordion-down 0.2s ease-out",
        "accordion-up":    "accordion-up 0.2s ease-out",
        "fade-in":         "fade-in 0.2s ease-out",
        "slide-in-right":  "slide-in-right 0.25s cubic-bezier(0.4,0,0.2,1)",
        "slide-in-left":   "slide-in-left 0.25s cubic-bezier(0.4,0,0.2,1)",
      },
    },
  },
  plugins: [animate],
};

export default config;
TS
ok "tailwind.config.ts"

# ===========================================================================
#  index.html
# ===========================================================================
cat > index.html << 'HTML'
<!doctype html>
<html lang="en" dir="ltr">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/png" href="/TheRue.png" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Rue POS</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;500;600;700;800;900&display=swap"
      rel="stylesheet"
    />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
HTML
ok "index.html"

# ===========================================================================
#  src/index.css  — shadcn CSS variables + RTL + dark mode
# ===========================================================================
log "Writing src/index.css ..."
cat > src/index.css << 'CSS'
@import "tailwindcss/base";
@import "tailwindcss/components";
@import "tailwindcss/utilities";

/* ── Cairo font baseline ─────────────────────────────────────── */
* {
  font-family: "Cairo", sans-serif;
  -webkit-tap-highlight-color: transparent;
  box-sizing: border-box;
}

html, body, #root {
  overflow-x: hidden;
  overscroll-behavior-y: none;
}

body { position: relative; }

/* ── shadcn CSS variables — Light mode ───────────────────────── */
:root {
  --background:          0 0% 98%;
  --foreground:          222 47% 11%;
  --card:                0 0% 100%;
  --card-foreground:     222 47% 11%;
  --popover:             0 0% 100%;
  --popover-foreground:  222 47% 11%;

  /* Brand blue: #1a56db */
  --primary:             221 78% 47%;
  --primary-foreground:  0 0% 100%;

  --secondary:           214 32% 91%;
  --secondary-foreground:222 47% 11%;

  --muted:               214 32% 95%;
  --muted-foreground:    215 16% 47%;

  --accent:              221 78% 95%;
  --accent-foreground:   221 78% 40%;

  --destructive:         0 84% 60%;
  --destructive-foreground: 0 0% 100%;

  --border:              214 32% 91%;
  --input:               214 32% 91%;
  --ring:                221 78% 47%;

  --radius: 0.625rem;

  /* Chart palette */
  --chart-1: 221 78% 47%;
  --chart-2: 160 60% 40%;
  --chart-3: 258 58% 52%;
  --chart-4: 38 80% 50%;
  --chart-5: 4 84% 60%;
}

/* ── Dark mode ───────────────────────────────────────────────── */
.dark {
  --background:          222 47% 8%;
  --foreground:          210 40% 96%;
  --card:                222 47% 11%;
  --card-foreground:     210 40% 96%;
  --popover:             222 47% 11%;
  --popover-foreground:  210 40% 96%;

  --primary:             221 78% 58%;
  --primary-foreground:  0 0% 100%;

  --secondary:           217 33% 17%;
  --secondary-foreground:210 40% 96%;

  --muted:               217 33% 17%;
  --muted-foreground:    215 20% 65%;

  --accent:              221 78% 20%;
  --accent-foreground:   221 78% 75%;

  --destructive:         0 62% 45%;
  --destructive-foreground: 0 0% 100%;

  --border:              217 33% 20%;
  --input:               217 33% 20%;
  --ring:                221 78% 58%;

  --chart-1: 221 78% 58%;
  --chart-2: 160 60% 50%;
  --chart-3: 258 58% 62%;
  --chart-4: 38 80% 60%;
  --chart-5: 4 84% 65%;
}

/* ── Brand gradient utility ──────────────────────────────────── */
.brand-gradient {
  background: linear-gradient(135deg, #1a56db 0%, #3b28cc 100%);
}

.brand-gradient-text {
  background: linear-gradient(135deg, #1a56db 0%, #3b28cc 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

/* ── Scrollbar styling ───────────────────────────────────────── */
.no-scrollbar::-webkit-scrollbar { display: none; }
.no-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }

::-webkit-scrollbar { width: 5px; height: 5px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb {
  background: hsl(var(--border));
  border-radius: 99px;
}
::-webkit-scrollbar-thumb:hover { background: hsl(var(--muted-foreground)); }

/* ── RTL utilities ───────────────────────────────────────────── */
[dir="rtl"] .rtl-mirror { transform: scaleX(-1); }
[dir="rtl"] .ltr-only   { display: none; }
[dir="ltr"] .rtl-only   { display: none; }

/* ── Safe area ───────────────────────────────────────────────── */
.pb-safe { padding-bottom: max(1rem, env(safe-area-inset-bottom)); }
.pt-safe { padding-top: env(safe-area-inset-top); }

/* ── Smooth momentum scrolling on iOS ───────────────────────── */
.scroll-ios { -webkit-overflow-scrolling: touch; }

/* ── Table row hover ─────────────────────────────────────────── */
.table-row-hover:hover { background: hsl(var(--muted) / 0.5); }

/* ── Sidebar active link gradient indicator ──────────────────── */
.nav-active-indicator {
  position: absolute;
  left: 0;
  top: 50%;
  transform: translateY(-50%);
  width: 3px;
  height: 60%;
  border-radius: 0 3px 3px 0;
  background: linear-gradient(180deg, #1a56db, #3b28cc);
}

[dir="rtl"] .nav-active-indicator {
  left: auto;
  right: 0;
  border-radius: 3px 0 0 3px;
}

/* ── Skeleton pulse ──────────────────────────────────────────── */
@keyframes skeleton-pulse {
  0%, 100% { opacity: 1; }
  50%       { opacity: 0.5; }
}
.skeleton-pulse { animation: skeleton-pulse 2s cubic-bezier(0.4,0,0.6,1) infinite; }
CSS
ok "src/index.css"

# ===========================================================================
#  src/types/index.ts  — all TypeScript interfaces matching Rust structs
# ===========================================================================
log "Writing src/types/index.ts ..."
cat > src/types/index.ts << 'TS'
// =============================================================================
//  Rue POS — TypeScript types matching Rust backend structs
// =============================================================================

// ── Auth ──────────────────────────────────────────────────────────────────────
export type UserRole = "super_admin" | "org_admin" | "branch_manager" | "teller";

export interface UserPublic {
  id:        string;
  org_id:    string | null;
  branch_id: string | null;
  name:      string;
  email:     string | null;
  phone:     string | null;
  role:      UserRole;
  is_active: boolean;
}

export interface LoginResponse {
  token: string;
  user:  UserPublic;
}

// ── Organisations ─────────────────────────────────────────────────────────────
export interface Org {
  id:             string;
  name:           string;
  slug:           string;
  logo_url:       string | null;
  currency_code:  string;
  tax_rate:       number;
  receipt_footer: string | null;
  is_active:      boolean;
}

// ── Branches ──────────────────────────────────────────────────────────────────
export type PrinterBrand = "star" | "epson";

export interface Branch {
  id:            string;
  org_id:        string;
  name:          string;
  address:       string | null;
  phone:         string | null;
  timezone:      string;
  printer_brand: PrinterBrand | null;
  printer_ip:    string | null;
  printer_port:  number | null;
  is_active:     boolean;
  created_at:    string;
  updated_at:    string;
}

// ── Users ─────────────────────────────────────────────────────────────────────
export interface UserBranch {
  branch_id:   string;
  branch_name: string;
}

// ── Permissions ───────────────────────────────────────────────────────────────
export interface Permission {
  id:       string;
  user_id:  string;
  resource: string;
  action:   string;
  granted:  boolean;
}

export interface RolePermission {
  role:     string;
  resource: string;
  action:   string;
  granted:  boolean;
}

export interface PermissionMatrix {
  resource:      string;
  action:        string;
  role_default:  boolean | null;
  user_override: boolean | null;
  effective:     boolean;
}

// ── Menu ──────────────────────────────────────────────────────────────────────
export interface Category {
  id:            string;
  org_id:        string;
  name:          string;
  image_url:     string | null;
  display_order: number;
  is_active:     boolean;
  created_at:    string;
  updated_at:    string;
}

export type AddonType = "coffee_type" | "milk_type" | "extra";

export interface AddonItem {
  id:            string;
  org_id:        string;
  name:          string;
  addon_type:    AddonType;
  default_price: number; // piastres
  is_active:     boolean;
  display_order: number;
  created_at:    string;
  updated_at:    string;
}

export interface ItemSize {
  id:             string;
  menu_item_id:   string;
  label:          string;
  price_override: number;
  display_order:  number;
  is_active:      boolean;
}

export interface DrinkOptionItemFull {
  id:             string;
  group_id:       string;
  addon_item_id:  string;
  price_override: number | null;
  display_order:  number;
  is_active:      boolean;
  name:           string;
  default_price:  number;
  addon_type:     AddonType;
}

export interface DrinkOptionGroupFull {
  id:             string;
  menu_item_id:   string;
  group_type:     AddonType;
  selection_type: "single" | "multi";
  is_required:    boolean;
  min_selections: number;
  display_order:  number;
  items:          DrinkOptionItemFull[];
}

export interface MenuItem {
  id:            string;
  org_id:        string;
  category_id:   string | null;
  name:          string;
  description:   string | null;
  image_url:     string | null;
  base_price:    number;
  is_active:     boolean;
  display_order: number;
  created_at:    string;
  updated_at:    string;
}

export interface MenuItemFull extends MenuItem {
  sizes:         ItemSize[];
  option_groups: DrinkOptionGroupFull[];
}

// ── Recipes ───────────────────────────────────────────────────────────────────
export interface DrinkRecipe {
  id:                    string;
  menu_item_id:          string;
  size_label:            string;
  inventory_item_id:     string;
  inventory_item_name:   string;
  unit:                  string;
  quantity_used:         number;
}

export interface AddonIngredient {
  id:                    string;
  addon_item_id:         string;
  inventory_item_id:     string;
  inventory_item_name:   string;
  unit:                  string;
  quantity_used:         number;
}

export interface DrinkOptionOverride {
  id:                    string;
  drink_option_item_id:  string;
  size_label:            string | null;
  inventory_item_id:     string;
  inventory_item_name:   string;
  unit:                  string;
  quantity_used:         number;
}

// ── Inventory ─────────────────────────────────────────────────────────────────
export type InventoryUnit = "g" | "kg" | "ml" | "l" | "pcs";

export interface InventoryItem {
  id:                string;
  branch_id:         string;
  name:              string;
  unit:              InventoryUnit;
  current_stock:     number;
  reorder_threshold: number;
  cost_per_unit:     number | null;
  is_active:         boolean;
  created_at:        string;
  updated_at:        string;
}

export interface InventoryAdjustment {
  id:                string;
  branch_id:         string;
  inventory_item_id: string;
  item_name:         string;
  unit:              string;
  adjustment_type:   "add" | "remove" | "transfer_in" | "transfer_out";
  quantity:          number;
  note:              string | null;
  transfer_id:       string | null;
  adjusted_by:       string;
  adjusted_by_name:  string;
  created_at:        string;
}

export type TransferStatus = "pending" | "completed" | "partial" | "rejected";

export interface InventoryTransfer {
  id:                       string;
  source_branch_id:         string;
  source_branch_name:       string;
  destination_branch_id:    string;
  destination_branch_name:  string;
  inventory_item_id:        string;
  item_name:                string;
  unit:                     string;
  quantity_sent:            number;
  quantity_confirmed:       number | null;
  status:                   TransferStatus;
  note:                     string | null;
  initiated_by:             string;
  initiated_by_name:        string;
  confirmed_by:             string | null;
  rejection_reason:         string | null;
  initiated_at:             string;
  confirmed_at:             string | null;
}

// ── Soft Serve ────────────────────────────────────────────────────────────────
export interface ServePool {
  id:             string;
  branch_id:      string;
  menu_item_id:   string;
  item_name:      string;
  total_units:    number;
  large_ratio:    number;
  low_stock_flag: boolean;
  updated_at:     string;
}

export interface SoftServeBatch {
  id:             string;
  branch_id:      string;
  menu_item_id:   string;
  item_name:      string;
  small_serves:   number;
  large_serves:   number;
  large_ratio:    number;
  total_units:    number;
  logged_by:      string;
  logged_by_name: string;
  notes:          string | null;
  created_at:     string;
}

// ── Orders ────────────────────────────────────────────────────────────────────
export type PaymentMethod =
  | "cash" | "card" | "digital_wallet" | "mixed"
  | "talabat_online" | "talabat_cash";

export type OrderStatus = "completed" | "voided";

export interface OrderItemAddon {
  id:            string;
  order_item_id: string;
  addon_item_id: string;
  addon_name:    string;
  unit_price:    number;
  quantity:      number;
  line_total:    number;
}

export interface OrderItem {
  id:           string;
  order_id:     string;
  menu_item_id: string;
  item_name:    string;
  size_label:   string | null;
  unit_price:   number;
  quantity:     number;
  line_total:   number;
  notes:        string | null;
  addons:       OrderItemAddon[];
}

export interface Order {
  id:              string;
  branch_id:       string;
  shift_id:        string;
  teller_id:       string;
  teller_name:     string;
  order_number:    number;
  status:          OrderStatus;
  payment_method:  PaymentMethod;
  subtotal:        number;
  discount_type:   "percentage" | "fixed" | null;
  discount_value:  number;
  discount_amount: number;
  tax_amount:      number;
  total_amount:    number;
  customer_name:   string | null;
  notes:           string | null;
  voided_at:       string | null;
  void_reason:     string | null;
  voided_by:       string | null;
  created_at:      string;
  items?:          OrderItem[];
}

// ── Shifts ────────────────────────────────────────────────────────────────────
export type ShiftStatus = "open" | "closed" | "force_closed";

export interface Shift {
  id:                        string;
  branch_id:                 string;
  teller_id:                 string;
  teller_name:               string;
  status:                    ShiftStatus;
  opening_cash:              number;
  opening_cash_original:     number | null;
  opening_cash_was_edited:   boolean;
  opening_cash_edit_reason:  string | null;
  closing_cash_declared:     number | null;
  closing_cash_system:       number | null;
  cash_discrepancy:          number | null;
  opened_at:                 string;
  closed_at:                 string | null;
  closed_by:                 string | null;
  force_closed_by:           string | null;
  force_closed_at:           string | null;
  force_close_reason:        string | null;
  notes:                     string | null;
}

export interface ShiftPreFill {
  has_open_shift:         boolean;
  open_shift:             Shift | null;
  suggested_opening_cash: number;
}

export interface CashMovement {
  id:            string;
  shift_id:      string;
  amount:        number;
  note:          string;
  moved_by:      string;
  moved_by_name: string;
  created_at:    string;
}

export interface PaymentSummaryRow {
  payment_method: PaymentMethod;
  total:          number;
  order_count:    number;
}

export interface CashMovementSummaryRow {
  amount:        number;
  note:          string;
  moved_by_name: string;
  created_at:    string;
}

export interface ShiftReport {
  shift:               Shift;
  payment_summary:     PaymentSummaryRow[];
  total_payments:      number;
  total_returns:       number;
  net_payments:        number;
  cash_movements:      CashMovementSummaryRow[];
  cash_movements_in:   number;
  cash_movements_out:  number;
  cash_movements_net:  number;
  printed_at:          string;
}

// ── Reports / Analytics ───────────────────────────────────────────────────────
export interface ItemSales {
  menu_item_id:  string;
  item_name:     string;
  quantity_sold: number;
  revenue:       number;
}

export interface CategorySales {
  category_id:   string | null;
  category_name: string | null;
  item_count:    number;
  quantity_sold: number;
  revenue:       number;
  items:         ItemSales[];
}

export interface BranchSalesReport {
  branch_id:              string;
  branch_name:            string;
  from:                   string | null;
  to:                     string | null;
  total_orders:           number;
  voided_orders:          number;
  subtotal:               number;
  total_discount:         number;
  total_tax:              number;
  total_revenue:          number;
  cash_revenue:           number;
  card_revenue:           number;
  digital_wallet_revenue: number;
  mixed_revenue:          number;
  talabat_online_revenue: number;
  talabat_cash_revenue:   number;
  top_items:              ItemSales[];
  by_category:            CategorySales[];
}

export interface TimeseriesPoint {
  period:                 string;
  orders:                 number;
  revenue:                number;
  voided:                 number;
  discount:               number;
  tax:                    number;
  cash_revenue:           number;
  card_revenue:           number;
  digital_wallet_revenue: number;
  mixed_revenue:          number;
  talabat_online_revenue: number;
  talabat_cash_revenue:   number;
}

export interface TellerStats {
  teller_id:       string;
  teller_name:     string;
  orders:          number;
  revenue:         number;
  avg_order_value: number;
  voided:          number;
  shifts:          number;
}

export interface AddonSalesRow {
  addon_item_id: string;
  addon_name:    string;
  addon_type:    AddonType;
  quantity_sold: number;
  revenue:       number;
}

export interface BranchComparison {
  branch_id:              string;
  branch_name:            string;
  total_orders:           number;
  voided_orders:          number;
  total_revenue:          number;
  cash_revenue:           number;
  card_revenue:           number;
  digital_wallet_revenue: number;
  mixed_revenue:          number;
  talabat_online_revenue: number;
  talabat_cash_revenue:   number;
  avg_order_value:        number;
  void_rate_pct:          number;
}

export interface OrgComparisonReport {
  org_id:   string;
  from:     string | null;
  to:       string | null;
  branches: BranchComparison[];
}

export interface ShiftSummary {
  shift_id:               string;
  branch_id:              string;
  branch_name:            string;
  teller_id:              string;
  teller_name:            string;
  status:                 ShiftStatus;
  opened_at:              string;
  closed_at:              string | null;
  opening_cash:           number;
  closing_cash_declared:  number | null;
  closing_cash_system:    number | null;
  cash_discrepancy:       number | null;
  total_orders:           number;
  voided_orders:          number;
  total_revenue:          number;
  cash_revenue:           number;
  card_revenue:           number;
  digital_wallet_revenue: number;
  mixed_revenue:          number;
  talabat_online_revenue: number;
  talabat_cash_revenue:   number;
  total_discount:         number;
  total_tax:              number;
}

export interface StockRow {
  inventory_item_id: string;
  item_name:         string;
  unit:              string;
  current_stock:     number;
  reorder_threshold: number;
  cost_per_unit:     number | null;
  below_reorder:     boolean;
  is_active:         boolean;
}

export interface BranchStockReport {
  branch_id:   string;
  branch_name: string;
  items:       StockRow[];
}

export interface InventoryDiscrepancy {
  inventory_item_id: string;
  item_name:         string;
  unit:              string;
  stock_at_open:     number;
  expected_stock:    number;
  actual_count:      number | null;
  discrepancy:       number | null;
  notes:             string | null;
}
TS
ok "src/types/index.ts"

# ===========================================================================
#  src/lib/client.ts  — axios, typed
# ===========================================================================
log "Writing src/lib/client.ts ..."
cat > src/lib/client.ts << 'TS'
import axios, { AxiosError, type AxiosRequestConfig } from "axios";

const client = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? "http://187.124.33.153:8080",
  headers: { "Content-Type": "application/json" },
  timeout: 15_000,
});

client.interceptors.request.use((config) => {
  const token = localStorage.getItem("rue_token");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

client.interceptors.response.use(
  (res) => res,
  (err: AxiosError) => {
    if (err.response?.status === 401) {
      localStorage.removeItem("rue_token");
      localStorage.removeItem("rue_user");
      window.location.href = "/login";
    }
    return Promise.reject(err);
  },
);

export default client;

/** Extract a human-readable error message from an axios error */
export function getErrorMessage(err: unknown): string {
  if (err instanceof AxiosError) {
    const data = err.response?.data as Record<string, unknown> | undefined;
    if (typeof data?.error === "string") return data.error;
    if (typeof data?.message === "string") return data.message;
    return err.message;
  }
  if (err instanceof Error) return err.message;
  return "An unexpected error occurred";
}
TS
ok "src/lib/client.ts"

# ===========================================================================
#  src/lib/query.ts  — TanStack Query client
# ===========================================================================
cat > src/lib/query.ts << 'TS'
import { QueryClient } from "@tanstack/react-query";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry:            1,
      staleTime:        30_000,
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 0,
    },
  },
});
TS
ok "src/lib/query.ts"

# ===========================================================================
#  src/lib/utils.ts  — shadcn cn() helper
# ===========================================================================
cat > src/lib/utils.ts << 'TS'
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
TS
ok "src/lib/utils.ts"

# ===========================================================================
#  src/store/auth.ts
# ===========================================================================
log "Writing src/store/auth.ts ..."
cat > src/store/auth.ts << 'TS'
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
TS
ok "src/store/auth.ts"

# ===========================================================================
#  src/store/app.ts
# ===========================================================================
cat > src/store/app.ts << 'TS'
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
      partialize: (s) => ({
        selectedOrgId:    s.selectedOrgId,
        selectedBranchId: s.selectedBranchId,
        language:         s.language,
      }),
    },
  ),
);
TS
ok "src/store/app.ts"

# ===========================================================================
#  src/utils/format.ts  — all formatters
# ===========================================================================
log "Writing src/utils/format.ts ..."
cat > src/utils/format.ts << 'TS'
import type { PaymentMethod } from "@/types";

// ── Money ─────────────────────────────────────────────────────────────────────
export const egp = (piastres: number = 0): string => {
  const egpValue = piastres / 100;
  return `EGP ${egpValue.toLocaleString("en", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  })}`;
};

export const egpFull = (piastres: number = 0): string => {
  const egpValue = piastres / 100;
  return `EGP ${egpValue.toLocaleString("en", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
};

export const toEGP  = (p: number): string => (p / 100).toFixed(2);
export const toPiastres = (v: string | number): number =>
  Math.round(parseFloat(String(v)) * 100) || 0;

// ── Dates ─────────────────────────────────────────────────────────────────────
export const fmtDate = (iso: string | null | undefined): string => {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-GB", {
    day: "2-digit", month: "short", year: "numeric",
  });
};

export const fmtTime = (iso: string | null | undefined): string => {
  if (!iso) return "—";
  return new Date(iso).toLocaleTimeString("en-GB", {
    hour: "2-digit", minute: "2-digit",
  });
};

export const fmtDateTime = (iso: string | null | undefined): string => {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("en-GB", {
    day: "2-digit", month: "short",
    hour: "2-digit", minute: "2-digit",
  });
};

export const fmtDateTimeFull = (iso: string | null | undefined): string => {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("en-GB", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
};

// ── Duration ──────────────────────────────────────────────────────────────────
export const fmtDuration = (
  start: string | null | undefined,
  end?: string | null,
): string => {
  if (!start) return "—";
  const ms = new Date(end ?? Date.now()).getTime() - new Date(start).getTime();
  const h  = Math.floor(ms / 3_600_000);
  const m  = Math.floor((ms % 3_600_000) / 60_000);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
};

// ── Payment methods ───────────────────────────────────────────────────────────
export const PAYMENT_LABELS: Record<PaymentMethod, string> = {
  cash:           "Cash",
  card:           "Card",
  digital_wallet: "Digital Wallet",
  mixed:          "Mixed",
  talabat_online: "Talabat Online",
  talabat_cash:   "Talabat Cash",
};

export const fmtPayment = (method: string): string =>
  PAYMENT_LABELS[method as PaymentMethod] ??
  method.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

export const PAYMENT_COLORS: Record<PaymentMethod, string> = {
  cash:           "hsl(142 71% 45%)",
  card:           "hsl(221 78% 47%)",
  digital_wallet: "hsl(258 58% 52%)",
  mixed:          "hsl(38 80% 50%)",
  talabat_online: "hsl(22 88% 52%)",
  talabat_cash:   "hsl(22 60% 38%)",
};

export const PAYMENT_BG: Record<PaymentMethod, string> = {
  cash:           "bg-green-50 text-green-700 dark:bg-green-950 dark:text-green-300",
  card:           "bg-blue-50 text-blue-700 dark:bg-blue-950 dark:text-blue-300",
  digital_wallet: "bg-purple-50 text-purple-700 dark:bg-purple-950 dark:text-purple-300",
  mixed:          "bg-amber-50 text-amber-700 dark:bg-amber-950 dark:text-amber-300",
  talabat_online: "bg-orange-50 text-orange-700 dark:bg-orange-950 dark:text-orange-300",
  talabat_cash:   "bg-orange-50 text-orange-800 dark:bg-orange-950 dark:text-orange-400",
};

// ── Roles ─────────────────────────────────────────────────────────────────────
export const ROLE_LABELS: Record<string, string> = {
  super_admin:    "Super Admin",
  org_admin:      "Org Admin",
  branch_manager: "Branch Manager",
  teller:         "Teller",
};

export const fmtRole = (role: string): string =>
  ROLE_LABELS[role] ?? role.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

export const ROLE_COLORS: Record<string, string> = {
  super_admin:    "bg-yellow-50 text-yellow-700 border-yellow-200 dark:bg-yellow-950 dark:text-yellow-300 dark:border-yellow-800",
  org_admin:      "bg-violet-50 text-violet-700 border-violet-200 dark:bg-violet-950 dark:text-violet-300 dark:border-violet-800",
  branch_manager: "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:border-blue-800",
  teller:         "bg-green-50 text-green-700 border-green-200 dark:bg-green-950 dark:text-green-300 dark:border-green-800",
};

// ── Shift status ──────────────────────────────────────────────────────────────
export const SHIFT_STATUS_LABELS: Record<string, string> = {
  open:         "Open",
  closed:       "Closed",
  force_closed: "Force Closed",
};

export const SHIFT_STATUS_COLORS: Record<string, string> = {
  open:         "bg-green-50 text-green-700 border-green-200 dark:bg-green-950 dark:text-green-300",
  closed:       "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950 dark:text-blue-300",
  force_closed: "bg-orange-50 text-orange-700 border-orange-200 dark:bg-orange-950 dark:text-orange-300",
};

// ── Units ─────────────────────────────────────────────────────────────────────
export const UNIT_LABELS: Record<string, string> = {
  g: "g", kg: "kg", ml: "ml", l: "L", pcs: "pcs",
};

export const fmtUnit = (unit: string): string => UNIT_LABELS[unit] ?? unit;

// ── Percentage ────────────────────────────────────────────────────────────────
export const pct = (value: number, total: number): string => {
  if (total === 0) return "0%";
  return `${((value / total) * 100).toFixed(1)}%`;
};

// ── Size labels ───────────────────────────────────────────────────────────────
export const SIZE_LABELS: Record<string, string> = {
  small:       "Small",
  medium:      "Medium",
  large:       "Large",
  extra_large: "X-Large",
  one_size:    "One Size",
};

export const SIZE_SHORT: Record<string, string> = {
  small: "S", medium: "M", large: "L", extra_large: "XL", one_size: "—",
};

export const fmtSize = (size: string): string =>
  SIZE_LABELS[size] ?? size;

// ── Addon type labels ─────────────────────────────────────────────────────────
export const ADDON_TYPE_LABELS: Record<string, string> = {
  coffee_type: "Coffee Type",
  milk_type:   "Milk Type",
  extra:       "Extra",
};

export const fmtAddonType = (type: string): string =>
  ADDON_TYPE_LABELS[type] ?? type;

// ── Normalise name capitalisation ─────────────────────────────────────────────
export const normName = (s: string = ""): string =>
  s.split(" ").map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(" ");

// ── Initials ──────────────────────────────────────────────────────────────────
export const initials = (name: string = ""): string =>
  name
    .split(" ")
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? "")
    .join("");
TS
ok "src/utils/format.ts"

# ===========================================================================
#  src/api/  — all API files, fully typed
# ===========================================================================
log "Writing API files ..."

cat > src/api/auth.ts << 'TS'
import client from "@/lib/client";
import type { LoginResponse, UserPublic } from "@/types";

export const login = (data: { email?: string; password?: string; pin?: string; name?: string }) =>
  client.post<LoginResponse>("/auth/login", data);

export const getMe = () =>
  client.get<{ user: UserPublic }>("/auth/me");
TS

cat > src/api/orgs.ts << 'TS'
import client from "@/lib/client";
import type { Org } from "@/types";

export const getOrgs  = ()       => client.get<Org[]>("/orgs");
export const getOrg   = (id: string) => client.get<Org>(`/orgs/${id}`);
export const createOrg = (data: {
  name: string; slug: string;
  currency_code?: string; tax_rate?: number; receipt_footer?: string;
}) => client.post<Org>("/orgs", data);
TS

cat > src/api/branches.ts << 'TS'
import client from "@/lib/client";
import type { Branch } from "@/types";

export const getBranches  = (orgId: string)          => client.get<Branch[]>("/branches", { params: { org_id: orgId } });
export const getBranch    = (id: string)             => client.get<Branch>(`/branches/${id}`);
export const createBranch = (data: Partial<Branch> & { org_id: string; name: string }) =>
  client.post<Branch>("/branches", data);
export const updateBranch = (id: string, data: Partial<Branch> & {
  printer_brand?: string | null;
  printer_ip?:    string | null;
  printer_port?:  number | null;
}) => client.put<Branch>(`/branches/${id}`, data);
export const deleteBranch = (id: string) => client.delete(`/branches/${id}`);
TS

cat > src/api/users.ts << 'TS'
import client from "@/lib/client";
import type { UserPublic, UserBranch } from "@/types";

export const getUsers       = (orgId?: string | null) =>
  client.get<UserPublic[]>("/users", { params: orgId ? { org_id: orgId } : {} });
export const getUser        = (id: string)            => client.get<UserPublic>(`/users/${id}`);
export const createUser     = (data: Record<string, unknown>) => client.post<{ user: UserPublic }>("/users", data);
export const updateUser     = (id: string, data: Record<string, unknown>) => client.patch<UserPublic>(`/users/${id}`, data);
export const deleteUser     = (id: string)            => client.delete(`/users/${id}`);
export const assignBranch   = (userId: string, branchId: string) =>
  client.post(`/users/${userId}/branches`, { branch_id: branchId });
export const unassignBranch = (userId: string, branchId: string) =>
  client.delete(`/users/${userId}/branches/${branchId}`);
export const getUserBranches = (userId: string) =>
  client.get<UserBranch[]>(`/users/${userId}/branches`);
TS

cat > src/api/permissions.ts << 'TS'
import client from "@/lib/client";
import type { Permission, RolePermission, PermissionMatrix } from "@/types";

export const getMatrix           = (userId: string) => client.get<PermissionMatrix[]>(`/permissions/matrix/${userId}`);
export const getUserPermissions  = (userId: string) => client.get<Permission[]>(`/permissions/user/${userId}`);
export const upsertPermission    = (userId: string, data: { resource: string; action: string; granted: boolean }) =>
  client.put<Permission>(`/permissions/user/${userId}`, data);
export const deletePermission    = (userId: string, resource: string, action: string) =>
  client.delete(`/permissions/user/${userId}/${resource}/${action}`);
export const getRolePermissions  = ()     => client.get<RolePermission[]>("/permissions/roles");
export const upsertRolePermission = (data: { role: string; resource: string; action: string; granted: boolean }) =>
  client.put<RolePermission>("/permissions/roles", data);
TS

cat > src/api/menu.ts << 'TS'
import client from "@/lib/client";
import type { Category, MenuItem, MenuItemFull, AddonItem, DrinkOptionGroupFull, ItemSize } from "@/types";

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

// Option groups
export const getOptionGroups   = (itemId: string)                             => client.get<DrinkOptionGroupFull[]>(`/menu-items/${itemId}/option-groups`);
export const createOptionGroup = (itemId: string, data: Record<string, unknown>) => client.post(`/menu-items/${itemId}/option-groups`, data);
export const updateOptionGroup = (itemId: string, gid: string, data: Record<string, unknown>) => client.patch(`/menu-items/${itemId}/option-groups/${gid}`, data);
export const deleteOptionGroup = (itemId: string, gid: string)                => client.delete(`/menu-items/${itemId}/option-groups/${gid}`);

// Option items
export const addOptionItem    = (itemId: string, gid: string, data: Record<string, unknown>) => client.post(`/menu-items/${itemId}/option-groups/${gid}/items`, data);
export const updateOptionItem = (itemId: string, gid: string, oid: string, data: Record<string, unknown>) => client.patch(`/menu-items/${itemId}/option-groups/${gid}/items/${oid}`, data);
export const deleteOptionItem = (itemId: string, gid: string, oid: string)   => client.delete(`/menu-items/${itemId}/option-groups/${gid}/items/${oid}`);

// Sizes
export const upsertSize = (itemId: string, data: { label: string; price_override: number; display_order?: number }) =>
  client.post<ItemSize>(`/menu-items/${itemId}/sizes`, data);
export const deleteSize = (itemId: string, sid: string) => client.delete(`/menu-items/${itemId}/sizes/${sid}`);
TS

cat > src/api/inventory.ts << 'TS'
import client from "@/lib/client";
import type { InventoryItem, InventoryAdjustment, InventoryTransfer, ServePool, SoftServeBatch } from "@/types";

// Items
export const getInventoryItems   = (branchId: string)             => client.get<InventoryItem[]>(`/inventory/branches/${branchId}/items`);
export const createInventoryItem = (branchId: string, data: Record<string, unknown>) => client.post<InventoryItem>(`/inventory/branches/${branchId}/items`, data);
export const updateInventoryItem = (id: string, data: Record<string, unknown>) => client.patch<InventoryItem>(`/inventory/items/${id}`, data);
export const deleteInventoryItem = (id: string)                   => client.delete(`/inventory/items/${id}`);

// Adjustments
export const getAdjustments   = (branchId: string)             => client.get<InventoryAdjustment[]>(`/inventory/branches/${branchId}/adjustments`);
export const createAdjustment = (branchId: string, data: Record<string, unknown>) => client.post<InventoryAdjustment>(`/inventory/branches/${branchId}/adjustments`, data);

// Transfers
export const getTransfers    = (branchId: string, direction?: string) =>
  client.get<InventoryTransfer[]>(`/inventory/branches/${branchId}/transfers`, { params: direction ? { direction } : {} });
export const createTransfer  = (data: Record<string, unknown>) => client.post<InventoryTransfer>("/inventory/transfers", data);
export const getTransfer     = (id: string)                    => client.get<InventoryTransfer>(`/inventory/transfers/${id}`);
export const confirmTransfer = (id: string, data: Record<string, unknown>) => client.patch<InventoryTransfer>(`/inventory/transfers/${id}/confirm`, data);
export const rejectTransfer  = (id: string, data: Record<string, unknown>) => client.patch<InventoryTransfer>(`/inventory/transfers/${id}/reject`, data);

// Soft serve
export const getSoftServePools   = (branchId: string)             => client.get<ServePool[]>(`/soft-serve/branches/${branchId}/pools`);
export const getSoftServeBatches = (branchId: string)             => client.get<SoftServeBatch[]>(`/soft-serve/branches/${branchId}/batches`);
export const createSoftServeBatch = (branchId: string, data: Record<string, unknown>) => client.post(`/soft-serve/branches/${branchId}/batches`, data);
TS

cat > src/api/recipes.ts << 'TS'
import client from "@/lib/client";
import type { DrinkRecipe, AddonIngredient, DrinkOptionOverride } from "@/types";

export const getDrinkRecipes     = (menuItemId: string)                                    => client.get<DrinkRecipe[]>(`/recipes/drinks/${menuItemId}`);
export const upsertDrinkRecipe   = (menuItemId: string, data: Record<string, unknown>)     => client.post<DrinkRecipe>(`/recipes/drinks/${menuItemId}`, data);
export const deleteDrinkRecipe   = (menuItemId: string, size: string, invId: string)       => client.delete(`/recipes/drinks/${menuItemId}/${size}/${invId}`);

export const getAddonIngredients   = (addonItemId: string)                                 => client.get<AddonIngredient[]>(`/recipes/addons/${addonItemId}`);
export const upsertAddonIngredient = (addonItemId: string, data: Record<string, unknown>)  => client.post<AddonIngredient>(`/recipes/addons/${addonItemId}`, data);
export const deleteAddonIngredient = (addonItemId: string, invId: string)                  => client.delete(`/recipes/addons/${addonItemId}/${invId}`);

export const getOverrides   = (drinkOptionItemId: string)                                  => client.get<DrinkOptionOverride[]>(`/recipes/overrides/${drinkOptionItemId}`);
export const upsertOverride = (drinkOptionItemId: string, data: Record<string, unknown>)   => client.post<DrinkOptionOverride>(`/recipes/overrides/${drinkOptionItemId}`, data);
export const deleteOverride = (drinkOptionItemId: string, invId: string, size?: string)    =>
  client.delete(`/recipes/overrides/${drinkOptionItemId}/${invId}`, { params: size ? { size } : {} });
TS

cat > src/api/shifts.ts << 'TS'
import client from "@/lib/client";
import type { Shift, ShiftPreFill, CashMovement, ShiftReport } from "@/types";

export const getCurrentShift  = (branchId: string)             => client.get<ShiftPreFill>(`/shifts/branches/${branchId}/current`);
export const getBranchShifts  = (branchId: string)             => client.get<Shift[]>(`/shifts/branches/${branchId}`);
export const getShift         = (id: string)                   => client.get<Shift>(`/shifts/${id}`);
export const openShift        = (branchId: string, data: Record<string, unknown>) => client.post<Shift>(`/shifts/branches/${branchId}/open`, data);
export const closeShift       = (id: string, data: Record<string, unknown>) => client.post(`/shifts/${id}/close`, data);
export const forceCloseShift  = (id: string, data: Record<string, unknown>) => client.post<Shift>(`/shifts/${id}/force-close`, data);
export const getCashMovements = (id: string)                   => client.get<CashMovement[]>(`/shifts/${id}/cash-movements`);
export const addCashMovement  = (id: string, data: Record<string, unknown>) => client.post<CashMovement>(`/shifts/${id}/cash-movements`, data);
export const getShiftReport   = (id: string)                   => client.get<ShiftReport>(`/shifts/${id}/report`);
TS

cat > src/api/orders.ts << 'TS'
import client from "@/lib/client";
import type { Order } from "@/types";

export const getOrders   = (params: Record<string, unknown>) => client.get<Order[]>("/orders", { params });
export const getOrder    = (id: string)                      => client.get<Order>(`/orders/${id}`);
export const createOrder = (data: Record<string, unknown>)  => client.post<Order>("/orders", data);
export const voidOrder   = (id: string, data: Record<string, unknown>) => client.post<Order>(`/orders/${id}/void`, data);
TS

cat > src/api/reports.ts << 'TS'
import client from "@/lib/client";
import type {
  ShiftSummary, BranchSalesReport, BranchStockReport,
  TimeseriesPoint, TellerStats, AddonSalesRow,
  OrgComparisonReport, InventoryDiscrepancy,
} from "@/types";

export const getShiftSummary    = (shiftId: string)          => client.get<ShiftSummary>(`/reports/shifts/${shiftId}/summary`);
export const getShiftInventory  = (shiftId: string)          => client.get<InventoryDiscrepancy[]>(`/reports/shifts/${shiftId}/inventory`);
export const getBranchSales     = (branchId: string, params: Record<string, unknown>) =>
  client.get<BranchSalesReport>(`/reports/branches/${branchId}/sales`, { params });
export const getBranchTimeseries = (branchId: string, params: Record<string, unknown>) =>
  client.get<TimeseriesPoint[]>(`/reports/branches/${branchId}/sales/timeseries`, { params });
export const getBranchTellers   = (branchId: string, params: Record<string, unknown>) =>
  client.get<TellerStats[]>(`/reports/branches/${branchId}/tellers`, { params });
export const getBranchAddonSales = (branchId: string, params: Record<string, unknown>) =>
  client.get<AddonSalesRow[]>(`/reports/branches/${branchId}/addons`, { params });
export const getBranchStock     = (branchId: string)         => client.get<BranchStockReport>(`/reports/branches/${branchId}/stock`);
export const getOrgComparison   = (orgId: string, params: Record<string, unknown>) =>
  client.get<OrgComparisonReport>(`/reports/orgs/${orgId}/comparison`, { params });
TS

ok "API files"

# ===========================================================================
#  src/components/ui/  — shadcn primitives
# ===========================================================================
log "Writing shadcn UI components ..."

cat > src/components/ui/button.tsx << 'TSX'
import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-xl text-sm font-semibold ring-offset-background transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0 active:scale-[0.98]",
  {
    variants: {
      variant: {
        default:     "brand-gradient text-white shadow hover:opacity-90",
        destructive: "bg-destructive text-destructive-foreground shadow hover:bg-destructive/90",
        outline:     "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
        secondary:   "bg-secondary text-secondary-foreground hover:bg-secondary/80",
        ghost:       "hover:bg-accent hover:text-accent-foreground",
        link:        "text-primary underline-offset-4 hover:underline",
        success:     "bg-green-600 text-white shadow hover:bg-green-700",
        warning:     "bg-amber-500 text-white shadow hover:bg-amber-600",
      },
      size: {
        default: "h-10 px-4 py-2",
        sm:      "h-8 rounded-lg px-3 text-xs",
        lg:      "h-12 rounded-xl px-6 text-base",
        icon:    "h-9 w-9",
        "icon-sm": "h-7 w-7",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
  loading?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, loading, children, disabled, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        disabled={disabled || loading}
        {...props}
      >
        {loading ? (
          <>
            <span className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin flex-shrink-0" />
            {children}
          </>
        ) : children}
      </Comp>
    );
  },
);
Button.displayName = "Button";

export { Button, buttonVariants };
TSX

cat > src/components/ui/badge.tsx << 'TSX'
import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
  {
    variants: {
      variant: {
        default:     "border-transparent brand-gradient text-white",
        secondary:   "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80",
        destructive: "border-transparent bg-destructive/10 text-destructive border-destructive/20",
        outline:     "text-foreground",
        success:     "border-transparent bg-green-50 text-green-700 border-green-200 dark:bg-green-950 dark:text-green-300 dark:border-green-800",
        warning:     "border-transparent bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950 dark:text-amber-300 dark:border-amber-800",
        info:        "border-transparent bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:border-blue-800",
      },
    },
    defaultVariants: { variant: "default" },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />;
}

export { Badge, badgeVariants };
TSX

cat > src/components/ui/input.tsx << 'TSX'
import * as React from "react";
import { cn } from "@/lib/utils";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, ...props }, ref) => (
    <input
      type={type}
      className={cn(
        "flex h-10 w-full rounded-xl border border-input bg-background px-3 py-2 text-sm ring-offset-background",
        "file:border-0 file:bg-transparent file:text-sm file:font-medium",
        "placeholder:text-muted-foreground",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
        "disabled:cursor-not-allowed disabled:opacity-50",
        "transition-colors",
        className,
      )}
      ref={ref}
      {...props}
    />
  ),
);
Input.displayName = "Input";

export { Input };
TSX

cat > src/components/ui/label.tsx << 'TSX'
import * as React from "react";
import * as LabelPrimitive from "@radix-ui/react-label";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const labelVariants = cva(
  "text-xs font-semibold uppercase tracking-wide text-muted-foreground leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70",
);

const Label = React.forwardRef<
  React.ElementRef<typeof LabelPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof LabelPrimitive.Root> & VariantProps<typeof labelVariants>
>(({ className, ...props }, ref) => (
  <LabelPrimitive.Root ref={ref} className={cn(labelVariants(), className)} {...props} />
));
Label.displayName = LabelPrimitive.Root.displayName;

export { Label };
TSX

cat > src/components/ui/select.tsx << 'TSX'
import * as React from "react";
import * as SelectPrimitive from "@radix-ui/react-select";
import { Check, ChevronDown, ChevronUp } from "lucide-react";
import { cn } from "@/lib/utils";

const Select       = SelectPrimitive.Root;
const SelectGroup  = SelectPrimitive.Group;
const SelectValue  = SelectPrimitive.Value;

const SelectTrigger = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.Trigger>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Trigger>
>(({ className, children, ...props }, ref) => (
  <SelectPrimitive.Trigger
    ref={ref}
    className={cn(
      "flex h-10 w-full items-center justify-between rounded-xl border border-input bg-background px-3 py-2 text-sm ring-offset-background",
      "placeholder:text-muted-foreground",
      "focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
      "disabled:cursor-not-allowed disabled:opacity-50",
      "[&>span]:line-clamp-1 transition-colors",
      className,
    )}
    {...props}
  >
    {children}
    <SelectPrimitive.Icon asChild>
      <ChevronDown className="h-4 w-4 opacity-50" />
    </SelectPrimitive.Icon>
  </SelectPrimitive.Trigger>
));
SelectTrigger.displayName = SelectPrimitive.Trigger.displayName;

const SelectScrollUpButton = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.ScrollUpButton>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.ScrollUpButton>
>(({ className, ...props }, ref) => (
  <SelectPrimitive.ScrollUpButton
    ref={ref}
    className={cn("flex cursor-default items-center justify-center py-1", className)}
    {...props}
  >
    <ChevronUp className="h-4 w-4" />
  </SelectPrimitive.ScrollUpButton>
));
SelectScrollUpButton.displayName = SelectPrimitive.ScrollUpButton.displayName;

const SelectScrollDownButton = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.ScrollDownButton>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.ScrollDownButton>
>(({ className, ...props }, ref) => (
  <SelectPrimitive.ScrollDownButton
    ref={ref}
    className={cn("flex cursor-default items-center justify-center py-1", className)}
    {...props}
  >
    <ChevronDown className="h-4 w-4" />
  </SelectPrimitive.ScrollDownButton>
));
SelectScrollDownButton.displayName = SelectPrimitive.ScrollDownButton.displayName;

const SelectContent = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Content>
>(({ className, children, position = "popper", ...props }, ref) => (
  <SelectPrimitive.Portal>
    <SelectPrimitive.Content
      ref={ref}
      className={cn(
        "relative z-50 max-h-96 min-w-[8rem] overflow-hidden rounded-xl border bg-popover text-popover-foreground shadow-md",
        "data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
        "data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95",
        "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2",
        "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",
        position === "popper" &&
          "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1",
        className,
      )}
      position={position}
      {...props}
    >
      <SelectScrollUpButton />
      <SelectPrimitive.Viewport
        className={cn(
          "p-1",
          position === "popper" &&
            "h-[var(--radix-select-trigger-height)] w-full min-w-[var(--radix-select-trigger-width)]",
        )}
      >
        {children}
      </SelectPrimitive.Viewport>
      <SelectScrollDownButton />
    </SelectPrimitive.Content>
  </SelectPrimitive.Portal>
));
SelectContent.displayName = SelectPrimitive.Content.displayName;

const SelectLabel = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.Label>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Label>
>(({ className, ...props }, ref) => (
  <SelectPrimitive.Label
    ref={ref}
    className={cn("py-1.5 pl-8 pr-2 text-xs font-semibold text-muted-foreground uppercase tracking-wide", className)}
    {...props}
  />
));
SelectLabel.displayName = SelectPrimitive.Label.displayName;

const SelectItem = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.Item>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Item>
>(({ className, children, ...props }, ref) => (
  <SelectPrimitive.Item
    ref={ref}
    className={cn(
      "relative flex w-full cursor-default select-none items-center rounded-lg py-2 pl-8 pr-2 text-sm outline-none",
      "focus:bg-accent focus:text-accent-foreground",
      "data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
      className,
    )}
    {...props}
  >
    <span className="absolute left-2 flex h-3.5 w-3.5 items-center justify-center">
      <SelectPrimitive.ItemIndicator>
        <Check className="h-4 w-4" />
      </SelectPrimitive.ItemIndicator>
    </span>
    <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
  </SelectPrimitive.Item>
));
SelectItem.displayName = SelectPrimitive.Item.displayName;

const SelectSeparator = React.forwardRef<
  React.ElementRef<typeof SelectPrimitive.Separator>,
  React.ComponentPropsWithoutRef<typeof SelectPrimitive.Separator>
>(({ className, ...props }, ref) => (
  <SelectPrimitive.Separator
    ref={ref}
    className={cn("-mx-1 my-1 h-px bg-muted", className)}
    {...props}
  />
));
SelectSeparator.displayName = SelectPrimitive.Separator.displayName;

export {
  Select, SelectGroup, SelectValue, SelectTrigger, SelectContent,
  SelectLabel, SelectItem, SelectSeparator,
  SelectScrollUpButton, SelectScrollDownButton,
};
TSX

cat > src/components/ui/dialog.tsx << 'TSX'
import * as React from "react";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { X } from "lucide-react";
import { cn } from "@/lib/utils";

const Dialog       = DialogPrimitive.Root;
const DialogTrigger = DialogPrimitive.Trigger;
const DialogPortal  = DialogPrimitive.Portal;
const DialogClose   = DialogPrimitive.Close;

const DialogOverlay = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Overlay>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Overlay>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Overlay
    ref={ref}
    className={cn(
      "fixed inset-0 z-50 bg-black/40 backdrop-blur-sm",
      "data-[state=open]:animate-in data-[state=closed]:animate-out",
      "data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
      className,
    )}
    {...props}
  />
));
DialogOverlay.displayName = DialogPrimitive.Overlay.displayName;

const DialogContent = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Content> & {
    showClose?: boolean;
    sheet?: "bottom" | "right";
  }
>(({ className, children, showClose = true, sheet, ...props }, ref) => (
  <DialogPortal>
    <DialogOverlay />
    <DialogPrimitive.Content
      ref={ref}
      className={cn(
        "fixed z-50 bg-background shadow-lg duration-200",
        // Default centered modal
        !sheet && [
          "left-[50%] top-[50%] translate-x-[-50%] translate-y-[-50%]",
          "w-full max-w-lg max-h-[90dvh] overflow-y-auto",
          "rounded-2xl border",
          "data-[state=open]:animate-in data-[state=closed]:animate-out",
          "data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
          "data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95",
          "data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%]",
          "data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%]",
          // Mobile: slide up from bottom
          "max-sm:top-auto max-sm:bottom-0 max-sm:left-0 max-sm:right-0 max-sm:translate-x-0 max-sm:translate-y-0 max-sm:rounded-b-none max-sm:max-w-full",
        ],
        // Bottom sheet
        sheet === "bottom" && [
          "bottom-0 left-0 right-0 rounded-t-2xl border-t max-h-[85dvh] overflow-y-auto",
          "data-[state=open]:animate-in data-[state=closed]:animate-out",
          "data-[state=closed]:slide-out-to-bottom data-[state=open]:slide-in-from-bottom",
        ],
        // Right drawer
        sheet === "right" && [
          "right-0 top-0 bottom-0 w-[min(90vw,560px)] rounded-l-2xl border-l overflow-y-auto",
          "data-[state=open]:animate-slide-in-right data-[state=closed]:animate-out",
          "data-[state=closed]:slide-out-to-right",
        ],
        className,
      )}
      {...props}
    >
      {children}
      {showClose && (
        <DialogPrimitive.Close className="absolute right-4 top-4 rounded-lg opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:pointer-events-none data-[state=open]:bg-accent data-[state=open]:text-muted-foreground">
          <X className="h-4 w-4" />
          <span className="sr-only">Close</span>
        </DialogPrimitive.Close>
      )}
    </DialogPrimitive.Content>
  </DialogPortal>
));
DialogContent.displayName = DialogPrimitive.Content.displayName;

const DialogHeader = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn("flex flex-col gap-1.5 p-6 pb-0", className)} {...props} />
);
DialogHeader.displayName = "DialogHeader";

const DialogFooter = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn("flex flex-col-reverse gap-2 p-6 pt-0 sm:flex-row sm:justify-end", className)} {...props} />
);
DialogFooter.displayName = "DialogFooter";

const DialogTitle = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Title>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Title>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Title
    ref={ref}
    className={cn("text-lg font-bold leading-none tracking-tight", className)}
    {...props}
  />
));
DialogTitle.displayName = DialogPrimitive.Title.displayName;

const DialogDescription = React.forwardRef<
  React.ElementRef<typeof DialogPrimitive.Description>,
  React.ComponentPropsWithoutRef<typeof DialogPrimitive.Description>
>(({ className, ...props }, ref) => (
  <DialogPrimitive.Description
    ref={ref}
    className={cn("text-sm text-muted-foreground", className)}
    {...props}
  />
));
DialogDescription.displayName = DialogPrimitive.Description.displayName;

export {
  Dialog, DialogPortal, DialogOverlay, DialogClose, DialogTrigger,
  DialogContent, DialogHeader, DialogFooter, DialogTitle, DialogDescription,
};
TSX

cat > src/components/ui/tabs.tsx << 'TSX'
import * as React from "react";
import * as TabsPrimitive from "@radix-ui/react-tabs";
import { cn } from "@/lib/utils";

const Tabs      = TabsPrimitive.Root;
const TabsList = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.List>,
  React.ComponentPropsWithoutRef<typeof TabsPrimitive.List>
>(({ className, ...props }, ref) => (
  <TabsPrimitive.List
    ref={ref}
    className={cn(
      "inline-flex h-10 items-center justify-center rounded-xl bg-muted p-1 text-muted-foreground",
      className,
    )}
    {...props}
  />
));
TabsList.displayName = TabsPrimitive.List.displayName;

const TabsTrigger = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.Trigger>,
  React.ComponentPropsWithoutRef<typeof TabsPrimitive.Trigger>
>(({ className, ...props }, ref) => (
  <TabsPrimitive.Trigger
    ref={ref}
    className={cn(
      "inline-flex items-center justify-center gap-1.5 whitespace-nowrap rounded-lg px-3 py-1.5 text-sm font-medium ring-offset-background transition-all",
      "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
      "disabled:pointer-events-none disabled:opacity-50",
      "data-[state=active]:bg-background data-[state=active]:text-foreground data-[state=active]:shadow-sm",
      className,
    )}
    {...props}
  />
));
TabsTrigger.displayName = TabsPrimitive.Trigger.displayName;

const TabsContent = React.forwardRef<
  React.ElementRef<typeof TabsPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof TabsPrimitive.Content>
>(({ className, ...props }, ref) => (
  <TabsPrimitive.Content
    ref={ref}
    className={cn(
      "mt-4 ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
      className,
    )}
    {...props}
  />
));
TabsContent.displayName = TabsPrimitive.Content.displayName;

export { Tabs, TabsList, TabsTrigger, TabsContent };
TSX

cat > src/components/ui/skeleton.tsx << 'TSX'
import { cn } from "@/lib/utils";

function Skeleton({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn("animate-pulse rounded-lg bg-muted", className)}
      {...props}
    />
  );
}

export { Skeleton };
TSX

cat > src/components/ui/separator.tsx << 'TSX'
import * as React from "react";
import * as SeparatorPrimitive from "@radix-ui/react-separator";
import { cn } from "@/lib/utils";

const Separator = React.forwardRef<
  React.ElementRef<typeof SeparatorPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof SeparatorPrimitive.Root>
>(({ className, orientation = "horizontal", decorative = true, ...props }, ref) => (
  <SeparatorPrimitive.Root
    ref={ref}
    decorative={decorative}
    orientation={orientation}
    className={cn(
      "shrink-0 bg-border",
      orientation === "horizontal" ? "h-[1px] w-full" : "h-full w-[1px]",
      className,
    )}
    {...props}
  />
));
Separator.displayName = SeparatorPrimitive.Root.displayName;

export { Separator };
TSX

cat > src/components/ui/tooltip.tsx << 'TSX'
import * as React from "react";
import * as TooltipPrimitive from "@radix-ui/react-tooltip";
import { cn } from "@/lib/utils";

const TooltipProvider = TooltipPrimitive.Provider;
const Tooltip         = TooltipPrimitive.Root;
const TooltipTrigger  = TooltipPrimitive.Trigger;

const TooltipContent = React.forwardRef<
  React.ElementRef<typeof TooltipPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof TooltipPrimitive.Content>
>(({ className, sideOffset = 4, ...props }, ref) => (
  <TooltipPrimitive.Content
    ref={ref}
    sideOffset={sideOffset}
    className={cn(
      "z-50 overflow-hidden rounded-lg border bg-popover px-3 py-1.5 text-xs font-medium text-popover-foreground shadow-md",
      "animate-in fade-in-0 zoom-in-95",
      "data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95",
      "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2",
      "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",
      className,
    )}
    {...props}
  />
));
TooltipContent.displayName = TooltipPrimitive.Content.displayName;

export { Tooltip, TooltipTrigger, TooltipContent, TooltipProvider };
TSX

cat > src/components/ui/switch.tsx << 'TSX'
import * as React from "react";
import * as SwitchPrimitives from "@radix-ui/react-switch";
import { cn } from "@/lib/utils";

const Switch = React.forwardRef<
  React.ElementRef<typeof SwitchPrimitives.Root>,
  React.ComponentPropsWithoutRef<typeof SwitchPrimitives.Root>
>(({ className, ...props }, ref) => (
  <SwitchPrimitives.Root
    className={cn(
      "peer inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent",
      "shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
      "disabled:cursor-not-allowed disabled:opacity-50",
      "data-[state=checked]:bg-primary data-[state=unchecked]:bg-input",
      className,
    )}
    {...props}
    ref={ref}
  >
    <SwitchPrimitives.Thumb
      className={cn(
        "pointer-events-none block h-4 w-4 rounded-full bg-background shadow-lg ring-0 transition-transform",
        "data-[state=checked]:translate-x-4 data-[state=unchecked]:translate-x-0",
      )}
    />
  </SwitchPrimitives.Root>
));
Switch.displayName = SwitchPrimitives.Root.displayName;

export { Switch };
TSX

cat > src/components/ui/checkbox.tsx << 'TSX'
import * as React from "react";
import * as CheckboxPrimitive from "@radix-ui/react-checkbox";
import { Check } from "lucide-react";
import { cn } from "@/lib/utils";

const Checkbox = React.forwardRef<
  React.ElementRef<typeof CheckboxPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof CheckboxPrimitive.Root>
>(({ className, ...props }, ref) => (
  <CheckboxPrimitive.Root
    ref={ref}
    className={cn(
      "peer h-4 w-4 shrink-0 rounded border border-primary shadow",
      "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring",
      "disabled:cursor-not-allowed disabled:opacity-50",
      "data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground",
      className,
    )}
    {...props}
  >
    <CheckboxPrimitive.Indicator className={cn("flex items-center justify-center text-current")}>
      <Check className="h-3 w-3" />
    </CheckboxPrimitive.Indicator>
  </CheckboxPrimitive.Root>
));
Checkbox.displayName = CheckboxPrimitive.Root.displayName;

export { Checkbox };
TSX

cat > src/components/ui/dropdown-menu.tsx << 'TSX'
import * as React from "react";
import * as DropdownMenuPrimitive from "@radix-ui/react-dropdown-menu";
import { Check, ChevronRight, Circle } from "lucide-react";
import { cn } from "@/lib/utils";

const DropdownMenu          = DropdownMenuPrimitive.Root;
const DropdownMenuTrigger   = DropdownMenuPrimitive.Trigger;
const DropdownMenuGroup     = DropdownMenuPrimitive.Group;
const DropdownMenuPortal    = DropdownMenuPrimitive.Portal;
const DropdownMenuSub       = DropdownMenuPrimitive.Sub;
const DropdownMenuRadioGroup = DropdownMenuPrimitive.RadioGroup;

const DropdownMenuSubTrigger = React.forwardRef<
  React.ElementRef<typeof DropdownMenuPrimitive.SubTrigger>,
  React.ComponentPropsWithoutRef<typeof DropdownMenuPrimitive.SubTrigger> & { inset?: boolean }
>(({ className, inset, children, ...props }, ref) => (
  <DropdownMenuPrimitive.SubTrigger
    ref={ref}
    className={cn(
      "flex cursor-default select-none items-center gap-2 rounded-lg px-2 py-1.5 text-sm outline-none focus:bg-accent data-[state=open]:bg-accent [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
      inset && "pl-8",
      className,
    )}
    {...props}
  >
    {children}
    <ChevronRight className="ml-auto" />
  </DropdownMenuPrimitive.SubTrigger>
));
DropdownMenuSubTrigger.displayName = DropdownMenuPrimitive.SubTrigger.displayName;

const DropdownMenuSubContent = React.forwardRef<
  React.ElementRef<typeof DropdownMenuPrimitive.SubContent>,
  React.ComponentPropsWithoutRef<typeof DropdownMenuPrimitive.SubContent>
>(({ className, ...props }, ref) => (
  <DropdownMenuPrimitive.SubContent
    ref={ref}
    className={cn(
      "z-50 min-w-[8rem] overflow-hidden rounded-xl border bg-popover p-1 text-popover-foreground shadow-lg",
      "data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
      "data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2",
      "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",
      className,
    )}
    {...props}
  />
));
DropdownMenuSubContent.displayName = DropdownMenuPrimitive.SubContent.displayName;

const DropdownMenuContent = React.forwardRef<
  React.ElementRef<typeof DropdownMenuPrimitive.Content>,
  React.ComponentPropsWithoutRef<typeof DropdownMenuPrimitive.Content>
>(({ className, sideOffset = 4, ...props }, ref) => (
  <DropdownMenuPrimitive.Portal>
    <DropdownMenuPrimitive.Content
      ref={ref}
      sideOffset={sideOffset}
      className={cn(
        "z-50 min-w-[8rem] overflow-hidden rounded-xl border bg-popover p-1 text-popover-foreground shadow-md",
        "data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0",
        "data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2",
        "data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2",
        className,
      )}
      {...props}
    />
  </DropdownMenuPrimitive.Portal>
));
DropdownMenuContent.displayName = DropdownMenuPrimitive.Content.displayName;

const DropdownMenuItem = React.forwardRef<
  React.ElementRef<typeof DropdownMenuPrimitive.Item>,
  React.ComponentPropsWithoutRef<typeof DropdownMenuPrimitive.Item> & { inset?: boolean }
>(({ className, inset, ...props }, ref) => (
  <DropdownMenuPrimitive.Item
    ref={ref}
    className={cn(
      "relative flex cursor-default select-none items-center gap-2 rounded-lg px-2 py-1.5 text-sm outline-none transition-colors",
      "focus:bg-accent focus:text-accent-foreground",
      "data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
      "[&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
      inset && "pl-8",
      className,
    )}
    {...props}
  />
));
DropdownMenuItem.displayName = DropdownMenuPrimitive.Item.displayName;

const DropdownMenuLabel = React.forwardRef<
  React.ElementRef<typeof DropdownMenuPrimitive.Label>,
  React.ComponentPropsWithoutRef<typeof DropdownMenuPrimitive.Label> & { inset?: boolean }
>(({ className, inset, ...props }, ref) => (
  <DropdownMenuPrimitive.Label
    ref={ref}
    className={cn("px-2 py-1.5 text-xs font-semibold text-muted-foreground uppercase tracking-wide", inset && "pl-8", className)}
    {...props}
  />
));
DropdownMenuLabel.displayName = DropdownMenuPrimitive.Label.displayName;

const DropdownMenuSeparator = React.forwardRef<
  React.ElementRef<typeof DropdownMenuPrimitive.Separator>,
  React.ComponentPropsWithoutRef<typeof DropdownMenuPrimitive.Separator>
>(({ className, ...props }, ref) => (
  <DropdownMenuPrimitive.Separator
    ref={ref}
    className={cn("-mx-1 my-1 h-px bg-border", className)}
    {...props}
  />
));
DropdownMenuSeparator.displayName = DropdownMenuPrimitive.Separator.displayName;

export {
  DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem,
  DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuGroup, DropdownMenuPortal,
  DropdownMenuSub, DropdownMenuSubContent, DropdownMenuSubTrigger, DropdownMenuRadioGroup,
};
TSX

cat > src/components/ui/avatar.tsx << 'TSX'
import * as React from "react";
import * as AvatarPrimitive from "@radix-ui/react-avatar";
import { cn } from "@/lib/utils";

const Avatar = React.forwardRef<
  React.ElementRef<typeof AvatarPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof AvatarPrimitive.Root>
>(({ className, ...props }, ref) => (
  <AvatarPrimitive.Root
    ref={ref}
    className={cn("relative flex h-9 w-9 shrink-0 overflow-hidden rounded-full", className)}
    {...props}
  />
));
Avatar.displayName = AvatarPrimitive.Root.displayName;

const AvatarImage = React.forwardRef<
  React.ElementRef<typeof AvatarPrimitive.Image>,
  React.ComponentPropsWithoutRef<typeof AvatarPrimitive.Image>
>(({ className, ...props }, ref) => (
  <AvatarPrimitive.Image ref={ref} className={cn("aspect-square h-full w-full", className)} {...props} />
));
AvatarImage.displayName = AvatarPrimitive.Image.displayName;

const AvatarFallback = React.forwardRef<
  React.ElementRef<typeof AvatarPrimitive.Fallback>,
  React.ComponentPropsWithoutRef<typeof AvatarPrimitive.Fallback>
>(({ className, ...props }, ref) => (
  <AvatarPrimitive.Fallback
    ref={ref}
    className={cn(
      "flex h-full w-full items-center justify-center rounded-full brand-gradient text-white text-sm font-bold",
      className,
    )}
    {...props}
  />
));
AvatarFallback.displayName = AvatarPrimitive.Fallback.displayName;

export { Avatar, AvatarImage, AvatarFallback };
TSX

cat > src/components/ui/progress.tsx << 'TSX'
import * as React from "react";
import * as ProgressPrimitive from "@radix-ui/react-progress";
import { cn } from "@/lib/utils";

const Progress = React.forwardRef<
  React.ElementRef<typeof ProgressPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof ProgressPrimitive.Root>
>(({ className, value, ...props }, ref) => (
  <ProgressPrimitive.Root
    ref={ref}
    className={cn("relative h-2 w-full overflow-hidden rounded-full bg-secondary", className)}
    {...props}
  >
    <ProgressPrimitive.Indicator
      className="h-full w-full flex-1 brand-gradient transition-all"
      style={{ transform: `translateX(-${100 - (value || 0)}%)` }}
    />
  </ProgressPrimitive.Root>
));
Progress.displayName = ProgressPrimitive.Root.displayName;

export { Progress };
TSX

# Scroll area
cat > src/components/ui/scroll-area.tsx << 'TSX'
import * as React from "react";
import * as ScrollAreaPrimitive from "@radix-ui/react-scroll-area";
import { cn } from "@/lib/utils";

const ScrollArea = React.forwardRef<
  React.ElementRef<typeof ScrollAreaPrimitive.Root>,
  React.ComponentPropsWithoutRef<typeof ScrollAreaPrimitive.Root>
>(({ className, children, ...props }, ref) => (
  <ScrollAreaPrimitive.Root ref={ref} className={cn("relative overflow-hidden", className)} {...props}>
    <ScrollAreaPrimitive.Viewport className="h-full w-full rounded-[inherit]">
      {children}
    </ScrollAreaPrimitive.Viewport>
    <ScrollBar />
    <ScrollAreaPrimitive.Corner />
  </ScrollAreaPrimitive.Root>
));
ScrollArea.displayName = ScrollAreaPrimitive.Root.displayName;

const ScrollBar = React.forwardRef<
  React.ElementRef<typeof ScrollAreaPrimitive.ScrollAreaScrollbar>,
  React.ComponentPropsWithoutRef<typeof ScrollAreaPrimitive.ScrollAreaScrollbar>
>(({ className, orientation = "vertical", ...props }, ref) => (
  <ScrollAreaPrimitive.ScrollAreaScrollbar
    ref={ref}
    orientation={orientation}
    className={cn(
      "flex touch-none select-none transition-colors",
      orientation === "vertical" && "h-full w-2 border-l border-l-transparent p-[1px]",
      orientation === "horizontal" && "h-2 flex-col border-t border-t-transparent p-[1px]",
      className,
    )}
    {...props}
  >
    <ScrollAreaPrimitive.ScrollAreaThumb className="relative flex-1 rounded-full bg-border" />
  </ScrollAreaPrimitive.ScrollAreaScrollbar>
));
ScrollBar.displayName = ScrollAreaPrimitive.ScrollAreaScrollbar.displayName;

export { ScrollArea, ScrollBar };
TSX

# Command palette (cmdk)
cat > src/components/ui/command.tsx << 'TSX'
import * as React from "react";
import { type DialogProps } from "@radix-ui/react-dialog";
import { Command as CommandPrimitive } from "cmdk";
import { Search } from "lucide-react";
import { cn } from "@/lib/utils";
import { Dialog, DialogContent } from "@/components/ui/dialog";

const Command = React.forwardRef<
  React.ElementRef<typeof CommandPrimitive>,
  React.ComponentPropsWithoutRef<typeof CommandPrimitive>
>(({ className, ...props }, ref) => (
  <CommandPrimitive
    ref={ref}
    className={cn(
      "flex h-full w-full flex-col overflow-hidden rounded-2xl bg-popover text-popover-foreground",
      className,
    )}
    {...props}
  />
));
Command.displayName = CommandPrimitive.displayName;

const CommandDialog = ({ children, ...props }: DialogProps) => (
  <Dialog {...props}>
    <DialogContent className="overflow-hidden p-0 shadow-2xl max-w-lg" showClose={false}>
      <Command className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground [&_[cmdk-group]:not([hidden])_~[cmdk-group]]:pt-0 [&_[cmdk-group]]:px-2 [&_[cmdk-input-wrapper]_svg]:h-4 [&_[cmdk-input-wrapper]_svg]:w-4 [&_[cmdk-input]]:h-12 [&_[cmdk-item]]:px-2 [&_[cmdk-item]]:py-2.5 [&_[cmdk-item]_svg]:h-4 [&_[cmdk-item]_svg]:w-4">
        {children}
      </Command>
    </DialogContent>
  </Dialog>
);

const CommandInput = React.forwardRef<
  React.ElementRef<typeof CommandPrimitive.Input>,
  React.ComponentPropsWithoutRef<typeof CommandPrimitive.Input>
>(({ className, ...props }, ref) => (
  <div className="flex items-center border-b px-4" cmdk-input-wrapper="">
    <Search className="mr-2 h-4 w-4 shrink-0 opacity-50" />
    <CommandPrimitive.Input
      ref={ref}
      className={cn(
        "flex h-12 w-full rounded-md bg-transparent py-3 text-sm outline-none placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50",
        className,
      )}
      {...props}
    />
  </div>
));
CommandInput.displayName = CommandPrimitive.Input.displayName;

const CommandList = React.forwardRef<
  React.ElementRef<typeof CommandPrimitive.List>,
  React.ComponentPropsWithoutRef<typeof CommandPrimitive.List>
>(({ className, ...props }, ref) => (
  <CommandPrimitive.List
    ref={ref}
    className={cn("max-h-[320px] overflow-y-auto overflow-x-hidden", className)}
    {...props}
  />
));
CommandList.displayName = CommandPrimitive.List.displayName;

const CommandEmpty = React.forwardRef<
  React.ElementRef<typeof CommandPrimitive.Empty>,
  React.ComponentPropsWithoutRef<typeof CommandPrimitive.Empty>
>((props, ref) => (
  <CommandPrimitive.Empty ref={ref} className="py-8 text-center text-sm text-muted-foreground" {...props} />
));
CommandEmpty.displayName = CommandPrimitive.Empty.displayName;

const CommandGroup = React.forwardRef<
  React.ElementRef<typeof CommandPrimitive.Group>,
  React.ComponentPropsWithoutRef<typeof CommandPrimitive.Group>
>(({ className, ...props }, ref) => (
  <CommandPrimitive.Group
    ref={ref}
    className={cn(
      "overflow-hidden p-1 text-foreground [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-xs [&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-wide",
      className,
    )}
    {...props}
  />
));
CommandGroup.displayName = CommandPrimitive.Group.displayName;

const CommandSeparator = React.forwardRef<
  React.ElementRef<typeof CommandPrimitive.Separator>,
  React.ComponentPropsWithoutRef<typeof CommandPrimitive.Separator>
>(({ className, ...props }, ref) => (
  <CommandPrimitive.Separator ref={ref} className={cn("-mx-1 h-px bg-border", className)} {...props} />
));
CommandSeparator.displayName = CommandPrimitive.Separator.displayName;

const CommandItem = React.forwardRef<
  React.ElementRef<typeof CommandPrimitive.Item>,
  React.ComponentPropsWithoutRef<typeof CommandPrimitive.Item>
>(({ className, ...props }, ref) => (
  <CommandPrimitive.Item
    ref={ref}
    className={cn(
      "relative flex cursor-default gap-2 select-none items-center rounded-lg px-2 py-2 text-sm outline-none",
      "data-[disabled=true]:pointer-events-none data-[selected=true]:bg-accent data-[selected=true]:text-accent-foreground data-[disabled=true]:opacity-50",
      "[&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
      className,
    )}
    {...props}
  />
));
CommandItem.displayName = CommandPrimitive.Item.displayName;

const CommandShortcut = ({ className, ...props }: React.HTMLAttributes<HTMLSpanElement>) => (
  <span className={cn("ml-auto text-xs tracking-widest text-muted-foreground", className)} {...props} />
);
CommandShortcut.displayName = "CommandShortcut";

export {
  Command, CommandDialog, CommandInput, CommandList, CommandEmpty,
  CommandGroup, CommandItem, CommandSeparator, CommandShortcut,
};
TSX

ok "shadcn UI components"

# ===========================================================================
#  src/components/layout/ThemeProvider.tsx
# ===========================================================================
log "Writing layout components ..."

cat > src/components/layout/ThemeProvider.tsx << 'TSX'
import { ThemeProvider as NextThemesProvider } from "next-themes";
import type { ThemeProviderProps } from "next-themes/dist/types";

export function ThemeProvider({ children, ...props }: ThemeProviderProps) {
  return <NextThemesProvider {...props}>{children}</NextThemesProvider>;
}
TSX

# ===========================================================================
#  src/components/layout/CommandPalette.tsx
# ===========================================================================
cat > src/components/layout/CommandPalette.tsx << 'TSX'
import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  LayoutDashboard, Building2, Users, GitBranch, Coffee,
  Package, BookOpen, Clock, BarChart2, Shield,
} from "lucide-react";
import {
  CommandDialog, CommandEmpty, CommandGroup, CommandInput,
  CommandItem, CommandList, CommandSeparator,
} from "@/components/ui/command";
import { useAuthStore } from "@/store/auth";

const NAV_ITEMS = [
  { label: "Dashboard",     to: "/",                    icon: LayoutDashboard, roles: ["super_admin","org_admin","branch_manager","teller"] },
  { label: "Organizations", to: "/orgs",                icon: Building2,       roles: ["super_admin"] },
  { label: "Users",         to: "/users",               icon: Users,           roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Branches",      to: "/branches",            icon: GitBranch,       roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Menu",          to: "/menu",                icon: Coffee,          roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Inventory",     to: "/inventory",           icon: Package,         roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Recipes",       to: "/recipes",             icon: BookOpen,        roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Shifts",        to: "/shifts",              icon: Clock,           roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Analytics",     to: "/analytics",           icon: BarChart2,       roles: ["super_admin","org_admin","branch_manager"] },
  { label: "Permissions",   to: "/permissions/select",  icon: Shield,          roles: ["super_admin","org_admin"] },
];

export function CommandPalette() {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if ((e.key === "k" && (e.metaKey || e.ctrlKey)) || e.key === "/") {
        e.preventDefault();
        setOpen((o) => !o);
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  const filtered = NAV_ITEMS.filter((i) => i.roles.includes(user?.role ?? ""));

  return (
    <CommandDialog open={open} onOpenChange={setOpen}>
      <CommandInput placeholder="Search pages…" />
      <CommandList>
        <CommandEmpty>No results found.</CommandEmpty>
        <CommandGroup heading="Navigation">
          {filtered.map(({ label, to, icon: Icon }) => (
            <CommandItem
              key={to}
              onSelect={() => { navigate(to); setOpen(false); }}
            >
              <Icon className="mr-2 h-4 w-4" />
              {label}
            </CommandItem>
          ))}
        </CommandGroup>
        <CommandSeparator />
        <CommandGroup heading="Shortcuts">
          <CommandItem onSelect={() => { navigate("/shifts"); setOpen(false); }}>
            <Clock className="mr-2 h-4 w-4" />
            Open Shifts
          </CommandItem>
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  );
}
TSX

# ===========================================================================
#  src/components/layout/Sidebar.tsx
# ===========================================================================
cat > src/components/layout/Sidebar.tsx << 'TSX'
import React, { useState } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import { useTheme } from "next-themes";
import {
  Coffee, Building2, Users, LayoutDashboard, LogOut,
  Search, X, GitBranch, Package, BookOpen, Clock,
  BarChart2, Shield, Sun, Moon, Languages, ChevronRight,
  PanelLeftClose, PanelLeftOpen,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Tooltip, TooltipContent, TooltipTrigger, TooltipProvider } from "@/components/ui/tooltip";
import { Separator } from "@/components/ui/separator";
import { useAuthStore } from "@/store/auth";
import { useAppStore } from "@/store/app";
import { fmtRole, ROLE_COLORS, initials } from "@/utils/format";

const NAV = [
  {
    group: "Overview",
    items: [
      { to: "/", icon: LayoutDashboard, label: "Dashboard", sub: "System overview",
        roles: ["super_admin","org_admin","branch_manager","teller"] },
    ],
  },
  {
    group: "Management",
    items: [
      { to: "/orgs",      icon: Building2, label: "Organizations", sub: "Manage coffee brands",  roles: ["super_admin"] },
      { to: "/users",     icon: Users,     label: "Users",         sub: "Staff accounts",        roles: ["super_admin","org_admin","branch_manager"] },
      { to: "/branches",  icon: GitBranch, label: "Branches",      sub: "Manage branches",       roles: ["super_admin","org_admin","branch_manager"] },
      { to: "/menu",      icon: Coffee,    label: "Menu",          sub: "Items & categories",    roles: ["super_admin","org_admin","branch_manager"] },
      { to: "/inventory", icon: Package,   label: "Inventory",     sub: "Stock & transfers",     roles: ["super_admin","org_admin","branch_manager"] },
      { to: "/recipes",   icon: BookOpen,  label: "Recipes",       sub: "Drink ingredients",     roles: ["super_admin","org_admin","branch_manager"] },
      { to: "/shifts",    icon: Clock,     label: "Shifts",        sub: "Reports & management",  roles: ["super_admin","org_admin","branch_manager"] },
      { to: "/analytics", icon: BarChart2, label: "Analytics",     sub: "Reports & trends",      roles: ["super_admin","org_admin","branch_manager"] },
    ],
  },
] as const;

interface SidebarContentProps {
  collapsed: boolean;
  onClose?: () => void;
}

function SidebarContent({ collapsed, onClose }: SidebarContentProps) {
  const [search, setSearch] = useState("");
  const user     = useAuthStore((s) => s.user);
  const signOut  = useAuthStore((s) => s.signOut);
  const language = useAppStore((s) => s.language);
  const setLang  = useAppStore((s) => s.setLanguage);
  const { theme, setTheme } = useTheme();
  const navigate = useNavigate();

  const handleSignOut = () => { signOut(); navigate("/login"); };
  const toggleLang    = () => setLang(language === "en" ? "ar" : "en");
  const toggleTheme   = () => setTheme(theme === "dark" ? "light" : "dark");

  const filtered = NAV.map((g) => ({
    ...g,
    items: g.items.filter(
      (i) =>
        i.roles.includes(user?.role ?? "") &&
        (search === "" || i.label.toLowerCase().includes(search.toLowerCase())),
    ),
  })).filter((g) => g.items.length > 0);

  return (
    <TooltipProvider delayDuration={0}>
      <div className="flex flex-col h-full overflow-hidden">
        {/* Logo */}
        <div className={cn(
          "flex items-center border-b border-border flex-shrink-0",
          collapsed ? "h-14 justify-center px-2" : "h-14 px-4 justify-between",
        )}>
          {!collapsed && (
            <img src="/TheRue.png" alt="The Rue" className="h-7 object-contain" />
          )}
          {collapsed && (
            <div className="w-8 h-8 brand-gradient rounded-xl flex items-center justify-center">
              <Coffee size={16} className="text-white" />
            </div>
          )}
          {onClose && !collapsed && (
            <Button variant="ghost" size="icon-sm" onClick={onClose} className="lg:hidden">
              <X size={16} />
            </Button>
          )}
        </div>

        {/* Search — hidden when collapsed */}
        {!collapsed && (
          <div className="px-3 py-2 border-b border-border flex-shrink-0">
            <div className="flex items-center gap-2 bg-muted rounded-xl px-3 py-2">
              <Search size={13} className="text-muted-foreground flex-shrink-0" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search… ⌘K"
                className="flex-1 bg-transparent text-sm outline-none placeholder:text-muted-foreground min-w-0"
              />
              {search && (
                <button
                  onClick={() => setSearch("")}
                  className="text-muted-foreground hover:text-foreground transition-colors"
                >
                  <X size={13} />
                </button>
              )}
            </div>
          </div>
        )}

        {/* Nav */}
        <nav className="flex-1 overflow-y-auto py-2 px-2 no-scrollbar">
          {filtered.map((group) => (
            <div key={group.group} className="mb-3">
              {!collapsed && (
                <p className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest px-3 mb-1">
                  {group.group}
                </p>
              )}
              <div className="space-y-0.5">
                {group.items.map(({ to, icon: Icon, label, sub }) => (
                  <Tooltip key={to} disableHoverableContent={!collapsed}>
                    <TooltipTrigger asChild>
                      <NavLink
                        to={to}
                        end={to === "/"}
                        onClick={onClose}
                        className={({ isActive }) =>
                          cn(
                            "relative flex items-center gap-3 rounded-xl transition-all duration-150",
                            collapsed ? "justify-center h-10 w-10 mx-auto" : "px-3 py-2.5",
                            isActive
                              ? "bg-accent text-accent-foreground font-semibold"
                              : "text-muted-foreground hover:bg-muted hover:text-foreground",
                          )
                        }
                      >
                        {({ isActive }) => (
                          <>
                            {isActive && !collapsed && (
                              <span className="nav-active-indicator" />
                            )}
                            <div className={cn(
                              "flex items-center justify-center rounded-lg flex-shrink-0 transition-all",
                              collapsed ? "w-8 h-8" : "w-7 h-7",
                              isActive
                                ? "brand-gradient text-white shadow-sm"
                                : "bg-muted text-muted-foreground",
                            )}>
                              <Icon size={collapsed ? 15 : 14} />
                            </div>
                            {!collapsed && (
                              <div className="flex-1 min-w-0">
                                <p className={cn(
                                  "text-sm leading-tight truncate",
                                  isActive ? "font-semibold text-foreground" : "font-medium",
                                )}>{label}</p>
                                <p className="text-[11px] text-muted-foreground truncate">{sub}</p>
                              </div>
                            )}
                            {!collapsed && isActive && (
                              <ChevronRight size={12} className="text-primary flex-shrink-0" />
                            )}
                          </>
                        )}
                      </NavLink>
                    </TooltipTrigger>
                    {collapsed && (
                      <TooltipContent side="right">
                        <p className="font-medium">{label}</p>
                      </TooltipContent>
                    )}
                  </Tooltip>
                ))}
              </div>
            </div>
          ))}
        </nav>

        {/* Footer */}
        <div className={cn("flex-shrink-0 border-t border-border", collapsed ? "p-2" : "p-3")}>
          {/* Theme + Language */}
          <div className={cn(
            "flex mb-2 gap-1",
            collapsed ? "flex-col items-center" : "items-center justify-between",
          )}>
            {!collapsed && <span className="text-xs text-muted-foreground">Appearance</span>}
            <div className="flex gap-1">
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="ghost" size="icon-sm" onClick={toggleTheme}>
                    {theme === "dark" ? <Sun size={14} /> : <Moon size={14} />}
                  </Button>
                </TooltipTrigger>
                <TooltipContent side={collapsed ? "right" : "top"}>
                  {theme === "dark" ? "Light mode" : "Dark mode"}
                </TooltipContent>
              </Tooltip>
              <Tooltip>
                <TooltipTrigger asChild>
                  <Button variant="ghost" size="icon-sm" onClick={toggleLang}>
                    <Languages size={14} />
                  </Button>
                </TooltipTrigger>
                <TooltipContent side={collapsed ? "right" : "top"}>
                  {language === "en" ? "Switch to Arabic" : "Switch to English"}
                </TooltipContent>
              </Tooltip>
            </div>
          </div>

          <Separator className="mb-2" />

          {/* User */}
          {collapsed ? (
            <Tooltip>
              <TooltipTrigger asChild>
                <button onClick={handleSignOut} className="w-full flex items-center justify-center">
                  <Avatar className="h-8 w-8">
                    <AvatarFallback className="text-xs">{initials(user?.name ?? "")}</AvatarFallback>
                  </Avatar>
                </button>
              </TooltipTrigger>
              <TooltipContent side="right">
                <p className="font-medium">{user?.name}</p>
                <p className="text-xs text-muted-foreground">{fmtRole(user?.role ?? "")}</p>
              </TooltipContent>
            </Tooltip>
          ) : (
            <>
              <div className="flex items-center gap-3 p-2 rounded-xl bg-muted mb-2">
                <Avatar className="h-8 w-8 flex-shrink-0">
                  <AvatarFallback className="text-xs">{initials(user?.name ?? "")}</AvatarFallback>
                </Avatar>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold truncate">{user?.name}</p>
                  <p className={cn(
                    "text-[10px] font-semibold px-1.5 py-0.5 rounded-full border inline-block mt-0.5",
                    ROLE_COLORS[user?.role ?? ""],
                  )}>
                    {fmtRole(user?.role ?? "")}
                  </p>
                </div>
              </div>
              <Button
                variant="destructive"
                size="sm"
                className="w-full justify-center"
                onClick={handleSignOut}
              >
                <LogOut size={13} />
                Sign Out
              </Button>
            </>
          )}
        </div>
      </div>
    </TooltipProvider>
  );
}

interface SidebarProps {
  mobileOpen:    boolean;
  onMobileClose: () => void;
}

export function Sidebar({ mobileOpen, onMobileClose }: SidebarProps) {
  const collapsed    = useAppStore((s) => !s.sidebarOpen);
  const toggleSidebar = useAppStore((s) => s.toggleSidebar);

  return (
    <>
      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm lg:hidden"
          onClick={onMobileClose}
        />
      )}

      {/* Mobile drawer */}
      <aside
        className={cn(
          "fixed left-0 top-0 bottom-0 z-50 w-[min(280px,82vw)] bg-background border-r border-border shadow-xl",
          "transition-transform duration-250 ease-[cubic-bezier(0.4,0,0.2,1)] lg:hidden",
          mobileOpen ? "translate-x-0" : "-translate-x-full",
        )}
      >
        <SidebarContent collapsed={false} onClose={onMobileClose} />
      </aside>

      {/* Desktop sidebar */}
      <aside
        className={cn(
          "hidden lg:flex flex-col bg-background border-r border-border flex-shrink-0 sticky top-0 h-screen",
          "transition-[width] duration-200 ease-in-out relative",
          collapsed ? "w-[64px]" : "w-[240px]",
        )}
      >
        <SidebarContent collapsed={collapsed} />

        {/* Collapse toggle */}
        <button
          onClick={toggleSidebar}
          className={cn(
            "absolute -right-3 top-20 z-10",
            "w-6 h-6 rounded-full bg-background border border-border shadow-sm",
            "flex items-center justify-center text-muted-foreground hover:text-foreground",
            "transition-colors",
          )}
        >
          {collapsed
            ? <PanelLeftOpen size={12} />
            : <PanelLeftClose size={12} />}
        </button>
      </aside>
    </>
  );
}
TSX

# ===========================================================================
#  src/components/layout/Header.tsx
# ===========================================================================
cat > src/components/layout/Header.tsx << 'TSX'
import React from "react";
import { useLocation } from "react-router-dom";
import { Menu, Search } from "lucide-react";
import { Button } from "@/components/ui/button";

const TITLES: Record<string, { title: string; sub: string }> = {
  "/":           { title: "Dashboard",     sub: "System overview" },
  "/orgs":       { title: "Organizations", sub: "Manage all coffee brands" },
  "/users":      { title: "Users",         sub: "Manage staff accounts" },
  "/branches":   { title: "Branches",      sub: "Manage branch locations" },
  "/menu":       { title: "Menu",          sub: "Categories, items and addons" },
  "/inventory":  { title: "Inventory",     sub: "Stock levels and transfers" },
  "/recipes":    { title: "Recipes",       sub: "Drink ingredients" },
  "/shifts":     { title: "Shifts",        sub: "Reports and shift management" },
  "/analytics":  { title: "Analytics",     sub: "Reports & trends" },
  "/permissions":{ title: "Permissions",   sub: "User access control" },
};

interface HeaderProps {
  onMenuClick: () => void;
  onSearchClick?: () => void;
}

export function Header({ onMenuClick, onSearchClick }: HeaderProps) {
  const loc  = useLocation();
  const segs = loc.pathname.split("/").filter(Boolean);
  const base = segs.length ? "/" + segs[0] : "/";
  const meta = TITLES[base] ?? { title: "Rue POS", sub: "" };

  return (
    <header className="h-14 flex-shrink-0 bg-background border-b border-border flex items-center px-4 gap-3 sticky top-0 z-30">
      {/* Mobile hamburger */}
      <Button
        variant="ghost"
        size="icon-sm"
        onClick={onMenuClick}
        className="lg:hidden flex-shrink-0"
        aria-label="Open menu"
      >
        <Menu size={18} />
      </Button>

      <div className="flex-1 min-w-0">
        <h1 className="text-sm font-bold leading-tight truncate">{meta.title}</h1>
        <p className="text-xs text-muted-foreground mt-0.5 hidden sm:block truncate">{meta.sub}</p>
      </div>

      {/* Search shortcut hint */}
      <button
        onClick={onSearchClick}
        className="hidden sm:flex items-center gap-2 text-xs text-muted-foreground bg-muted hover:bg-muted/80 px-3 py-1.5 rounded-lg transition-colors"
      >
        <Search size={12} />
        <span>Search</span>
        <kbd className="text-[10px] bg-background border border-border rounded px-1 font-mono">⌘K</kbd>
      </button>
    </header>
  );
}
TSX

# ===========================================================================
#  src/components/layout/Layout.tsx
# ===========================================================================
cat > src/components/layout/Layout.tsx << 'TSX'
import React, { useState } from "react";
import { Outlet } from "react-router-dom";
import { Sidebar } from "./Sidebar";
import { Header } from "./Header";
import { CommandPalette } from "./CommandPalette";

export default function Layout() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <div className="flex h-screen bg-background overflow-hidden">
      <Sidebar
        mobileOpen={mobileOpen}
        onMobileClose={() => setMobileOpen(false)}
      />

      <div className="flex-1 flex flex-col overflow-hidden min-w-0">
        <Header
          onMenuClick={() => setMobileOpen(true)}
          onSearchClick={() => {
            const event = new KeyboardEvent("keydown", {
              key: "k", metaKey: true, bubbles: true,
            });
            document.dispatchEvent(event);
          }}
        />

        <main
          className="flex-1 overflow-y-auto overflow-x-hidden"
          style={{ WebkitOverflowScrolling: "touch" }}
        >
          <Outlet />
        </main>
      </div>

      <CommandPalette />
    </div>
  );
}
TSX

# ===========================================================================
#  src/components/layout/ProtectedRoute.tsx
# ===========================================================================
cat > src/components/layout/ProtectedRoute.tsx << 'TSX'
import { Navigate } from "react-router-dom";
import { useAuthStore } from "@/store/auth";
import { Skeleton } from "@/components/ui/skeleton";

export default function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const user = useAuthStore((s) => s.user);

  // Zustand loads synchronously from localStorage — no async loading state needed
  if (!user) return <Navigate to="/login" replace />;
  return <>{children}</>;
}
TSX

ok "Layout components"

# ===========================================================================
#  src/main.tsx
# ===========================================================================
log "Writing src/main.tsx ..."
cat > src/main.tsx << 'TSX'
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
TSX
ok "src/main.tsx"

# ===========================================================================
#  src/App.tsx
# ===========================================================================
log "Writing src/App.tsx ..."
cat > src/App.tsx << 'TSX'
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import ProtectedRoute from "@/components/layout/ProtectedRoute";
import Layout from "@/components/layout/Layout";

// Pages — lazy loaded for code splitting
import { lazy, Suspense } from "react";
import { Skeleton } from "@/components/ui/skeleton";

const Login       = lazy(() => import("@/pages/auth/Login"));
const Dashboard   = lazy(() => import("@/pages/dashboard/Dashboard"));
const Orgs        = lazy(() => import("@/pages/orgs/Orgs"));
const Users       = lazy(() => import("@/pages/users/Users"));
const Branches    = lazy(() => import("@/pages/branches/Branches"));
const Menu        = lazy(() => import("@/pages/menu/Menu"));
const Inventory   = lazy(() => import("@/pages/inventory/Inventory"));
const Recipes     = lazy(() => import("@/pages/recipes/Recipes"));
const Shifts      = lazy(() => import("@/pages/shifts/Shifts"));
const Analytics   = lazy(() => import("@/pages/analytics/Analytics"));
const Permissions = lazy(() => import("@/pages/permissions/Permissions"));

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
            <Route index              element={<Dashboard />} />
            <Route path="orgs"        element={<Orgs />} />
            <Route path="users"       element={<Users />} />
            <Route path="branches"    element={<Branches />} />
            <Route path="menu"        element={<Menu />} />
            <Route path="inventory"   element={<Inventory />} />
            <Route path="recipes"     element={<Recipes />} />
            <Route path="shifts"      element={<Shifts />} />
            <Route path="analytics"   element={<Analytics />} />
            <Route path="permissions/:userId" element={<Permissions />} />
            <Route path="permissions/select"  element={<Permissions />} />
            <Route path="*"           element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}
TSX
ok "src/App.tsx"

# ===========================================================================
#  Placeholder pages so the app compiles
#  (Real pages come in parts 2-7)
# ===========================================================================
log "Writing placeholder pages so the app compiles ..."

for page in \
  "pages/auth/Login" \
  "pages/dashboard/Dashboard" \
  "pages/orgs/Orgs" \
  "pages/users/Users" \
  "pages/branches/Branches" \
  "pages/menu/Menu" \
  "pages/inventory/Inventory" \
  "pages/recipes/Recipes" \
  "pages/shifts/Shifts" \
  "pages/analytics/Analytics" \
  "pages/permissions/Permissions"
do
  NAME=$(basename "$page")
  mkdir -p "src/$(dirname "$page")"
  cat > "src/${page}.tsx" << TSX
export default function ${NAME}() {
  return (
    <div className="p-6 lg:p-8">
      <h1 className="text-2xl font-bold">${NAME}</h1>
      <p className="text-muted-foreground mt-1">Coming in next parts…</p>
    </div>
  );
}
TSX
done

ok "Placeholder pages"

# ===========================================================================
#  Install dependencies
# ===========================================================================
log "Installing dependencies (npm install) ..."
npm install --legacy-peer-deps

ok "npm install"

# ===========================================================================
#  Done
# ===========================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}  Part 1 complete! Foundation is ready.${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo "  Created:"
echo "    ✓ package.json         (all deps installed)"
echo "    ✓ vite.config.ts"
echo "    ✓ tsconfig.json"
echo "    ✓ tailwind.config.ts   (dark mode, RTL, brand colors)"
echo "    ✓ src/index.css        (shadcn CSS vars, dark mode, RTL)"
echo "    ✓ src/types/index.ts   (all Rust struct types)"
echo "    ✓ src/lib/             (axios client, query client, utils)"
echo "    ✓ src/store/           (useAuthStore, useAppStore)"
echo "    ✓ src/utils/format.ts  (egp, dates, payment methods, etc.)"
echo "    ✓ src/api/             (all API files, fully typed)"
echo "    ✓ src/components/ui/   (shadcn: Button, Badge, Input, Label,"
echo "                            Select, Dialog, Tabs, Skeleton,"
echo "                            Separator, Tooltip, Switch, Checkbox,"
echo "                            DropdownMenu, Avatar, Progress,"
echo "                            ScrollArea, Command palette)"
echo "    ✓ src/components/layout/ (Sidebar, Header, Layout,"
echo "                              ThemeProvider, CommandPalette,"
echo "                              ProtectedRoute)"
echo "    ✓ src/main.tsx"
echo "    ✓ src/App.tsx"
echo "    ✓ Placeholder pages (so app compiles now)"
echo ""
echo "  Test it works:"
echo "    npm run dev"
echo ""
echo "  Then run Part 2 (Auth + Dashboard):"
echo "    bash frontend_part2.sh"
echo ""