import ProductCardSkeleton from "@/components/shared/ProductCardSkeleton.jsx";
import { cn } from "@/lib/utils";

export default function ProductGridSkeleton({ count = 8, className }) {
  return (
    <div className={cn("grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4", className)}>
      {Array.from({ length: count }).map((_, i) => (
        <ProductCardSkeleton key={i} />
      ))}
    </div>
  );
}
