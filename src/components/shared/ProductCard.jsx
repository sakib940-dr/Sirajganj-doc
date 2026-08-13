import { Link } from "react-router-dom";
import { UserRound, MapPin, BadgeCheck, Stethoscope, Navigation } from "lucide-react";
import { productPath } from "@/constants/routes";
import { cn } from "@/lib/utils";

function getDistanceKm(product) {
  const distance = product?.distance_km ?? product?.shops?.distance_km;
  if (distance == null || Number.isNaN(Number(distance))) return null;
  return Number(distance) < 10 ? Number(distance).toFixed(1) : Math.round(Number(distance));
}

export default function ProductCard({ product, className, variant = "horizontal", distanceKm }) {
  const chamber = product.shops;
  const distance = distanceKm ?? getDistanceKm(product);

  if (variant === "grid") {
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
          {product.specialty&&<p className="line-clamp-1 text-xs text-muted-foreground">{product.specialty}</p>}
          {product.bmdc_registration_no&&<p className="line-clamp-1 text-xs text-muted-foreground">বিএমডিসি: {product.bmdc_registration_no}</p>}
          {chamber?.chamber_name||chamber?.shop_name ? <p className="flex items-start gap-1 text-xs font-medium text-foreground"><Stethoscope className="mt-0.5 h-3 w-3 shrink-0 text-primary"/><span className="line-clamp-1">{chamber.chamber_name||chamber.shop_name}</span></p> : null}
          {chamber?.address&&<p className="flex items-start gap-1 text-xs text-muted-foreground"><MapPin className="mt-0.5 h-3 w-3 shrink-0"/><span className="line-clamp-2">{chamber.address}</span></p>}
        </div>
      </Link>
    );
  }

  return (
    <Link
      to={productPath(product.slug)}
      className={cn(
        "group flex h-[9.25rem] w-[20.5rem] shrink-0 overflow-hidden rounded-2xl border border-border bg-card transition-all hover:-translate-y-0.5 hover:shadow-md active:scale-[0.99] sm:w-[23rem]",
        className
      )}
    >
      <div className="relative h-full w-[8rem] shrink-0 bg-secondary sm:w-[8.75rem]">
        {product.thumbnail_url ? (
          <img src={product.thumbnail_url} alt={product.name} className="h-full w-full object-cover" loading="lazy" />
        ) : (
          <div className="flex h-full items-center justify-center text-muted-foreground"><UserRound className="h-12 w-12" /></div>
        )}
        {product.verified_badge && (
          <span className="absolute left-2 top-2 inline-flex items-center gap-1 rounded-full bg-background/90 px-2 py-1 text-[9px] font-semibold text-primary shadow">
            <BadgeCheck className="h-3 w-3" /> ভেরিফাইড
          </span>
        )}
      </div>
      <div className="min-w-0 flex-1 space-y-1 px-3 py-2.5">
        <h3 className="line-clamp-1 text-[15px] font-bold leading-tight text-foreground group-hover:text-primary">{product.name}</h3>
        {product.degree && <p className="line-clamp-1 text-[11px] leading-4 text-muted-foreground">{product.degree}</p>}
        {product.specialty && <p className="line-clamp-1 text-[11px] leading-4 font-medium text-primary">{product.specialty}</p>}
        {product.designation && <p className="line-clamp-1 text-[11px] leading-4 text-muted-foreground">{product.designation}</p>}
        {product.bmdc_registration_no && <p className="line-clamp-1 text-[10px] leading-4 text-muted-foreground">বিএমডিসি: {product.bmdc_registration_no}</p>}
        {chamber?.chamber_name || chamber?.shop_name ? (
          <p className="flex items-start gap-1 text-[10px] font-medium leading-4 text-foreground">
            <Stethoscope className="mt-0.5 h-3 w-3 shrink-0 text-primary" />
            <span className="line-clamp-1">{chamber.chamber_name || chamber.shop_name}</span>
          </p>
        ) : null}
        {chamber?.address && (
          <p className="flex items-start gap-1 text-[10px] leading-4 text-muted-foreground">
            <MapPin className="mt-0.5 h-3 w-3 shrink-0" />
            <span className="line-clamp-1">{chamber.address}</span>
          </p>
        )}
        {distance != null && (
          <p className="flex items-center gap-1 text-[10px] font-semibold text-primary">
            <Navigation className="h-3 w-3" /> {distance} কিমি দূরে
          </p>
        )}
      </div>
    </Link>
  );
}
