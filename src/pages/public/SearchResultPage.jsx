import { useSearchParams } from "react-router-dom";
import { Search } from "lucide-react";
import { useProductSearch } from "@/hooks/useProducts";
import ProductCard from "@/components/shared/ProductCard.jsx";
import ProductGridSkeleton from "@/components/shared/ProductGridSkeleton.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";

export default function SearchResultPage() {
  const [searchParams] = useSearchParams();
  const q = searchParams.get("q") || "";
  const { products, loading } = useProductSearch(q);

  return (
    <div className="container py-10">
      <h1 className="mb-1 text-2xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
        অনুসন্ধানের ফলাফল
      </h1>
      <p className="mb-6 text-sm text-muted-foreground">
        “{q}” এর জন্য {products.length} টি ডাক্তার প্রোফাইল পাওয়া গেছে
      </p>

      {loading ? (
        <ProductGridSkeleton />
      ) : products.length === 0 ? (
        <EmptyState
          icon={Search}
          title="কোনো ডাক্তার প্রোফাইল পাওয়া যায়নি"
          description="ভিন্ন কিওয়ার্ড দিয়ে আবার চেষ্টা করুন।"
        />
      ) : (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4">
          {products.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      )}
    </div>
  );
}
