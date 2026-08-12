import { useEffect, useMemo, useState } from "react";
import {
  Store,
  Package,
  FolderTree,
  Users,
  ArrowUpRight,
  BadgeCheck,
  ShieldAlert,
  Eye,
  Heart,
  Trophy,
  BarChart3,
  Activity,
} from "lucide-react";
import { supabase } from "@/lib/supabaseClient";
import { useAuth } from "@/hooks/useAuth";
import { useSuperAdminAnalytics } from "@/hooks/admin/useSuperAdminAnalytics.js";
import { ROLES } from "@/constants/roles";
import { ROUTES } from "@/constants/routes";
import { Link } from "react-router-dom";
import StatCard from "@/components/shared/StatCard.jsx";
import { RankedListCard } from "@/components/admin/analytics/SuperAdminAnalyticsWidgets.jsx";
import GroupedBarChart from "@/components/shared/charts/GroupedBarChart.jsx";
import BarStatChart from "@/components/shared/charts/BarStatChart.jsx";
import DonutStatChart from "@/components/shared/charts/DonutStatChart.jsx";

const STATS = [
  { key: "shops", label: "মোট চেম্বার", icon: Store, table: "shops" },
  { key: "products", label: "মোট ডাক্তার প্রোফাইল", icon: Package, table: "products" },
  { key: "categories", label: "মোট ক্যাটাগরি", icon: FolderTree, table: "categories" },
];

