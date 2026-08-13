import { useSearchParams } from "react-router-dom";
import { Search, MapPin, Flame, Sparkles } from "lucide-react";
import ProductCard from "@/components/shared/ProductCard.jsx";
import ProductGridSkeleton from "@/components/shared/ProductGridSkeleton.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { useDoctorsDirectory } from "@/hooks/useDoctorsDirectory";

export default function DoctorsListPage() {
  const [params, setParams] = useSearchParams();
  const page = Math.max(1, Number(params.get("page") || 1));
  const district = params.get("district") || "";
  const upazila = params.get("upazila") || "";
  const section = params.get("section") || "popular";
  const q = params.get("q") || "";
  const { products, total, loading } = useDoctorsDirectory({ district, upazila, section, query: q, page, pageSize: 20 });
  const totalPages = Math.max(1, Math.ceil(total / 20));
  const title = upazila ? `${upazila} এলাকার ডাক্তার` : district ? `${district} জেলার সকল ডাক্তার` : section === "latest" ? "সাম্প্রতিক ডাক্তার প্রোফাইল" : "জনপ্রিয় ডাক্তার প্রোফাইল";
  const subtitle = `${total} জন ডাক্তার • প্রতি পাতায় ২০ জন`;
  const go = (nextPage) => setParams({ ...(district ? { district } : {}), ...(upazila ? { upazila } : {}), ...(q ? { q } : {}), section, page: String(nextPage) });

  return (
    <div className="container py-7 md:py-10">
      <div className="mb-5 flex items-end justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold md:text-2xl" style={{ fontFamily: "'Tiro Bangla', serif" }}>{title}</h1>
          <p className="mt-1 text-xs text-muted-foreground md:text-sm">{subtitle}</p>
        </div>
        <span className="hidden rounded-full bg-secondary px-3 py-1 text-xs font-medium text-primary sm:inline-flex">২০ জন/পাতা</span>
      </div>

      {loading ? <ProductGridSkeleton count={8} /> : products.length === 0 ? (
        <EmptyState icon={Search} title="কোনো ডাক্তার পাওয়া যায়নি" description="অন্য এলাকা বা ভিন্ন অনুসন্ধান দিয়ে চেষ্টা করুন।" />
      ) : (
        <div className="grid grid-cols-1 gap-3">
          {products.map((product) => <ProductCard key={product.id} product={product} variant="horizontal" className="w-full" />)}
        </div>
      )}

      {totalPages > 1 && (
        <div className="mt-7 flex items-center justify-center gap-2">
          <button disabled={page <= 1} onClick={() => go(page - 1)} className="rounded-lg border px-4 py-2 text-sm disabled:opacity-40">আগের পাতা</button>
          <span className="px-2 text-sm text-muted-foreground">{page} / {totalPages}</span>
          <button disabled={page >= totalPages} onClick={() => go(page + 1)} className="rounded-lg bg-primary px-4 py-2 text-sm text-primary-foreground disabled:opacity-40">পরের পাতা</button>
        </div>
      )}
    </div>
  );
}
