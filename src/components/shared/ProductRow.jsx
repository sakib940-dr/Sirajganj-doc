import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import ProductCard from "@/components/shared/ProductCard.jsx";
import ProductCardSkeleton from "@/components/shared/ProductCardSkeleton.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { cn } from "@/lib/utils";

/**
 * হোমপেজের "জনপ্রিয়", "ছাড়", "সাম্প্রতিক" — এই ধরনের সেকশনগুলোর জন্য
 * একটাই reusable horizontal-scroll কার্ড-রো। এতে হোমপেজ অনেকগুলো সেকশন
 * থাকলেও উল্লম্বভাবে লম্বা হয়ে যায় না — প্রতিটা সেকশন একটামাত্র স্ক্রল-রো।
 */
export default function ProductRow({
  id,
  title,
  subtitle,
  icon: Icon,
  products,
  loading,
  viewAllTo,
  emptyIcon,
  emptyTitle,
  emptyDescription,
  accentClassName,
}) {
  return (
    <section id={id} className="py-8 md:py-10">
      <div className="container">
        <div className="mb-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            {Icon && (
              <span
                className={cn(
                  "flex h-8 w-8 items-center justify-center rounded-lg bg-secondary text-primary",
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

          {viewAllTo && products?.length > 0 && (
            <Link
              to={viewAllTo}
              className="flex shrink-0 items-center gap-1 text-xs font-medium text-primary md:text-sm"
            >
              সব দেখুন <ArrowLeft className="h-3.5 w-3.5 rotate-180" />
            </Link>
          )}
        </div>
      </div>

      {loading ? (
        <div className="container">
          <div className="no-scrollbar -mx-4 flex gap-3 overflow-x-auto px-4 pb-1">
            {Array.from({ length: 5 }).map((_, i) => (
              <ProductCardSkeleton key={i} className="w-[8.5rem] shrink-0 sm:w-40 md:w-44" />
            ))}
          </div>
        </div>
      ) : !products || products.length === 0 ? (
        <div className="container">
          <EmptyState icon={emptyIcon} title={emptyTitle} description={emptyDescription} />
        </div>
      ) : (
        <div className="container">
          <div className="no-scrollbar -mx-4 flex snap-x snap-mandatory gap-3 overflow-x-auto px-4 pb-1">
            {products.map((product) => (
              <ProductCard
                key={product.id}
                product={product}
                className="w-[8.5rem] shrink-0 snap-start sm:w-40 md:w-44"
              />
            ))}
          </div>
        </div>
      )}
    </section>
  );
}
