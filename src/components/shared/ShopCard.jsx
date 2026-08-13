import { Link } from "react-router-dom";
import { Store, MapPin, MessageCircle, Navigation } from "lucide-react";
import { calculateDistanceKm, formatDistanceKm } from "@/lib/geo";
import { shopPath } from "@/constants/routes";
import { cn } from "@/lib/utils";

/**
 * কম্প্যাক্ট শপ কার্ড — ব্যানার আর লোগোর অনুপাত ভারসাম্যপূর্ণ রাখা হয়েছে
 * (ব্যানার ছোট, লোগো তুলনামূলক বড় ও ওভারল্যাপ করে বসানো) যাতে লোগো-ই
 * চেম্বার চেনার প্রধান ভিজ্যুয়াল অ্যাঙ্কর হয়ে থাকে। গ্রিড ও horizontal-scroll
 * রো (ShopRow) — দুই জায়গাতেই `className`-এ width দিয়ে ব্যবহারযোগ্য।
 */
export default function ShopCard({ shop, className, visitorLatitude, visitorLongitude }) {
  const distanceKm = calculateDistanceKm(visitorLatitude, visitorLongitude, shop.latitude, shop.longitude);
  const distanceLabel = formatDistanceKm(distanceKm);
  return (
    <Link
      to={shopPath(shop.slug)}
      className={cn(
        "group block overflow-hidden rounded-xl border border-border bg-card transition-all hover:-translate-y-0.5 hover:shadow-md active:scale-[0.98]",
        className
      )}
    >
      <div className="h-16 w-full bg-secondary sm:h-20">
        {shop.banner_url ? (
          <img src={shop.banner_url} alt="" className="h-full w-full object-cover" loading="lazy" />
        ) : (
          <div className="h-full w-full bg-gradient-to-br from-primary/15 to-accent/15" />
        )}
      </div>
      <div className="flex items-center gap-3 p-3 pt-0">
        <div className="-mt-6 flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-xl border-4 border-card bg-primary text-primary-foreground shadow-sm">
          {shop.logo_url ? (
            <img src={shop.logo_url} alt={shop.shop_name} className="h-full w-full object-cover" loading="lazy" />
          ) : (
            <Store className="h-5 w-5" />
          )}
        </div>
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-sm font-semibold text-foreground group-hover:text-primary">
            {shop.shop_name}
          </h3>
          {shop.address ? (
            <p className="mt-0.5 flex items-center gap-1 truncate text-xs text-muted-foreground">
              <MapPin className="h-3 w-3 shrink-0" />
              {shop.address}
            </p>
          ) : shop.whatsapp_number ? (
            <p className="mt-0.5 flex items-center gap-1 truncate text-xs text-muted-foreground">
              <MessageCircle className="h-3 w-3 shrink-0" />
              সরাসরি যোগাযোগ করা যাবে
            </p>
          ) : null}
          {distanceLabel && (
            <p className="mt-1 inline-flex items-center gap-1 text-[11px] font-semibold text-primary">
              <Navigation className="h-3 w-3" />
              {distanceLabel}
            </p>
          )}
        </div>
      </div>
    </Link>
  );
}
