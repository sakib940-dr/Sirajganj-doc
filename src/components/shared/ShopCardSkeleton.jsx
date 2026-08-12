import Skeleton from "@/components/shared/Skeleton.jsx";
import { cn } from "@/lib/utils";

export default function ShopCardSkeleton({ className }) {
  return (
    <div className={cn("overflow-hidden rounded-xl border border-border bg-card", className)}>
      <Skeleton className="h-16 w-full rounded-none sm:h-20" />
      <div className="flex items-center gap-3 p-3 pt-0">
        <Skeleton className="-mt-6 h-12 w-12 shrink-0 rounded-xl border-4 border-card" />
        <div className="min-w-0 flex-1 space-y-2 pt-1">
          <Skeleton className="h-3.5 w-3/4" />
          <Skeleton className="h-3 w-1/2" />
        </div>
      </div>
    </div>
  );
}
