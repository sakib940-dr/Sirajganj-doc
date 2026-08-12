import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import ShopCard from "@/components/shared/ShopCard.jsx";
import ShopCardSkeleton from "@/components/shared/ShopCardSkeleton.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { cn } from "@/lib/utils";

/**
 * হোমপেজের "জনপ্রিয় চেম্বারসমূহ" সেকশন — বড় গ্রিডের বদলে কম্প্যাক্ট
 * horizontal-scroll রো, ProductRow-এর সাথে ভিজ্যুয়ালি সামঞ্জস্যপূর্ণ।
 * সব চেম্বারের সম্পূর্ণ তালিকা এখনো /shops পেজে গ্রিড-আকারেই থাকছে।
 */
export default function ShopRow({
  id,
  title,
  subtitle,
  icon: Icon,
  shops,
  loading,
  viewAllTo,
  emptyIcon,
  emptyTitle,
  emptyDescription,
  accentClassName,
}) {
  return (
    <section id={id} className="bg-secondary/40 py-8 md:py-10">
      <div className="container">
        <div className="mb-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            {Icon && (
              <span
                className={cn(
                  "flex h-8 w-8 items-center justify-center rounded-lg bg-card text-primary",
                  accentClassName
                )}
              >
                <Icon className="h-4 w-4" />
              </span>
            )}
            <div>
              <h2 className="text-lg font-bold md:text-xl" style={{ fontFamily: "'Tiro Bangla', serif" }}>
                {title}
              </h2>
              {subtitle && <p className="text-xs text-muted-foreground md:text-sm">{subtitle}</p>}
            </div>
          </div>

          {viewAllTo && shops?.length > 0 && (
            <Link
              to={viewAllTo}
              className="flex shrink-0 items-center gap-1 text-xs font-medium text-primary md:text-sm"
            >
              সব দেখুন <ArrowLeft className="h-3.5 w-3.5 rotate-180" />
            </Link>
          )}
        </div>

        {loading ? (
          <div className="no-scrollbar -mx-4 flex gap-3 overflow-x-auto px-4 pb-1">
            {Array.from({ length: 4 }).map((_, i) => (
              <ShopCardSkeleton key={i} className="w-56 shrink-0 sm:w-64" />
            ))}
          </div>
        ) : !shops || shops.length === 0 ? (
          <EmptyState icon={emptyIcon} title={emptyTitle} description={emptyDescription} />
        ) : (
          <div className="no-scrollbar -mx-4 flex snap-x snap-mandatory gap-3 overflow-x-auto px-4 pb-1">
            {shops.map((shop) => (
              <ShopCard
                key={shop.id}
                shop={shop}
                className="w-56 shrink-0 snap-start sm:w-64"
              />
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
