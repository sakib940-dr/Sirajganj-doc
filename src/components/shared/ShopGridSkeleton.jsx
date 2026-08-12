import ShopCardSkeleton from "@/components/shared/ShopCardSkeleton.jsx";
import { cn } from "@/lib/utils";

export default function ShopGridSkeleton({ count = 6, className }) {
  return (
    <div className={cn("grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3", className)}>
      {Array.from({ length: count }).map((_, i) => (
        <ShopCardSkeleton key={i} />
      ))}
    </div>
  );
}
