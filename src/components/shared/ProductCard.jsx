import { Link } from "react-router-dom";
import { UserRound, MapPin, BadgeCheck } from "lucide-react";
import { productPath } from "@/constants/routes";
import { formatPriceBn, cn } from "@/lib/utils";

export default function ProductCard({ product, className }) {
  const chamber = product.shops;
  return (
    <Link to={productPath(product.slug)} className={cn("group block overflow-hidden rounded-xl border border-border bg-card transition-all hover:-translate-y-0.5 hover:shadow-md active:scale-[0.98]", className)}>
      <div className="relative aspect-square w-full bg-secondary">
        {product.thumbnail_url ? <img src={product.thumbnail_url} alt={product.name} className="h-full w-full object-cover transition-transform group-hover:scale-105" loading="lazy"/> :
          <div className="flex h-full items-center justify-center text-muted-foreground"><UserRound className="h-9 w-9"/></div>}
        {product.verified_badge && <span className="absolute left-2 top-2 inline-flex items-center gap-1 rounded-full bg-background/90 px-2 py-1 text-[10px] font-semibold text-primary shadow"><BadgeCheck className="h-3 w-3"/> Verified</span>}
      </div>
      <div className="space-y-1.5 p-2.5">
        <h3 className="line-clamp-2 min-h-[2.25em] text-[13px] font-semibold leading-tight text-foreground group-hover:text-primary">{product.name}</h3>
        {product.designation&&<p className="line-clamp-1 text-[11px] text-muted-foreground">{product.designation}</p>}
        {product.degree&&<p className="line-clamp-1 text-[11px] text-muted-foreground">{product.degree}</p>}
        <div className="text-sm font-bold text-primary">{formatPriceBn(product.consultation_fee ?? product.price)}</div>
        {chamber?.shop_name&&<p className="flex items-center gap-1 truncate text-[11px] text-muted-foreground"><MapPin className="h-3 w-3 shrink-0"/><span className="truncate">{chamber.chamber_name||chamber.shop_name}</span></p>}
      </div>
    </Link>
  );
}
