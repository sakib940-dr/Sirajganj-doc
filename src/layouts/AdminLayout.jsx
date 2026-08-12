import { useMemo, useState } from "react";
import { Outlet, Link, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  Users,
  UserCog,
  KeyRound,
  ShieldCheck,
  FolderTree,
  Package,
  GalleryHorizontal,
  Palette,
  ArrowLeft,
  Menu,
  X,
  LogOut,
  Shield,
} from "lucide-react";
import AdminSidebarNav from "@/components/layout/AdminSidebarNav.jsx";
import { ROUTES } from "@/constants/routes";
import { useAuth } from "@/hooks/useAuth";
import { ROLES, ROLE_LABEL_BN } from "@/constants/roles";
import { cn } from "@/lib/utils";

export default function AdminLayout() {
  const { role, profile, signOut } = useAuth();
  const location = useLocation();
  const isSuperAdmin = role === ROLES.SUPER_ADMIN;
  const [drawerOpen, setDrawerOpen] = useState(false);

  const groups = useMemo(
    () => [
      {
        items: [{ to: ROUTES.ADMIN, label: "ড্যাশবোর্ড", icon: LayoutDashboard, end: true }],
      },
      {
        title: "ডাক্তার ব্যবস্থাপনা",
        items: [
          { to: ROUTES.ADMIN_SELLERS, label: "ডাক্তার ম্যানেজমেন্ট", icon: Users },
          { to: ROUTES.ADMIN_VERIFICATIONS, label: "ডাক্তার ভেরিফিকেশন", icon: ShieldCheck },
        ],
      },
      {
        title: "ক্যাটালগ",
        items: [
          { to: ROUTES.ADMIN_CATEGORIES, label: "ক্যাটাগরি", icon: FolderTree },
          { to: ROUTES.ADMIN_PRODUCTS, label: "ডাক্তার প্রোফাইল ম্যানেজমেন্ট", icon: Package },
        ],
      },
      ...(isSuperAdmin
        ? [
            {
              title: "ইউজার ও অ্যাক্সেস",
              items: [
                { to: ROUTES.ADMIN_USERS, label: "ইউজার (রোলসহ)", icon: UserCog },
                { to: ROUTES.ADMIN_CREDENTIALS, label: "লগইন অ্যাক্সেস", icon: KeyRound },
              ],
            },
            {
              title: "সাইট কনফিগারেশন",
              items: [
                { to: ROUTES.ADMIN_CMS, label: "CMS প্যানেল", icon: Palette },
                { to: ROUTES.ADMIN_BANNERS, label: "ব্যানার (দ্রুত অ্যাক্সেস)", icon: GalleryHorizontal },
              ],
            },
          ]
        : []),
    ],
    [isSuperAdmin]
  );

  const currentLabel = useMemo(() => {
    const flat = groups.flatMap((g) => g.items);
    const match =
      flat.find((i) => i.end && location.pathname === i.to) ||
      flat
        .filter((i) => !i.end)
        .sort((a, b) => b.to.length - a.to.length)
        .find((i) => location.pathname.startsWith(i.to));
    return match?.label || "ড্যাশবোর্ড";
  }, [groups, location.pathname]);

  return (
    <div className="min-h-screen bg-muted/40">
      <div className="flex min-h-screen">
        {/* Desktop fixed sidebar */}
        <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col bg-primary text-primary-foreground lg:flex">
          <div className="flex h-16 items-center gap-2.5 border-b border-primary-foreground/10 px-5">
            <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
              <Shield className="h-5 w-5" />
            </span>
            <div className="min-w-0">
              <p className="truncate text-sm font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
                অ্যাডমিন প্যানেল
              </p>
              <p className="truncate text-[11px] text-primary-foreground/55">
                অ্যাডমিন অ্যাক্সেস
              </p>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto px-3 py-4">
            <AdminSidebarNav groups={groups} />
          </div>

          <div className="border-t border-primary-foreground/10 p-3">
            <div className="mb-2 flex items-center gap-2.5 rounded-lg px-2 py-2">
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary-foreground/10 text-xs font-semibold">
                {(profile?.full_name || "A").charAt(0)}
              </span>
              <div className="min-w-0">
                <p className="truncate text-sm font-medium">{profile?.full_name || "অ্যাডমিন"}</p>
                <p className="truncate text-[11px] text-primary-foreground/55">{ROLE_LABEL_BN[role]}</p>
              </div>
            </div>
            <Link
              to={ROUTES.ACCOUNT}
              className="flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-primary-foreground/75 transition-colors hover:bg-primary-foreground/10 hover:text-primary-foreground"
            >
              <KeyRound className="h-4 w-4" />
              পাসওয়ার্ড পরিবর্তন
            </Link>
            <Link
              to={ROUTES.HOME}
              className="flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-primary-foreground/75 transition-colors hover:bg-primary-foreground/10 hover:text-primary-foreground"
            >
              <ArrowLeft className="h-4 w-4" />
              মূল সাইটে ফিরুন
            </Link>
            <button
              type="button"
              onClick={signOut}
              className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-primary-foreground/75 transition-colors hover:bg-destructive/20 hover:text-primary-foreground"
            >
              <LogOut className="h-4 w-4" />
              লগ আউট
            </button>
          </div>
        </aside>

        {/* Mobile drawer */}
        <div
          className={cn("fixed inset-0 z-50 lg:hidden", drawerOpen ? "pointer-events-auto" : "pointer-events-none")}
          aria-hidden={!drawerOpen}
        >
          <div
            className={cn(
              "absolute inset-0 bg-black/50 transition-opacity",
              drawerOpen ? "opacity-100" : "opacity-0"
            )}
            onClick={() => setDrawerOpen(false)}
          />
          <div
            className={cn(
              "absolute inset-y-0 left-0 flex w-72 max-w-[82%] flex-col bg-primary text-primary-foreground shadow-xl transition-transform duration-200",
              drawerOpen ? "translate-x-0" : "-translate-x-full"
            )}
          >
            <div className="flex h-14 items-center justify-between border-b border-primary-foreground/10 px-4">
              <div className="flex items-center gap-2">
                <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-accent text-accent-foreground">
                  <Shield className="h-4 w-4" />
                </span>
                <p className="text-sm font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
                  অ্যাডমিন প্যানেল
                </p>
              </div>
              <button
                type="button"
                onClick={() => setDrawerOpen(false)}
                className="flex h-8 w-8 items-center justify-center rounded-lg text-primary-foreground/80 hover:bg-primary-foreground/10"
                aria-label="মেনু বন্ধ করুন"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto px-3 py-4">
              <AdminSidebarNav groups={groups} onNavigate={() => setDrawerOpen(false)} />
            </div>
            <div className="border-t border-primary-foreground/10 p-3">
              <Link
                to={ROUTES.ACCOUNT}
                onClick={() => setDrawerOpen(false)}
                className="flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-primary-foreground/75 hover:bg-primary-foreground/10 hover:text-primary-foreground"
              >
                <KeyRound className="h-4 w-4" />
                পাসওয়ার্ড পরিবর্তন
              </Link>
              <Link
                to={ROUTES.HOME}
                onClick={() => setDrawerOpen(false)}
                className="flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-primary-foreground/75 hover:bg-primary-foreground/10 hover:text-primary-foreground"
              >
                <ArrowLeft className="h-4 w-4" />
                মূল সাইটে ফিরুন
              </Link>
              <button
                type="button"
                onClick={signOut}
                className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-sm text-primary-foreground/75 hover:bg-destructive/20 hover:text-primary-foreground"
              >
                <LogOut className="h-4 w-4" />
                লগ আউট
              </button>
            </div>
          </div>
        </div>

        {/* Main column */}
        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-border bg-card/95 px-4 backdrop-blur supports-[backdrop-filter]:bg-card/80 sm:px-6">
            <button
              type="button"
              onClick={() => setDrawerOpen(true)}
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg text-foreground hover:bg-secondary lg:hidden"
              aria-label="মেনু খুলুন"
            >
              <Menu className="h-5 w-5" />
            </button>
            <div className="min-w-0">
              <p className="truncate text-base font-semibold">{currentLabel}</p>
            </div>
            <div className="ml-auto flex items-center gap-2">
              <span className="hidden rounded-full bg-secondary px-3 py-1 text-xs font-medium text-secondary-foreground sm:inline-block">
                {ROLE_LABEL_BN[role]}
              </span>
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 text-xs font-semibold text-primary lg:hidden">
                {(profile?.full_name || "A").charAt(0)}
              </span>
            </div>
          </header>

          <main className="min-w-0 flex-1 px-4 py-6 sm:px-6">
            <div className="mx-auto w-full max-w-6xl">
              <Outlet />
            </div>
          </main>
        </div>
      </div>
    </div>
  );
}
