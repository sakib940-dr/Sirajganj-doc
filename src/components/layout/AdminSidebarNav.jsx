import { NavLink } from "react-router-dom";
import { cn } from "@/lib/utils";

export default function AdminSidebarNav({ groups, onNavigate }) {
  return (
    <nav className="flex flex-col gap-5">
      {groups.map((group, gi) => (
        <div key={group.title || gi} className="flex flex-col gap-1">
          {group.title && <p className="px-3 pb-1 text-[10px] font-bold uppercase tracking-wider text-muted-foreground">{group.title}</p>}
          {group.items.map(({ to, label, icon: Icon, end }) => (
            <NavLink key={to} to={to} end={end} onClick={onNavigate} className={({ isActive }) => cn(
              "group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-all",
              isActive ? "bg-primary text-primary-foreground shadow-sm" : "text-foreground/70 hover:bg-secondary hover:text-foreground"
            )}>
              <Icon className="h-4 w-4 shrink-0" /><span className="truncate">{label}</span>
            </NavLink>
          ))}
        </div>
      ))}
    </nav>
  );
}
