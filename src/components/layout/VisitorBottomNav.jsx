import { NavLink } from "react-router-dom";
import { Home, Store, LayoutGrid, Heart, User } from "lucide-react";
import { cn } from "@/lib/utils";
import { ROUTES } from "@/constants/routes";
import { useAuth } from "@/hooks/useAuth";

// Visitor-দের জন্য প্রিমিয়াম app-স্টাইল fixed bottom navigation — ৫টি
// প্রধান ট্যাব: হোম, চেম্বার (সব চেম্বারের তালিকা), ক্যাটাগরি (সব ক্যাটাগরির
// তালিকা), সংরক্ষিত, প্রোফাইল। "প্রোফাইল" ও "সংরক্ষিত" বিদ্যমান
// ProtectedRoute-এর মধ্য দিয়েই যায় — লগইন করা না থাকলে স্বয়ংক্রিয়ভাবে
// লগইন পেজে পাঠিয়ে দেয়, তাই এখানে আলাদা কোনো auth-guard লজিক লেখা হয়নি।
// লগইন করা থাকলে প্রোফাইল ট্যাবে ইউজারের নিজের অ্যাভাটার (থাকলে) দেখা যায়।
// শুধু MainLayout (Visitor-facing পাবলিক পেজ)-এ ব্যবহৃত হয়, তাই
// Seller/Admin UI অস্পৃষ্ট থাকে (তাদের নিজস্ব BottomNav/Sidebar আছে)।
export default function VisitorBottomNav() {
  const { isLoggedIn, profile } = useAuth();

  const navLinkClass = ({ isActive }) =>
    cn(
      "group relative flex flex-1 flex-col items-center justify-center gap-1 py-2 text-[11px] font-medium transition-colors",
      isActive ? "text-primary" : "text-muted-foreground hover:text-foreground"
    );

  const iconWrapClass = (active) =>
    cn(
      "flex h-9 w-9 items-center justify-center rounded-full transition-all duration-200",
      active ? "bg-primary text-primary-foreground shadow-md shadow-primary/30 scale-105" : "text-current"
    );

  const avatarInitial = (profile?.full_name?.trim()?.charAt(0) || "প").toUpperCase();

  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-40 border-t border-border/70 bg-card/95 shadow-[0_-4px_20px_-8px_rgba(0,0,0,0.15)] backdrop-blur supports-[backdrop-filter]:bg-card/85 md:hidden"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
      aria-label="Patient navigation"
    >
      <div className="kantha-divider" />
      <div className="mx-auto flex max-w-md items-stretch">
        <NavLink to={ROUTES.HOME} end className={navLinkClass}>
          {({ isActive }) => (
            <>
              <span className={iconWrapClass(isActive)}>
                <Home className="h-[19px] w-[19px]" strokeWidth={isActive ? 2.4 : 2} />
              </span>
              <span className="whitespace-nowrap">হোম</span>
            </>
          )}
        </NavLink>

        <NavLink to={ROUTES.SHOPS} className={navLinkClass}>
          {({ isActive }) => (
            <>
              <span className={iconWrapClass(isActive)}>
                <Store className="h-[19px] w-[19px]" strokeWidth={isActive ? 2.4 : 2} />
              </span>
              <span className="whitespace-nowrap">চেম্বার</span>
            </>
          )}
        </NavLink>

        <NavLink to={ROUTES.CATEGORIES} className={navLinkClass}>
          {({ isActive }) => (
            <>
              <span className={iconWrapClass(isActive)}>
                <LayoutGrid className="h-[19px] w-[19px]" strokeWidth={isActive ? 2.4 : 2} />
              </span>
              <span className="whitespace-nowrap">ক্যাটাগরি</span>
            </>
          )}
        </NavLink>

        <NavLink to={ROUTES.SAVED} className={navLinkClass}>
          {({ isActive }) => (
            <>
              <span className={iconWrapClass(isActive)}>
                <Heart className="h-[19px] w-[19px]" strokeWidth={isActive ? 2.4 : 2} />
              </span>
              <span className="whitespace-nowrap">সংরক্ষিত</span>
            </>
          )}
        </NavLink>

        <NavLink to={ROUTES.ACCOUNT} className={navLinkClass}>
          {({ isActive }) => (
            <>
              <span
                className={cn(
                  iconWrapClass(isActive),
                  isLoggedIn && profile?.avatar_url && "ring-2 ring-primary/40 ring-offset-1 ring-offset-card"
                )}
              >
                {isLoggedIn && profile?.avatar_url ? (
                  <img
                    src={profile.avatar_url}
                    alt="প্রোফাইল"
                    className="h-full w-full rounded-full object-cover"
                  />
                ) : isLoggedIn ? (
                  <span className="text-[11px] font-bold">{avatarInitial}</span>
                ) : (
                  <User className="h-[19px] w-[19px]" strokeWidth={isActive ? 2.4 : 2} />
                )}
              </span>
              <span className="whitespace-nowrap">প্রোফাইল</span>
            </>
          )}
        </NavLink>
      </div>
    </nav>
  );
}
