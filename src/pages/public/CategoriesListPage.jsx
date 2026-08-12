import { Tag } from "lucide-react";
import CategoryCard from "@/components/shared/CategoryCard.jsx";
import CategoryCardSkeleton from "@/components/shared/CategoryCardSkeleton.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { useCategories } from "@/hooks/useCategories";

// Bottom Navigation-এর "ক্যাটাগরি" ট্যাব থেকে সরাসরি এখানে আসা যায় — সব
// মূল ক্যাটাগরির সম্পূর্ণ তালিকা (হোমপেজে একই ক্যাটাগরি সংক্ষিপ্তভাবে
// দেখানো হয়)। বিদ্যমান useCategories({ rootOnly: true }) হুক reuse করা
// হয়েছে — নতুন query/backend পরিবর্তন লাগেনি।
export default function CategoriesListPage() {
  const { categories, loading } = useCategories({ rootOnly: true });

  return (
    <div className="container py-6 md:py-10">
      <div className="mb-5">
        <h1
          className="text-xl font-bold md:text-2xl"
          style={{ fontFamily: "'Tiro Bangla', serif" }}
        >
          সব ক্যাটাগরি
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">যা খুঁজছেন তা ক্যাটাগরি ধরে বেছে নিন</p>
      </div>

      {loading ? (
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-4 md:grid-cols-6">
          {Array.from({ length: 12 }).map((_, i) => (
            <CategoryCardSkeleton key={i} />
          ))}
        </div>
      ) : categories.length === 0 ? (
        <EmptyState
          icon={Tag}
          title="এখনো কোনো ক্যাটাগরি যোগ করা হয়নি"
          description="অ্যাডমিন প্যানেল থেকে ক্যাটাগরি যোগ করলে তা এখানে দেখা যাবে।"
        />
      ) : (
        <div className="grid grid-cols-3 gap-3 sm:grid-cols-4 md:grid-cols-6">
          {categories.map((cat) => (
            <CategoryCard key={cat.id} category={cat} />
          ))}
        </div>
      )}
    </div>
  );
}
