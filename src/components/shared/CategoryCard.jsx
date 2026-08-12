import { Link } from "react-router-dom";
import { Tag } from "lucide-react";
import { categoryPath } from "@/constants/routes";

export default function CategoryCard({ category }) {
  return (
    <Link
      to={categoryPath(category.slug)}
      className="group flex flex-col items-center gap-3 rounded-xl border border-border bg-card p-4 text-center transition-all hover:-translate-y-0.5 hover:border-primary/30 hover:shadow-md active:scale-[0.97]"
    >
      <div className="flex h-14 w-14 items-center justify-center overflow-hidden rounded-full bg-secondary text-primary transition-colors group-hover:bg-accent group-hover:text-accent-foreground">
        {category.icon_url ? (
          <img src={category.icon_url} alt={category.name} className="h-full w-full object-cover" />
        ) : (
          <Tag className="h-6 w-6" />
        )}
      </div>
      <span className="text-sm font-medium text-foreground">{category.name}</span>
    </Link>
  );
}
