import { Link } from "react-router-dom";
import { UserRound, MapPin, BadgeCheck, Stethoscope } from "lucide-react";
import { productPath } from "@/constants/routes";
import { cn } from "@/lib/utils";

export default function ProductCard({ product, className }) {
  const chamber = product.shops;
  return (
    <Link to={productPath(product.slug)} className={cn("group block overflow-hidden rounded-xl border border-border bg-card transition-all hover:-translate-y-0.5 hover:shadow-md active:scale-[0.98]", className)}>
      <div className="relative aspect-[5/4] w-full bg-secondary">
        {product.thumbnail_url ? <img src={product.thumbnail_url} alt={product.name} className="h-full w-full object-cover transition-transform group-hover:scale-105" loading="lazy"/> :
          <div className="flex h-full items-center justify-center text-muted-foreground"><UserRound className="h-9 w-9"/></div>}
        {product.verified_badge && <span className="absolute left-2 top-2 inline-flex items-center gap-1 rounded-full bg-background/90 px-2 py-1 text-[10px] font-semibold text-primary shadow"><BadgeCheck className="h-3 w-3"/> ভেরিফাইড</span>}
      </div>
      <div className="space-y-1.5 p-3">
        <h3 className="line-clamp-1 text-base font-bold leading-tight text-foreground group-hover:text-primary">{product.name}</h3>
        {product.degree&&<p className="line-clamp-1 text-xs text-muted-foreground">{product.degree}</p>}
        {product.designation&&<p className="line-clamp-1 text-xs text-muted-foreground">{product.designation}</p>}
        {product.bmdc_registration_no&&<p className="line-clamp-1 text-xs text-muted-foreground">বিএমডিসি: {product.bmdc_registration_no}</p>}
        {chamber?.chamber_name||chamber?.shop_name ? <p className="flex items-start gap-1 text-xs font-medium text-foreground"><Stethoscope className="mt-0.5 h-3 w-3 shrink-0 text-primary"/><span className="line-clamp-1">{chamber.chamber_name||chamber.shop_name}</span></p> : null}
        {chamber?.address&&<p className="flex items-start gap-1 text-xs text-muted-foreground"><MapPin className="mt-0.5 h-3 w-3 shrink-0"/><span className="line-clamp-2">{chamber.address}</span></p>}
      </div>
    </Link>
  );
}
