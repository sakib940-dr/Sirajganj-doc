import { useParams, Link } from "react-router-dom";
import { useEffect, useState } from "react";
import { Package } from "lucide-react";
import { useProductsByCategory } from "@/hooks/useProducts";
import { supabase } from "@/lib/supabaseClient";
import { categoryPath } from "@/constants/routes";
import ProductCard from "@/components/shared/ProductCard.jsx";
import ProductGridSkeleton from "@/components/shared/ProductGridSkeleton.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";

export default function CategoryPage() {
  const { slug } = useParams();
  const { products, subCategories, loading } = useProductsByCategory(slug);
  const [categoryName, setCategoryName] = useState("");

  useEffect(() => {
    supabase
      .from("categories")
      .select("name")
      .eq("slug", slug)
      .single()
      .then(({ data }) => setCategoryName(data?.name || ""));
  }, [slug]);

  return (
    <div className="container py-10">
      <h1 className="mb-6 text-2xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
        {categoryName ? `${categoryName} — সব ডাক্তার প্রোফাইল` : "ক্যাটাগরির ডাক্তার প্রোফাইল"}
      </h1>

      {subCategories.length > 0 && (
        <div className="mb-6 flex flex-wrap gap-2">
          {subCategories.map((sub) => (
            <Link
              key={sub.id}
              to={categoryPath(sub.slug)}
              className="rounded-full border border-border bg-card px-3.5 py-1.5 text-xs font-medium text-foreground/80 transition-colors hover:border-primary/40 hover:text-primary"
            >
              {sub.name}
            </Link>
          ))}
        </div>
      )}

      {loading ? (
        <ProductGridSkeleton />
      ) : products.length === 0 ? (
        <EmptyState
          icon={Package}
          title="এই ক্যাটাগরিতে এখনো কোনো ডাক্তার প্রোফাইল নেই"
          description="পরে আবার চেষ্টা করুন অথবা অন্য ক্যাটাগরি দেখুন।"
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
