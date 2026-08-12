import { useMemo } from "react";
import {
  Package,
  CheckCircle2,
  PackageX,
  TrendingUp,
  Eye,
  Heart,
  MousePointerClick,
  BarChart3,
} from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { useSellerProductStats } from "@/hooks/useSellerProductStats";
import StatCard from "@/components/shared/StatCard.jsx";
import PendingApprovalNotice from "@/components/seller/PendingApprovalNotice.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { ROLES, SELLER_STATUS, isAdminOrAbove } from "@/constants/roles";
import { RankedListCard } from "@/components/admin/analytics/SuperAdminAnalyticsWidgets.jsx";
import GroupedBarChart from "@/components/shared/charts/GroupedBarChart.jsx";
import DonutStatChart from "@/components/shared/charts/DonutStatChart.jsx";

export default function AnalyticsPage() {
  const { user, role, sellerStatus } = useAuth();

  const isApprovedSeller =
    isAdminOrAbove(role) || (role === ROLES.DOCTOR && sellerStatus === SELLER_STATUS.APPROVED);

  const { products, stats, mostViewed, mostSaved, loading } = useSellerProductStats({
    user,
    enabled: isApprovedSeller && !!user,
  });

  // টপ ৫ ডাক্তার প্রোফাইলের ভিউ/সেভ/ক্লিক একসাথে তুলনা করার জন্য গ্রুপড বার চার্ট ডেটা
  const engagementChartData = useMemo(
    () =>
      [...products]
        .sort((a, b) => (b.view_count ?? 0) - (a.view_count ?? 0))
        .slice(0, 5)
        .map((p) => ({
          label: p.name?.length > 12 ? `${p.name.slice(0, 11)}…` : p.name,
          views: p.view_count ?? 0,
          saves: p.save_count ?? 0,
          clicks: p.click_count ?? 0,
        })),
    [products]
  );

  const stockChartData = useMemo(
    () => [
      { label: "স্টকে আছে", value: stats.inStockProducts },
      { label: "স্টক শেষ", value: stats.outOfStockProducts, color: "hsl(var(--destructive))" },
    ],
    [stats.inStockProducts, stats.outOfStockProducts]
  );

  if (!isApprovedSeller) {
    return <PendingApprovalNotice status={sellerStatus} />;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1
          className="flex items-center gap-2 text-xl font-bold"
          style={{ fontFamily: "'Tiro Bangla', serif" }}
        >
          <TrendingUp className="h-5 w-5 text-primary" />
          অ্যানালিটিক্স
        </h1>
        <p className="text-sm text-muted-foreground">
          আপনার চেম্বারের ডাক্তার প্রোফাইলের পরিসংখ্যান — সংখ্যাগুলো স্বয়ংক্রিয়ভাবে আপডেট হয় (near real-time)
        </p>
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
        <StatCard title="মোট ভিউ" icon={Eye} value={stats.views} loading={loading} variant="accent" />
        <StatCard title="মোট সেভ" icon={Heart} value={stats.saves} loading={loading} variant="accent" />
        <StatCard
          title="অর্ডার বাটন ক্লিক"
          icon={MousePointerClick}
          value={stats.clicks}
          loading={loading}
          variant="accent"
        />
      </div>

      {!loading && products.length === 0 ? (
        <EmptyState icon={Package} title="এখনো কোনো ডাক্তার প্রোফাইল যোগ করা হয়নি" />
      ) : (
        <>
          {/* ================= চার্ট: এক নজরে ভিজ্যুয়াল ওভারভিউ ================= */}
          <div className="grid gap-4 lg:grid-cols-3">
            <GroupedBarChart
              title="টপ ৫ ডাক্তার প্রোফাইলের এনগেজমেন্ট"
              icon={BarChart3}
              description="ভিউ, সেভ ও অর্ডার ক্লিকের তুলনা"
              loading={loading}
              emptyLabel="এখনো কোনো এনগেজমেন্ট নেই"
              data={engagementChartData}
              series={[
                { key: "views", label: "ভিউ", color: "hsl(var(--primary))" },
                { key: "saves", label: "সেভ", color: "hsl(var(--accent))" },
                { key: "clicks", label: "ক্লিক", color: "hsl(0 72% 51%)" },
              ]}
              className="lg:col-span-2"
            />
            <DonutStatChart
              title="স্টক অবস্থা"
              icon={PackageX}
              loading={loading}
              emptyLabel="এখনো কোনো ডাক্তার প্রোফাইল নেই"
              data={stockChartData}
              centerLabel="মোট ডাক্তার প্রোফাইল"
            />
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <RankedListCard
              title="সর্বাধিক দেখা ডাক্তার প্রোফাইল"
              icon={Eye}
              loading={loading}
              emptyLabel="এখনো কোনো ভিউ নেই"
              items={mostViewed.map((p) => ({
                id: p.id,
                imageUrl: p.thumbnail_url,
                title: p.name,
                metricValue: p.view_count ?? 0,
                metricLabel: "ভিউ",
              }))}
            />
            <RankedListCard
              title="সর্বাধিক সেভ করা ডাক্তার প্রোফাইল"
              icon={Heart}
              loading={loading}
              emptyLabel="এখনো কোনো সেভ নেই"
              items={mostSaved.map((p) => ({
                id: p.id,
                imageUrl: p.thumbnail_url,
                title: p.name,
                metricValue: p.save_count ?? 0,
                metricLabel: "সেভ",
              }))}
            />
          </div>

          <div>
            <h2 className="mb-3 text-base font-semibold">সব ডাক্তার প্রোফাইলের বিস্তারিত পরিসংখ্যান</h2>
            <div className="overflow-x-auto rounded-xl border border-border bg-card">
              <table className="w-full min-w-[640px] text-sm">
                <thead className="border-b border-border bg-secondary/50 text-left">
                  <tr>
                    <th className="p-3 font-medium">ডাক্তার প্রোফাইল</th>
                    <th className="p-3 font-medium">
                      <span className="inline-flex items-center gap-1.5">
                        <Eye className="h-3.5 w-3.5" /> ভিউ
                      </span>
                    </th>
                    <th className="p-3 font-medium">
                      <span className="inline-flex items-center gap-1.5">
                        <Heart className="h-3.5 w-3.5" /> সেভ
                      </span>
                    </th>
                    <th className="p-3 font-medium">
                      <span className="inline-flex items-center gap-1.5">
                        <MousePointerClick className="h-3.5 w-3.5" /> অর্ডার ক্লিক
                      </span>
                    </th>
                    <th className="p-3 font-medium">স্টক</th>
                    <th className="p-3 font-medium">অবস্থা</th>
                  </tr>
                </thead>
                <tbody>
                  {products.map((p) => (
                    <tr key={p.id} className="border-b border-border last:border-0">
                      <td className="flex items-center gap-3 p-3">
                        <div className="h-10 w-10 shrink-0 overflow-hidden rounded-lg bg-secondary">
                          {p.thumbnail_url && (
                            <img src={p.thumbnail_url} alt="" className="h-full w-full object-cover" />
                          )}
                        </div>
                        <span className="line-clamp-1 font-medium">{p.name}</span>
                      </td>
                      <td className="p-3 font-medium">{p.view_count ?? 0}</td>
                      <td className="p-3 font-medium">{p.save_count ?? 0}</td>
                      <td className="p-3 font-medium">{p.click_count ?? 0}</td>
                      <td className="p-3">
                        <span
                          className={`font-medium ${
                            Number(p.stock_quantity ?? 0) <= 0
                              ? "text-destructive"
                              : "text-foreground"
                          }`}
                        >
                          {p.stock_quantity ?? 0}
                        </span>
                      </td>
                      <td className="p-3">
                        <span
                          className={`rounded-full px-2.5 py-1 text-xs font-medium ${
                            p.is_active ? "bg-primary/10 text-primary" : "bg-muted text-muted-foreground"
                          }`}
                        >
                          {p.is_active ? "সক্রিয়" : "নিষ্ক্রিয়"}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
