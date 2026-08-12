import { NavLink } from "react-router-dom";
import { cn } from "@/lib/utils";

/**
 * @param {{ to: string, label: string, icon: React.ComponentType }[]} items
 */
export default function Sidebar({ items, title }) {
  return (
    <aside className="w-full shrink-0 border-border md:w-64 md:border-r">
      <div className="hidden px-5 py-5 md:block">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</p>
      </div>
      <nav className="flex gap-1 overflow-x-auto px-3 py-2 md:flex-col md:overflow-visible md:py-0">
        {items.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              cn(
                "flex shrink-0 items-center gap-2.5 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                isActive
                  ? "bg-primary text-primary-foreground"
                  : "text-foreground/80 hover:bg-secondary"
              )
            }
          >
            <Icon className="h-4 w-4" />
            <span className="whitespace-nowrap">{label}</span>
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}
