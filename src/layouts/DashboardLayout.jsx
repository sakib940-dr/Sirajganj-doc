import { useState } from "react";
import { Outlet, Link, NavLink } from "react-router-dom";
import {
  LayoutDashboard,
  Store,
  Package,
  Images,
  ShieldCheck,
  TrendingUp,
  ArrowLeft,
  Menu,
  X,
  KeyRound,
} from "lucide-react";
import Sidebar from "@/components/layout/Sidebar.jsx";
import BottomNav from "@/components/layout/BottomNav.jsx";
import { ROUTES } from "@/constants/routes";
import { useAuth } from "@/hooks/useAuth";
import { cn } from "@/lib/utils";

const navItems = [
  { to: ROUTES.DASHBOARD, label: "ওভারভিউ", icon: LayoutDashboard, end: true },
  { to: ROUTES.DASHBOARD_ANALYTICS, label: "অ্যানালিটিক্স", icon: TrendingUp },
  { to: ROUTES.DASHBOARD_SHOP, label: "চেম্বারের তথ্য", icon: Store },
  { to: ROUTES.DASHBOARD_PRODUCTS, label: "ডাক্তার প্রোফাইল", icon: Package },
  { to: ROUTES.DASHBOARD_GALLERY, label: "গ্যালারি", icon: Images },
  { to: ROUTES.DASHBOARD_VERIFICATION, label: "ভেরিফিকেশন", icon: ShieldCheck },
];

export default function DashboardLayout() {
  const { profile } = useAuth();
  const [drawerOpen, setDrawerOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background">
      {/* Top bar */}
      <div className="border-b border-border bg-card">
        <div className="container flex h-14 items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => setDrawerOpen(true)}
              className="flex h-9 w-9 items-center justify-center rounded-lg text-foreground hover:bg-secondary md:hidden"
              aria-label="মেনু খুলুন"
            >
              <Menu className="h-5 w-5" />
            </button>
            <Link
              to={ROUTES.HOME}
              className="hidden items-center gap-2 text-sm text-muted-foreground hover:text-foreground md:flex"
            >
              <ArrowLeft className="h-4 w-4" />
              মূল সাইটে ফিরুন
            </Link>
          </div>
          <div className="flex items-center gap-3">
            <span className="truncate text-sm font-medium">{profile?.full_name || "ডাক্তার প্যানেল"}</span>
            <Link
              to={ROUTES.ACCOUNT}
              className="hidden items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground md:flex"
            >
              <KeyRound className="h-4 w-4" />
              পাসওয়ার্ড
            </Link>
          </div>
        </div>
      </div>

      {/* Mobile left hamburger drawer */}
      <div
        className={cn(
          "fixed inset-0 z-50 md:hidden",
          drawerOpen ? "pointer-events-auto" : "pointer-events-none"
        )}
        aria-hidden={!drawerOpen}
      >
        <div
          className={cn(
            "absolute inset-0 bg-black/40 transition-opacity",
            drawerOpen ? "opacity-100" : "opacity-0"
          )}
          onClick={() => setDrawerOpen(false)}
        />
        <div
          className={cn(
            "absolute inset-y-0 left-0 flex w-72 max-w-[80%] flex-col bg-card shadow-xl transition-transform duration-200",
            drawerOpen ? "translate-x-0" : "-translate-x-full"
          )}
        >
          <div className="flex h-14 items-center justify-between border-b border-border px-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
              ডাক্তার ড্যাশবোর্ড
            </p>
            <button
              type="button"
              onClick={() => setDrawerOpen(false)}
              className="flex h-8 w-8 items-center justify-center rounded-lg text-foreground hover:bg-secondary"
              aria-label="মেনু বন্ধ করুন"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
          <nav className="flex flex-1 flex-col gap-1 overflow-y-auto p-3">
            {navItems.map(({ to, label, icon: Icon, end }) => (
              <NavLink
                key={to}
                to={to}
                end={end}
                onClick={() => setDrawerOpen(false)}
                className={({ isActive }) =>
                  cn(
                    "flex items-center gap-2.5 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-primary text-primary-foreground"
                      : "text-foreground/80 hover:bg-secondary"
                  )
                }
              >
                <Icon className="h-4 w-4" />
                <span>{label}</span>
              </NavLink>
            ))}
            <Link
              to={ROUTES.ACCOUNT}
              onClick={() => setDrawerOpen(false)}
              className="mt-2 flex items-center gap-2.5 rounded-lg border-t border-border px-3 pt-4 text-sm text-muted-foreground hover:text-foreground"
            >
              <KeyRound className="h-4 w-4" />
              পাসওয়ার্ড পরিবর্তন
            </Link>
            <Link
              to={ROUTES.HOME}
              onClick={() => setDrawerOpen(false)}
              className="flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-muted-foreground hover:text-foreground"
            >
              <ArrowLeft className="h-4 w-4" />
              মূল সাইটে ফিরুন
            </Link>
          </nav>
        </div>
      </div>

      <div className="container flex flex-col gap-6 py-6 pb-24 md:flex-row md:pb-6">
        <div className="hidden md:block">
          <Sidebar items={navItems} title="ডাক্তার ড্যাশবোর্ড" />
        </div>
        <div className="min-w-0 flex-1">
          <Outlet />
        </div>
      </div>

      {/* Mobile bottom navigation */}
      <BottomNav />
    </div>
  );
}
