import { useMemo } from "react";
import { Link } from "react-router-dom";
import {
  Package,
  CheckCircle2,
  PackageX,
  Eye,
  Heart,
  MousePointerClick,
  ArrowUpRight,
  Store,
  TrendingUp,
} from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { useSellerProductStats } from "@/hooks/useSellerProductStats";
import PendingApprovalNotice from "@/components/seller/PendingApprovalNotice.jsx";
import StatCard from "@/components/shared/StatCard.jsx";
import BarStatChart from "@/components/shared/charts/BarStatChart.jsx";
import DonutStatChart from "@/components/shared/charts/DonutStatChart.jsx";
import { ROUTES } from "@/constants/routes";
import { ROLES, SELLER_STATUS, isAdminOrAbove } from "@/constants/roles";

export default function DashboardHome() {
  const { user, role, sellerStatus, profile } = useAuth();

  const isApprovedSeller =
    isAdminOrAbove(role) || (role === ROLES.DOCTOR && sellerStatus === SELLER_STATUS.APPROVED);

  const { products, stats, mostViewed, loading } = useSellerProductStats({
    user,
    enabled: isApprovedSeller && !!user,
  });

  const topProductsChartData = useMemo(
    () =>
      mostViewed.map((p) => ({
        label: p.name,
        value: p.view_count ?? 0,
      })),
    [mostViewed]
  );

  const statusChartData = useMemo(
    () => [
      { label: "সক্রিয় ডাক্তার প্রোফাইল", value: stats.activeProducts },
      { label: "নিষ্ক্রিয় ডাক্তার প্রোফাইল", value: stats.inactiveProducts, color: "hsl(var(--muted-foreground))" },
    ],
    [stats.activeProducts, stats.inactiveProducts]
  );

  if (!isApprovedSeller) {
    return <PendingApprovalNotice status={sellerStatus} />;
  }

  return (
    <div className="space-y-6">
      {/* ================= স্বাগতম ব্যানার ================= */}
      <div className="rounded-2xl border border-border bg-gradient-to-br from-primary/5 via-card to-card p-5 sm:p-6">
        <h1
          className="text-lg font-bold sm:text-xl"
          style={{ fontFamily: "'Tiro Bangla', serif" }}
        >
          স্বাগতম, {profile?.full_name || "ডাক্তার"}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">আপনার চেম্বার এখান থেকে পরিচালনা করুন</p>
      </div>

      {/* ================= সামারি কার্ড: এক নজরে সবকিছু ================= */}
      <div>
        <div className="mb-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-sm font-semibold text-muted-foreground sm:text-base">
              {role === "hospital" ? "আপনার চেম্বার/হাসপাতালের সারসংক্ষেপ" : "আপনার চেম্বারের সারসংক্ষেপ"}
            </h2>
            <p className="mt-0.5 text-xs text-muted-foreground">ডাক্তার প্রোফাইল, ভিউ ও রোগীর অনুরোধ এক নজরে দেখুন</p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Link to={ROUTES.DASHBOARD_APPOINTMENTS} className="inline-flex items-center justify-center rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground shadow-sm">
              অ্যাপয়েন্টমেন্টের অনুরোধ
            </Link>
            <Link to={ROUTES.DASHBOARD_ANALYTICS} className="inline-flex items-center gap-1 rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-medium text-foreground">
              পূর্ণ অ্যানালিটিক্স <ArrowUpRight className="h-3.5 w-3.5" />
            </Link>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-6">
          <StatCard title="মোট ডাক্তার প্রোফাইল" icon={Package} value={stats.totalProducts} loading={loading} />
          <StatCard
            title="সক্রিয় ডাক্তার প্রোফাইল"
            icon={CheckCircle2}
            value={stats.activeProducts}
            loading={loading}
          />
          <StatCard
            title="স্টক শেষ"
            icon={PackageX}
            value={stats.outOfStockProducts}
            loading={loading}
            variant={stats.outOfStockProducts > 0 ? "destructive" : "primary"}
          />
          <StatCard
            title="মোট ভিউ"
            icon={Eye}
            value={stats.views}
            loading={loading}
            variant="accent"
          />
          <StatCard
            title="মোট সেভ"
            icon={Heart}
            value={stats.saves}
            loading={loading}
            variant="accent"
          />
          <StatCard
            title="অর্ডার ক্লিক"
            icon={MousePointerClick}
            value={stats.clicks}
            loading={loading}
            variant="accent"
          />
        </div>
      </div>

      {/* ================= চার্ট: এক নজরে ভিজ্যুয়াল ওভারভিউ ================= */}
      {(loading || products.length > 0) && (
        <div className="grid gap-4 lg:grid-cols-2">
          <BarStatChart
            title="সর্বাধিক দেখা ডাক্তার প্রোফাইল"
            icon={TrendingUp}
            description="ভিউ অনুযায়ী টপ ৫ ডাক্তার প্রোফাইল"
            loading={loading}
            emptyLabel="এখনো কোনো ভিউ নেই"
            data={topProductsChartData}
            valueLabel="ভিউ"
          />
          <DonutStatChart
            title="ডাক্তার প্রোফাইলের অবস্থা"
            icon={Package}
            description="সক্রিয় বনাম নিষ্ক্রিয় ডাক্তার প্রোফাইল"
            loading={loading}
            emptyLabel="এখনো কোনো ডাক্তার প্রোফাইল নেই"
            data={statusChartData}
            centerLabel="মোট ডাক্তার প্রোফাইল"
          />
        </div>
      )}

      {/* ================= শপ সেটআপ CTA ================= */}
      <div className="flex flex-col gap-3 rounded-xl border border-accent/40 bg-accent/10 p-4 text-sm sm:flex-row sm:items-center sm:justify-between">
        <span className="flex items-center gap-2">
          <Store className="h-4 w-4 shrink-0 text-accent" />
          {role === "hospital" ? "আপনার চেম্বার/হাসপাতালের তথ্য পূরণ বা হালনাগাদ করতে চান?" : "আপনার চেম্বারের তথ্য পূরণ বা হালনাগাদ করতে চান?"}
        </span>
        <Link
          to={ROUTES.DASHBOARD_SHOP}
          className="inline-flex shrink-0 items-center gap-1 font-medium text-primary hover:underline"
        >
          এখনই দেখুন
          <ArrowUpRight className="h-3.5 w-3.5" />
        </Link>
      </div>
    </div>
  );
}
