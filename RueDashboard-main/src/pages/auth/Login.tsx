import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Eye, EyeOff, LogIn, Coffee, Zap, Shield, Globe } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { login } from "@/api/auth";
import { useAuthStore } from "@/store/auth";
import { getErrorMessage } from "@/lib/client";
import { cn } from "@/lib/utils";

const FEATURES = [
  {
    icon: Zap,
    label: "Real-time shifts",
    desc: "Live order tracking across all branches",
  },
  {
    icon: Shield,
    label: "Role-based access",
    desc: "Granular permissions per user",
  },
  {
    icon: Globe,
    label: "Multi-branch",
    desc: "Manage all locations from one place",
  },
];

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [loading, setLoading] = useState(false);
  const { signIn } = useAuthStore();
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const res = await login({ email, password });
      signIn(res.data.token, res.data.user);
      navigate("/");
    } catch (err) {
      toast.error(getErrorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex bg-background">
      {/* ── Left panel (desktop only) ─────────────────────────── */}
      <div className="hidden lg:flex lg:w-5/12 xl:w-1/2 flex-col relative overflow-hidden brand-gradient">
        {/* Decorative geometry */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute -top-32 -left-32 w-[480px] h-[480px] rounded-full bg-white/5" />
          <div className="absolute top-1/2 -right-24 w-96 h-96 rounded-full bg-white/5" />
          <div className="absolute -bottom-24 left-1/4 w-72 h-72 rounded-full bg-white/5" />
          {/* Grid overlay */}
          <div
            className="absolute inset-0 opacity-[0.03]"
            style={{
              backgroundImage: `linear-gradient(white 1px, transparent 1px), linear-gradient(90deg, white 1px, transparent 1px)`,
              backgroundSize: "40px 40px",
            }}
          />
        </div>

        <div className="relative z-10 flex flex-col justify-between h-full px-12 py-16">
          {/* Logo */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-white/20 backdrop-blur rounded-xl flex items-center justify-center">
              <Coffee size={20} className="text-white" />
            </div>
            <span className="text-white text-xl font-bold tracking-tight">
              Rue POS
            </span>
          </div>

          {/* Hero copy */}
          <div>
            <h2 className="text-white text-4xl font-extrabold leading-tight mb-4">
              Coffee Shop
              <br />
              Management
              <br />
              <span className="text-blue-200">Made Simple.</span>
            </h2>
            <p className="text-blue-100 text-base leading-relaxed mb-10 max-w-sm">
              One dashboard for every branch, every shift, every order — with
              full inventory and analytics built in.
            </p>

            <div className="space-y-4">
              {FEATURES.map(({ icon: Icon, label, desc }) => (
                <div
                  key={label}
                  className="flex items-center gap-4 bg-white/10 backdrop-blur-sm rounded-2xl p-4"
                >
                  <div className="w-9 h-9 bg-white/20 rounded-xl flex items-center justify-center flex-shrink-0">
                    <Icon size={16} className="text-white" />
                  </div>
                  <div>
                    <p className="text-white font-semibold text-sm">{label}</p>
                    <p className="text-blue-200 text-xs mt-0.5">{desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <p className="text-blue-300 text-xs">
            © 2026 The Rue Coffee. All rights reserved.
          </p>
        </div>
      </div>

      {/* ── Right panel ───────────────────────────────────────── */}
      <div className="flex-1 flex flex-col items-center justify-center px-4 py-8 sm:px-6">
        {/* Mobile logo */}
        <div className="flex lg:hidden items-center gap-3 mb-10">
          <div className="w-10 h-10 brand-gradient rounded-xl flex items-center justify-center shadow-lg">
            <Coffee size={18} className="text-white" />
          </div>
          <span className="text-xl font-bold">Rue POS</span>
        </div>

        <div className="w-full max-w-sm">
          <div className="mb-8">
            <h1 className="text-2xl font-extrabold tracking-tight">
              Welcome back
            </h1>
            <p className="text-muted-foreground text-sm mt-1">
              Sign in to your account to continue
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Email */}
            <div className="space-y-2">
              <Label htmlFor="email">Email address</Label>
              <Input
                id="email"
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@theruecoffee.com"
                required
                className="h-11"
              />
            </div>

            {/* Password */}
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <div className="relative">
                <Input
                  id="password"
                  type={show ? "text" : "password"}
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="h-11 pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShow((s) => !s)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                  aria-label={show ? "Hide password" : "Show password"}
                >
                  {show ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
            </div>

            <Button
              type="submit"
              loading={loading}
              className="w-full h-11 text-base shadow-lg shadow-primary/25"
            >
              <LogIn size={16} />
              Sign in
            </Button>
          </form>

          <p className="text-center text-xs text-muted-foreground mt-8">
            © 2026 Rue POS · Secured with JWT auth
          </p>
        </div>
      </div>
    </div>
  );
}
