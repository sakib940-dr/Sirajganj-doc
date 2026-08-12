import Skeleton from "@/components/shared/Skeleton.jsx";

export default function CategoryCardSkeleton() {
  return (
    <div className="flex flex-col items-center gap-3 rounded-xl border border-border bg-card p-4">
      <Skeleton className="h-14 w-14 rounded-full" />
      <Skeleton className="h-3 w-3/4" />
    </div>
  );
}