export default function AdminDashboard() {
  const { role } = useAuth();
  const isSuperAdmin = role === ROLES.SUPER_ADMIN;
  const [counts, setCounts] = useState({});
  const [pendingSellers, setPendingSellers] = useState(0);
  const [countsLoading, setCountsLoading] = useState(true);

  useEffect(() => {
    let pending = STATS.length;
    STATS.forEach(async ({ key, table }) => {
      const { count } = await supabase.from(table).select("id", { count: "exact", head: true });
      setCounts((prev) => ({ ...prev, [key]: count ?? 0 }));
      pending -= 1;
      if (pending === 0) setCountsLoading(false);
    });
    supabase
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", "doctor")
      .eq("seller_status", "pending")
      .then(({ count }) => setPendingSellers(count ?? 0));
  }, []);

  // Super Admin Analytics — শুধুমাত্র super_admin হলেই RPC কল হয় (enabled flag),
  // তাই সাধারণ Admin-এর জন্য কোনো এক্সট্রা কোয়েরি বা রিয়েলটাইম সাবস্ক্রিপশন
  // তৈরি হয় না, existing Admin dashboard আগের মতোই কাজ করে
  const {
    data: analytics,
    loading: analyticsLoading,
    error: analyticsError,
  } = useSuperAdminAnalytics({ enabled: isSuperAdmin });

  const totals = analytics?.totals ?? {};
  const growth = analytics?.growth ?? {};

  // দৈনিক/সাপ্তাহিক/মাসিক গ্রোথ একসাথে তুলনা করার জন্য গ্রুপড বার চার্ট ডেটা
  const growthChartData = useMemo(
    () => [
      {
        label: "দৈনিক",
        new_users: growth.daily?.new_users ?? 0,
        new_seller_applications: growth.daily?.new_seller_applications ?? 0,
        new_products: growth.daily?.new_products ?? 0,
      },
      {
        label: "সাপ্তাহিক",
        new_users: growth.weekly?.new_users ?? 0,
        new_seller_applications: growth.weekly?.new_seller_applications ?? 0,
        new_products: growth.weekly?.new_products ?? 0,
      },
      {
        label: "মাসিক",
        new_users: growth.monthly?.new_users ?? 0,
        new_seller_applications: growth.monthly?.new_seller_applications ?? 0,
        new_products: growth.monthly?.new_products ?? 0,
      },
    ],
    [growth]
  );

  const topCategoriesChartData = useMemo(
    () =>
      (analytics?.top_categories ?? []).slice(0, 5).map((c) => ({
        label: c.name,
        value: c.product_count,
      })),
    [analytics?.top_categories]
  );

  const topSellersChartData = useMemo(
    () =>
      (analytics?.top_sellers ?? []).slice(0, 5).map((s) => ({
        label: s.shop_name,
        value: s.total_order_clicks,
        color: "hsl(var(--accent))",
      })),
    [analytics?.top_sellers]
  );

  const sellerStatusChartData = useMemo(
    () => [
      { label: "ভেরিফাইড ডাক্তার", value: totals.total_verified_sellers ?? 0 },
      {
        label: "অ-ভেরিফাইড আবেদন",
        value: totals.total_unverified_seller_applications ?? 0,
        color: "hsl(var(--accent))",
      },
    ],
    [totals.total_verified_sellers, totals.total_unverified_seller_applications]
  );

  return (
    <div className="space-y-7">
      <div>
        <h1 className="text-xl font-bold sm:text-2xl" style={{ fontFamily: "'Tiro Bangla', serif" }}>
          অ্যাডমিন ড্যাশবোর্ড
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">মার্কেটপ্লেসের সার্বিক পরিসংখ্যান এক নজরে</p>
      </div>

      {/* ================= মূল সামারি কার্ড ================= */}
      <div className="grid gap-3 sm:grid-cols-2 sm:gap-4 lg:grid-cols-4">
        {STATS.map(({ key, label, icon: Icon }) => (
          <StatCard key={key} title={label} icon={Icon} value={counts[key]} loading={countsLoading} />
        ))}

        <Link to={ROUTES.ADMIN_VERIFICATIONS} className="block">
          <StatCard
            title="অপেক্ষমাণ ডাক্তার"
            icon={Users}
            value={pendingSellers}
            variant="accent"
            highlight={pendingSellers > 0}
            hint={
              pendingSellers > 0 ? (
                <span className="flex items-center gap-0.5 text-accent">
                  পর্যালোচনা করুন
                  <ArrowUpRight className="h-3 w-3" />
                </span>
              ) : null
            }
          />
        </Link>
      </div>

      {/* ================= কুইক-অ্যাক্সেস লিংক ================= */}
      <div className="grid gap-3 sm:grid-cols-2 sm:gap-4 lg:grid-cols-3">
        <Link
          to={ROUTES.ADMIN_SELLERS}
          className="flex items-center justify-between rounded-xl border border-border bg-card p-4 transition-colors hover:border-primary/40"
        >
          <span className="flex items-center gap-2 text-sm font-medium">
            <Users className="h-4 w-4 text-primary" /> ডাক্তার ম্যানেজমেন্ট
          </span>
          <ArrowUpRight className="h-4 w-4 text-muted-foreground" />
        </Link>
        <Link
          to={ROUTES.ADMIN_PRODUCTS}
          className="flex items-center justify-between rounded-xl border border-border bg-card p-4 transition-colors hover:border-primary/40"
        >
          <span className="flex items-center gap-2 text-sm font-medium">
            <Package className="h-4 w-4 text-primary" /> ডাক্তার প্রোফাইল ম্যানেজমেন্ট
          </span>
          <ArrowUpRight className="h-4 w-4 text-muted-foreground" />
        </Link>
        <Link
          to={ROUTES.ADMIN_CATEGORIES}
          className="flex items-center justify-between rounded-xl border border-border bg-card p-4 transition-colors hover:border-primary/40"
        >
          <span className="flex items-center gap-2 text-sm font-medium">
            <FolderTree className="h-4 w-4 text-primary" /> ক্যাটাগরি
          </span>
          <ArrowUpRight className="h-4 w-4 text-muted-foreground" />
        </Link>
      </div>

      {/* ================= Super Admin Analytics ================= */}
      {isSuperAdmin && (
        <div className="space-y-7 border-t border-border pt-7">
          <div>
            <h2
              className="flex items-center gap-2 text-lg font-bold sm:text-xl"
              style={{ fontFamily: "'Tiro Bangla', serif" }}
            >
              <BarChart3 className="h-5 w-5 text-primary" />
              মার্কেটপ্লেস অ্যানালিটিক্স
            </h2>
            <p className="text-sm text-muted-foreground">
              পুরো মার্কেটপ্লেসের সার্বিক পরিসংখ্যান — স্বয়ংক্রিয়ভাবে আপডেট হয় (near real-time)
            </p>
            {analyticsError && (
              <p className="mt-2 text-sm text-destructive">তথ্য লোড করা যায়নি: {analyticsError}</p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-5">
            <StatCard
              title="মোট ইউজার"
              icon={Users}
              value={totals.total_users}
              loading={analyticsLoading}
            />
            <StatCard
              title="অ-ভেরিফাইড ডাক্তার আবেদন"
              icon={ShieldAlert}
              value={totals.total_unverified_seller_applications}
              loading={analyticsLoading}
              variant="accent"
            />
            <StatCard
              title="ভেরিফাইড ডাক্তার"
              icon={BadgeCheck}
              value={totals.total_verified_sellers}
              loading={analyticsLoading}
            />
            <StatCard
              title="মোট ডাক্তার প্রোফাইল"
              icon={Package}
              value={totals.total_products}
              loading={analyticsLoading}
            />
            <StatCard
              title="মোট ডাক্তার প্রোফাইল ভিউ"
              icon={Eye}
              value={totals.total_product_views}
              loading={analyticsLoading}
              variant="accent"
            />
          </div>

          {/* ================= গ্রোথ ট্রেন্ড চার্ট ================= */}
          <div>
            <h3 className="mb-3 flex items-center gap-2 text-base font-semibold">
              <Activity className="h-4 w-4 text-primary" />
              গ্রোথ সামারি
            </h3>
            <GroupedBarChart
              title="দৈনিক / সাপ্তাহিক / মাসিক গ্রোথ"
              description="নতুন ইউজার, ডাক্তার আবেদন ও ডাক্তার প্রোফাইলের তুলনা"
              loading={analyticsLoading}
              emptyLabel="এখনো কোনো গ্রোথ ডেটা নেই"
              data={growthChartData}
              series={[
                { key: "new_users", label: "নতুন ইউজার", color: "hsl(var(--primary))" },
                {
                  key: "new_seller_applications",
                  label: "নতুন ডাক্তার আবেদন",
                  color: "hsl(var(--accent))",
                },
                { key: "new_products", label: "নতুন ডাক্তার প্রোফাইল", color: "hsl(217 91% 60%)" },
              ]}
              height={280}
            />
          </div>

          {/* ================= র‍্যাংকড চার্ট: ডাক্তার, ক্যাটাগরি, ভেরিফিকেশন ================= */}
          <div className="grid gap-4 lg:grid-cols-3">
            <BarStatChart
              title="টপ ৫ ডাক্তার"
              icon={Trophy}
              description="অর্ডার ক্লিক অনুযায়ী"
              loading={analyticsLoading}
              emptyLabel="এখনো কোনো অর্ডার ক্লিক নেই"
              data={topSellersChartData}
              valueLabel="ক্লিক"
              color="hsl(var(--accent))"
            />
            <BarStatChart
              title="টপ ৫ ক্যাটাগরি"
              icon={FolderTree}
              description="ডাক্তার প্রোফাইল সংখ্যা অনুযায়ী"
              loading={analyticsLoading}
              emptyLabel="এখনো কোনো ডাক্তার প্রোফাইল নেই"
              data={topCategoriesChartData}
              valueLabel="ডাক্তার প্রোফাইল"
            />
            <DonutStatChart
              title="ডাক্তার ভেরিফিকেশন অবস্থা"
              icon={BadgeCheck}
              loading={analyticsLoading}
              emptyLabel="এখনো কোনো ডাক্তার আবেদন নেই"
              data={sellerStatusChartData}
              centerLabel="মোট আবেদন"
            />
          </div>

          {/* ================= র‍্যাংকড লিস্ট: টপ ডাক্তার প্রোফাইল ================= */}
          <div className="grid gap-4 lg:grid-cols-2">
            <RankedListCard
              title="টপ ১০ সর্বাধিক দেখা ডাক্তার প্রোফাইল"
              icon={Eye}
              loading={analyticsLoading}
              emptyLabel="এখনো কোনো ভিউ নেই"
              items={(analytics?.top_viewed_products ?? []).map((p) => ({
                id: p.id,
                imageUrl: p.thumbnail_url,
                title: p.name,
                subtitle: p.shop_name,
                metricValue: p.view_count,
                metricLabel: "ভিউ",
              }))}
            />
            <RankedListCard
              title="টপ ১০ সর্বাধিক সেভ করা ডাক্তার প্রোফাইল"
              icon={Heart}
              loading={analyticsLoading}
              emptyLabel="এখনো কোনো সেভ নেই"
              items={(analytics?.top_saved_products ?? []).map((p) => ({
                id: p.id,
                imageUrl: p.thumbnail_url,
                title: p.name,
                subtitle: p.shop_name,
                metricValue: p.save_count,
                metricLabel: "সেভ",
              }))}
            />
          </div>
        </div>
      )}
    </div>
  );
}
