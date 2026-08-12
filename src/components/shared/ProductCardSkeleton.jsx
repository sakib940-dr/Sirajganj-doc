import Skeleton from "@/components/shared/Skeleton.jsx";
import { cn } from "@/lib/utils";

export default function ProductCardSkeleton({ className }) {
  return (
    <div className={cn("overflow-hidden rounded-xl border border-border bg-card", className)}>
      <Skeleton className="aspect-square w-full rounded-none" />
      <div className="space-y-2 p-2.5">
        <Skeleton className="h-3.5 w-full" />
        <Skeleton className="h-3.5 w-3/5" />
        <Skeleton className="h-3 w-2/5" />
      </div>
    </div>
  );
}
