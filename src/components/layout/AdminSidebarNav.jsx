import { NavLink } from "react-router-dom";
import { cn } from "@/lib/utils";

/**
 * @param {{ groups: { title?: string, items: { to: string, label: string, icon: React.ComponentType, end?: boolean }[] }[], onNavigate?: () => void }} props
 */
export default function AdminSidebarNav({ groups, onNavigate }) {
  return (
    <nav className="flex flex-col gap-5">
      {groups.map((group, gi) => (
        <div key={group.title || gi} className="flex flex-col gap-1">
          {group.title && (
            <p className="px-3 pb-1 text-[11px] font-semibold uppercase tracking-wider text-primary-foreground/45">
              {group.title}
            </p>
          )}
          {group.items.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              onClick={onNavigate}
              className={({ isActive }) =>
                cn(
                  "group flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                  isActive
                    ? "bg-accent text-accent-foreground shadow-sm"
                    : "text-primary-foreground/75 hover:bg-primary-foreground/10 hover:text-primary-foreground"
                )
              }
            >
              <Icon className="h-4 w-4 shrink-0" />
              <span className="truncate">{label}</span>
            </NavLink>
          ))}
        </div>
      ))}
    </nav>
  );
}
