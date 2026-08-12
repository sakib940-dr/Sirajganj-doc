import Skeleton from "@/components/shared/Skeleton.jsx";

export default function CategoryChipSkeleton() {
  return (
    <div className="flex w-16 shrink-0 flex-col items-center gap-1.5 sm:w-[4.75rem]">
      <Skeleton className="h-14 w-14 rounded-full sm:h-16 sm:w-16" />
      <Skeleton className="h-2.5 w-10 rounded" />
    </div>
  );
}
