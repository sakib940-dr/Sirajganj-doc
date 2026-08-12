import { Link } from "react-router-dom";
import { Tag } from "lucide-react";
import { categoryPath } from "@/constants/routes";
import { cn } from "@/lib/utils";

/**
 * বড় grid-এর বদলে কম্প্যাক্ট horizontal-scroll circle/chip রো — মোবাইলে
 * অনেক কম জায়গা নেয়, এক নজরে সব ক্যাটাগরি স্ক্রল করে দেখা যায়।
 * `twoRow` দিলে আইটেমগুলো ২-সারিতে (গ্রিড-ফ্লো-কলাম) সাজানো হয় — বেশি
 * ক্যাটাগরি থাকলে উলম্ব জায়গা কম লেগে আরও কম্প্যাক্ট দেখায়।
 */
export default function CategoryChipsRow({ categories, twoRow = false }) {
  return (
    <div className="no-scrollbar -mx-4 overflow-x-auto px-4 pb-1">
      <div
        className={cn(
          "flex w-max gap-3",
          twoRow && "grid grid-flow-col grid-rows-2 gap-x-3 gap-y-3"
        )}
      >
        {categories.map((cat) => (
          <Link
            key={cat.id}
            to={categoryPath(cat.slug)}
            className="group flex w-16 shrink-0 flex-col items-center gap-1.5 text-center transition-transform active:scale-[0.95] sm:w-[4.75rem]"
          >
            <span className="flex h-14 w-14 items-center justify-center overflow-hidden rounded-full border border-border/70 bg-secondary text-primary shadow-sm transition-all group-hover:-translate-y-0.5 group-hover:border-accent group-hover:shadow-md sm:h-16 sm:w-16">
              {cat.icon_url ? (
                <img src={cat.icon_url} alt={cat.name} className="h-full w-full object-cover" />
              ) : (
                <Tag className="h-5 w-5 sm:h-6 sm:w-6" />
              )}
            </span>
            <span className="line-clamp-2 text-[11px] font-medium leading-tight text-foreground sm:text-xs">
              {cat.name}
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}
