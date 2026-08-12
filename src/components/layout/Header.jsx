import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  Search,
  Menu,
  X,
  Store,
  LayoutDashboard,
  ShieldCheck,
  User,
  Sparkles,
  Heart,
  KeyRound,
  LogOut,
  ChevronDown,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu.jsx";
import { useAuth } from "@/hooks/useAuth";
import { useSiteSettings } from "@/hooks/useSiteSettings";
import { useMobileMenu } from "@/context/MobileMenuContext.jsx";
import { ROUTES } from "@/constants/routes";
import { ROLES, isAdminOrAbove } from "@/constants/roles";
import { cn } from "@/lib/utils";

export default function Header() {
  const [query, setQuery] = useState("");
  // মোবাইল মেনুর open/close state MobileMenuContext থেকে আসছে, যাতে
  // Header-এর হ্যামবার্গার (top-left) এবং ভবিষ্যতে অন্য কোথাও থেকেও একই
  // MobileSideMenu drawer খোলা/বন্ধ করা যায় — ডুপ্লিকেট মেনু-লজিক নেই।
  const { isOpen: mobileOpen, toggle: toggleMobileMenu } = useMobileMenu();
  const { isLoggedIn, role, profile, signOut } = useAuth();
  const { settings } = useSiteSettings();
  const navigate = useNavigate();

  const handleSearch = (e) => {
    e.preventDefault();
    if (query.trim()) {
      navigate(`${ROUTES.SEARCH}?q=${encodeURIComponent(query.trim())}`);
    }
  };

  const displayName = profile?.full_name?.trim() || "আমার অ্যাকাউন্ট";
  const avatarInitial = (profile?.full_name?.trim()?.charAt(0) || "ব").toUpperCase();

  return (
    <header className="sticky top-0 z-40 border-b border-border bg-background/95 shadow-sm backdrop-blur supports-[backdrop-filter]:bg-background/80">
      <div className="kantha-divider" />
      <div className="container flex h-14 items-center gap-2.5 md:h-16 md:gap-5">
        {/* মোবাইল হ্যামবার্গার — বাম পাশে, সবার প্রথমে */}
        <button
          type="button"
          className={cn(
            "flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-foreground transition-colors hover:bg-secondary md:hidden",
            mobileOpen && "bg-secondary"
          )}
          onClick={() => toggleMobileMenu()}
          aria-label={mobileOpen ? "মেনু বন্ধ করুন" : "মেনু খুলুন"}
          aria-expanded={mobileOpen}
        >
          {mobileOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>

        {/* লোগো/ব্র্যান্ড */}
        <Link to={ROUTES.HOME} className="flex shrink-0 items-center gap-2">
          {settings.site_logo_url ? (
            <img
              src={settings.site_logo_url}
              alt={settings.site_name}
              className="h-8 w-8 rounded-lg object-cover md:h-9 md:w-9"
            />
          ) : (
            <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-primary-foreground md:h-9 md:w-9">
              <Store className="h-4.5 w-4.5 md:h-5 md:w-5" />
            </span>
          )}
          <span
            className="text-base font-bold leading-none tracking-tight text-primary md:text-xl"
            style={{ fontFamily: "'Tiro Bangla', serif" }}
          >
            {settings.site_name}
          </span>
        </Link>

        {/* সার্চ — ডেস্কটপে হেডারে ইনলাইন, কম্প্যাক্ট প্রিমিয়াম লুক */}
        <form onSubmit={handleSearch} className="relative hidden flex-1 max-w-md md:block">
          <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="চেম্বার বা ডাক্তার প্রোফাইল খুঁজুন..."
            className="h-10 rounded-full border-border/80 bg-secondary/40 pl-10 shadow-none transition-colors focus-visible:bg-background"
          />
        </form>

        {/* ডেস্কটপ — কম্প্যাক্ট অ্যাকাউন্ট এলাকা */}
        <div className="ml-auto hidden items-center gap-2 md:flex">
          {isLoggedIn ? (
            <>
              <Button variant="ghost" size="icon" asChild className="rounded-full" title="সংরক্ষিত">
                <Link to={ROUTES.SAVED} aria-label="সংরক্ষিত">
                  <Heart className="h-[18px] w-[18px]" />
                </Link>
              </Button>

              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <button
                    type="button"
                    className="flex items-center gap-2 rounded-full border border-border/80 py-1 pl-1 pr-3 text-sm font-medium text-foreground shadow-sm transition-colors hover:bg-secondary/70"
                  >
                    <span className="flex h-7 w-7 items-center justify-center overflow-hidden rounded-full bg-primary text-xs font-bold text-primary-foreground">
                      {profile?.avatar_url ? (
                        <img src={profile.avatar_url} alt="" className="h-full w-full object-cover" />
                      ) : (
                        avatarInitial
                      )}
                    </span>
                    <span className="max-w-[9rem] truncate">{displayName}</span>
                    <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />
                  </button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-56">
                  <DropdownMenuLabel className="truncate">{displayName}</DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  {isAdminOrAbove(role) && (
                    <DropdownMenuItem asChild>
                      <Link to={ROUTES.ADMIN}>
                        <ShieldCheck className="h-4 w-4 text-muted-foreground" />
                        অ্যাডমিন প্যানেল
                      </Link>
                    </DropdownMenuItem>
                  )}
                  <DropdownMenuItem asChild>
                    <Link to={ROUTES.DASHBOARD}>
                      <LayoutDashboard className="h-4 w-4 text-muted-foreground" />
                      {role === ROLES.DOCTOR ? "ডাক্তার ড্যাশবোর্ড" : "ড্যাশবোর্ড"}
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuItem asChild>
                    <Link to={ROUTES.ACCOUNT}>
                      <KeyRound className="h-4 w-4 text-muted-foreground" />
                      প্রোফাইল / পাসওয়ার্ড
                    </Link>
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem onSelect={signOut} className="text-destructive focus:text-destructive">
                    <LogOut className="h-4 w-4" />
                    লগ আউট
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </>
          ) : (
            <>
              <Button
                variant="outline"
                size="sm"
                asChild
                className="border-primary/25 text-primary shadow-sm hover:border-primary/50 hover:bg-primary/5 hover:text-primary"
              >
                <Link to={ROUTES.LOGIN}>
                  <User className="h-4 w-4" />
                  অ্যাকাউন্টে প্রবেশ
                </Link>
              </Button>
              <Button
                size="sm"
                asChild
                className="relative overflow-hidden bg-gradient-to-r from-accent to-accent/80 text-accent-foreground shadow-md shadow-accent/30 transition-transform hover:scale-[1.03] hover:shadow-lg hover:shadow-accent/40"
              >
                <Link to={ROUTES.REGISTER}>
                  <Sparkles className="h-4 w-4" />
                  ডাক্তার হোন
                </Link>
              </Button>
            </>
          )}
        </div>

        {/* মোবাইলে আলাদা কোনো হেডার সার্চ আইকন নেই — হোমপেজের হিরো সেকশনে
            ইতিমধ্যে একটি কাজ করা সার্চ বক্স আছে (টাইপ করার সুযোগসহ), তাই এখানে
            আলাদা আইকন রাখলে তা শুধু ফাঁকা রেজাল্ট পেজে নিয়ে যেত এবং টাইপ করার
            কোনো সুযোগ থাকতো না — বিভ্রান্তিকর হওয়ায় সরিয়ে দেওয়া হলো। */}
      </div>
    </header>
  );
}
