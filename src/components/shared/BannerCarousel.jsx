import { useRef, useState } from "react";
import { cn } from "@/lib/utils";

/**
 * CMS থেকে আসা ব্যানার (useBanners) elegant snap-scroll carousel-এ দেখায়।
 * এক-এক করে পুরো width জুড়ে স্লাইড হয়, নিচে সক্রিয় স্লাইড বোঝাতে ছোট dot
 * indicator থাকে (স্ক্রল পজিশন ট্র্যাক করে) — কোনো নতুন লাইব্রেরি ছাড়াই।
 */
export default function BannerCarousel({ banners }) {
  const scrollRef = useRef(null);
  const [activeIndex, setActiveIndex] = useState(0);

  if (!banners || banners.length === 0) return null;

  const handleScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    const slideWidth = el.clientWidth;
    if (slideWidth === 0) return;
    const index = Math.round(el.scrollLeft / slideWidth);
    setActiveIndex(Math.min(Math.max(index, 0), banners.length - 1));
  };

  const scrollToIndex = (index) => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTo({ left: index * el.clientWidth, behavior: "smooth" });
  };

  return (
    <section className="container relative z-10 -mt-8">
      <div
        ref={scrollRef}
        onScroll={handleScroll}
        className="no-scrollbar flex snap-x snap-mandatory overflow-x-auto rounded-2xl shadow-lg"
      >
        {banners.map((banner) =>
          banner.link_url ? (
            <a
              key={banner.id}
              href={banner.link_url}
              target="_blank"
              rel="noreferrer"
              className="aspect-[16/7] w-full shrink-0 snap-center overflow-hidden sm:aspect-[21/8]"
            >
              <img
                src={banner.image_url}
                alt={banner.title || ""}
                className="h-full w-full object-cover"
              />
            </a>
          ) : (
            <div
              key={banner.id}
              className="aspect-[16/7] w-full shrink-0 snap-center overflow-hidden sm:aspect-[21/8]"
            >
              <img
                src={banner.image_url}
                alt={banner.title || ""}
                className="h-full w-full object-cover"
              />
            </div>
          )
        )}
      </div>

      {banners.length > 1 && (
        <div className="mt-3 flex items-center justify-center gap-1.5">
          {banners.map((banner, index) => (
            <button
              key={banner.id}
              type="button"
              onClick={() => scrollToIndex(index)}
              aria-label={`ব্যানার ${index + 1}`}
              className={cn(
                "h-1.5 rounded-full transition-all",
                index === activeIndex ? "w-5 bg-primary" : "w-1.5 bg-border"
              )}
            />
          ))}
        </div>
      )}
    </section>
  );
}
