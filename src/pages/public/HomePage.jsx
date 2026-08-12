import { useEffect, useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { Search, Tag, Store, Package, Flame, Sparkles } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import CategoryChipsRow from "@/components/shared/CategoryChipsRow.jsx";
import CategoryChipSkeleton from "@/components/shared/CategoryChipSkeleton.jsx";
import BannerCarousel from "@/components/shared/BannerCarousel.jsx";
import ShopRow from "@/components/shared/ShopRow.jsx";
import ProductRow from "@/components/shared/ProductRow.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { useCategories } from "@/hooks/useCategories";
import { useShops } from "@/hooks/useShops";
import { useLatestProducts, usePopularProducts } from "@/hooks/useProducts";
import { useBanners } from "@/hooks/useBanners";
import { useSiteSettings } from "@/hooks/useSiteSettings";
import { ROUTES } from "@/constants/routes";

export default function HomePage() {
  const [query, setQuery] = useState("");
  const navigate = useNavigate();
  const location = useLocation();

  // Bottom Navigation-এর "🛍️ চেম্বার" ট্যাব থেকে এলে (#shops হ্যাশ) সরাসরি
  // "জনপ্রিয় চেম্বারসমূহ" সেকশনে স্মুথ-স্ক্রল করে নিয়ে যাওয়া হয় — এর জন্য
  // আলাদা কোনো নতুন পেজ/রুট বানানো হয়নি, বিদ্যমান হোমপেজ সেকশনই ব্যবহার হচ্ছে।
  useEffect(() => {
    if (location.hash === "#shops") {
      document.getElementById("shops")?.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }, [location.hash]);

  const { categories, loading: catLoading } = useCategories({ rootOnly: true });
  const { shops, loading: shopLoading } = useShops({ limit: 6 });
  const { products: latestProducts, loading: latestLoading } = useLatestProducts({ limit: 10 });
  const { products: popularProducts, loading: popularLoading } = usePopularProducts({ limit: 10 });
  const { banners } = useBanners();
  const { settings } = useSiteSettings();

  const handleSearch = (e) => {
    e.preventDefault();
    if (query.trim()) navigate(`${ROUTES.SEARCH}?q=${encodeURIComponent(query.trim())}`);
  };

  return (
    <div>
      {/* Hero — কম্প্যাক্ট, রঙিন, আধুনিক ই-কমার্স-স্টাইল ব্যানার। আগে এটি মোবাইল
          স্ক্রিনের প্রায় অর্ধেক জায়গা নিতো (py-16), যা প্রথম ইম্প্রেশনের জন্য
          ভালো ছিল না — তাই ভার্টিক্যাল প্যাডিং/স্পেসিং অনেকটা কমানো হয়েছে ও
          গ্র্যাডিয়েন্ট ব্যাকগ্রাউন্ড দিয়ে আরও প্রাণবন্ত লুক দেওয়া হয়েছে। */}
      <section className="relative overflow-hidden bg-gradient-to-br from-primary via-primary to-emerald-800 text-primary-foreground">
        <div
          className="absolute inset-0 opacity-[0.07]"
          style={{
            backgroundImage:
              "repeating-linear-gradient(45deg, currentColor 0, currentColor 1px, transparent 1px, transparent 14px)",
          }}
        />
        <div
          className="absolute -right-16 -top-16 h-48 w-48 rounded-full bg-accent/20 blur-3xl md:h-64 md:w-64"
          aria-hidden="true"
        />
        <div className="container relative py-6 text-center md:py-12">
          <p className="mb-2 inline-flex items-center gap-1.5 rounded-full bg-accent/15 px-3 py-1 text-[11px] font-semibold text-accent md:mb-3 md:text-xs">
            আপনার এলাকার নির্ভরযোগ্য চেম্বার খুঁজুন
          </p>
          <h1
            className="mx-auto max-w-2xl text-xl font-bold leading-tight md:text-4xl"
            style={{ fontFamily: "'Tiro Bangla', serif" }}
          >
            স্থানীয় চেম্বার আর ডাক্তার প্রোফাইল —<br className="hidden sm:block" /> এখন সব এক জায়গায়
          </h1>
          <p className="mx-auto mt-2 hidden max-w-lg text-sm text-primary-foreground/75 sm:block md:mt-3 md:text-base">
            আপনার পাড়ার প্রিয় চেম্বারগুলোকে অনলাইনে খুঁজে নিন, ডাক্তার প্রোফাইল দেখুন, আর সরাসরি যোগাযোগ করুন।
          </p>

          <form onSubmit={handleSearch} className="mx-auto mt-4 flex max-w-lg gap-2 md:mt-6">
            <div className="relative flex-1">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="যেমন: শাড়ি, মোবাইল, খাবার..."
                className="h-10 rounded-lg pl-10 text-sm text-foreground md:h-12 md:text-base"
              />
            </div>
            <Button type="submit" size="lg" variant="accent" className="shrink-0">
              খুঁজুন
            </Button>
          </form>
        </div>
        <div className="kantha-divider" />
      </section>

      {/* Admin Banners (থাকলে) — CMS-driven, snap-scroll carousel */}
      <BannerCarousel banners={banners} />

      {/* Categories — কম্প্যাক্ট horizontal-scroll circle রো (২-সারি) */}
      <section className="container py-8 md:py-10">
        <div className="mb-4">
          <h2 className="text-lg font-bold md:text-xl" style={{ fontFamily: "'Tiro Bangla', serif" }}>
            ক্যাটাগরি অনুযায়ী দেখুন
          </h2>
          <p className="text-xs text-muted-foreground md:text-sm">যা খুঁজছেন তা সহজে বেছে নিন</p>
        </div>

        {catLoading ? (
          <div className="no-scrollbar -mx-4 flex gap-3 overflow-x-auto px-4 pb-1">
            {Array.from({ length: 7 }).map((_, i) => (
              <CategoryChipSkeleton key={i} />
            ))}
          </div>
        ) : categories.length === 0 ? (
          <EmptyState
            icon={Tag}
            title="এখনো কোনো ক্যাটাগরি যোগ করা হয়নি"
            description="অ্যাডমিন প্যানেল থেকে ক্যাটাগরি যোগ করলে তা এখানে দেখা যাবে।"
          />
        ) : (
          <CategoryChipsRow categories={categories} twoRow={categories.length > 6} />
        )}
      </section>

      {/* জনপ্রিয় ডাক্তার প্রোফাইল — sold_count/view_count অনুযায়ী */}
      <ProductRow
        title="জনপ্রিয় ডাক্তার প্রোফাইল"
        subtitle="সবচেয়ে বেশি দেখা ডাক্তার প্রোফাইলগুলো"
        icon={Flame}
        accentClassName="bg-destructive/10 text-destructive"
        products={popularProducts}
        loading={popularLoading}
        emptyIcon={Package}
        emptyTitle="এখনো কোনো জনপ্রিয় ডাক্তার প্রোফাইল নেই"
        emptyDescription="ডাক্তার প্রোফাইলের ভিউ বাড়লে এখানে দেখানো হবে।"
      />

      {/* Featured Shops — কম্প্যাক্ট horizontal-scroll রো, প্রোডাক্ট রো-গুলোর সাথে সামঞ্জস্যপূর্ণ */}
      <ShopRow
        id="shops"
        title="জনপ্রিয় চেম্বারসমূহ"
        subtitle="নতুন যুক্ত হওয়া বিশ্বস্ত চেম্বারগুলো দেখুন"
        icon={Store}
        accentClassName="bg-secondary text-primary"
        shops={shops}
        loading={shopLoading}
        viewAllTo={ROUTES.SHOPS}
        emptyIcon={Store}
        emptyTitle="এখনো কোনো চেম্বার অনুমোদিত হয়নি"
        emptyDescription="ডাক্তাররা অনুমোদন পেলে তাদের চেম্বার এখানে প্রদর্শিত হবে।"
      />

      {/* সাম্প্রতিক ডাক্তার প্রোফাইল */}
      <ProductRow
        title="সাম্প্রতিক ডাক্তার প্রোফাইল"
        subtitle="সদ্য যুক্ত হওয়া ডাক্তার প্রোফাইলগুলো ঘুরে দেখুন"
        icon={Sparkles}
        accentClassName="bg-primary/10 text-primary"
        products={latestProducts}
        loading={latestLoading}
        viewAllTo={ROUTES.SEARCH}
        emptyIcon={Package}
        emptyTitle="এখনো কোনো ডাক্তার প্রোফাইল যোগ করা হয়নি"
        emptyDescription="ডাক্তাররা ডাক্তার প্রোফাইল যোগ করলে তা এখানে দেখানো হবে।"
      />
    </div>
  );
}
