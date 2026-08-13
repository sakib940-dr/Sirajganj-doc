import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import ProductCard from "@/components/shared/ProductCard.jsx";
import ProductCardSkeleton from "@/components/shared/ProductCardSkeleton.jsx";
import EmptyState from "@/components/shared/EmptyState.jsx";
import { cn } from "@/lib/utils";

export default function ProductRow({
  id, title, subtitle, icon: Icon, products, loading, viewAllTo, emptyIcon, emptyTitle, emptyDescription, accentClassName,
}) {
  return (
    <section id={id} className="py-7 md:py-9">
      <div className="container">
        <div className="mb-4 flex items-center justify-between">
          <div className="flex min-w-0 items-center gap-2">
            {Icon && <span className={cn("flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-secondary text-primary", accentClassName)}><Icon className="h-4 w-4" /></span>}
            <div className="min-w-0">
              <h2 className="text-lg font-bold md:text-xl" style={{ fontFamily: "'Tiro Bangla', serif" }}>{title}</h2>
              {subtitle && <p className="text-xs text-muted-foreground md:text-sm">{subtitle}</p>}
            </div>
          </div>
          {viewAllTo && products?.length > 0 && (
            <Link to={viewAllTo} className="flex shrink-0 items-center gap-1 text-xs font-medium text-primary md:text-sm">
              সব দেখুন <ArrowLeft className="h-3.5 w-3.5 rotate-180" />
            </Link>
          )}
        </div>
      </div>

      {loading ? (
        <div className="container"><div className="no-scrollbar -mx-4 flex gap-3 overflow-x-auto px-4 pb-1">
          {Array.from({ length: 4 }).map((_, i) => <ProductCardSkeleton key={i} className="h-[9.25rem] w-[20.5rem] shrink-0 sm:w-[23rem]" />)}
        </div></div>
      ) : !products || products.length === 0 ? (
        <div className="container"><EmptyState icon={emptyIcon} title={emptyTitle} description={emptyDescription} /></div>
      ) : (
        <div className="container">
          <div className="no-scrollbar -mx-4 flex snap-x snap-mandatory gap-3 overflow-x-auto px-4 pb-1">
            {products.slice(0, 10).map((product) => <ProductCard key={product.id} product={product} className="snap-start" />)}
          </div>
        </div>
      )}
    </section>
  );
}
