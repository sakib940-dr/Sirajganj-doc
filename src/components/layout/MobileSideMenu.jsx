import { Link } from "react-router-dom";
import {
  X,
  User,
  LogIn,
  LogOut,
  LayoutDashboard,
  ShieldCheck,
  HelpCircle,
  Info,
  MessageSquareHeart,
  ScrollText,
  ShieldQuestion,
  Sparkles,
  ChevronRight,
  Store,
  Globe2,
  Settings,
  Droplets,
  Ambulance,
} from "lucide-react";
import { useAuth } from "@/hooks/useAuth";
import { useMobileMenu } from "@/context/MobileMenuContext.jsx";
import { ROUTES } from "@/constants/routes";
import { ROLES, isAdminOrAbove } from "@/constants/roles";
import { cn } from "@/lib/utils";

// অ্যাপ ভার্সন — package.json-এর version-এর সাথে সিঙ্কে রাখতে এখানে
// ম্যানুয়ালি আপডেট করুন। এটা শুধুই একটা display label, কোনো লজিকের সাথে
// যুক্ত না বলে বিল্ড টুল থেকে আলাদা করে ইনজেক্ট করার দরকার হয়নি।
const APP_VERSION = "v0.1.0";

function MenuLink({ to, icon: Icon, label, onClick }) {
  return (
    <Link
      to={to}
      onClick={onClick}
      className="flex items-center justify-between rounded-lg px-3 py-2.5 text-sm font-medium text-foreground/90 transition-colors hover:bg-secondary"
    >
      <span className="flex items-center gap-2.5">
        <Icon className="h-4 w-4 text-muted-foreground" />
        {label}
      </span>
      <ChevronRight className="h-3.5 w-3.5 text-muted-foreground/60" />
    </Link>
  );
}

// Header-এর হ্যামবার্গার (top-left) ও Bottom Navigation — উভয় থেকেই এই
// একই left-slide drawer খোলে (শেয়ার্ড MobileMenuContext ব্যবহার করে,
// কোনো ডুপ্লিকেট state/লজিক তৈরি হয়নি)। সংগঠন: উপরে Login/প্রোফাইল কার্ড →
// মাঝে Help/About/Feedback/FAQ/Terms/Privacy → নিচে Logout → সবার নিচে
// অ্যাপ ভার্সন।
export default function MobileSideMenu() {
  const { isOpen, close } = useMobileMenu();
  const { isLoggedIn, role, profile, signOut } = useAuth();

  const displayName = profile?.full_name?.trim() || "আমার অ্যাকাউন্ট";
  const avatarInitial = (profile?.full_name?.trim()?.charAt(0) || "ব").toUpperCase();
  const isStaff = isAdminOrAbove(role) || role === ROLES.DOCTOR || role === ROLES.HOSPITAL;
  const personalRoute = role === ROLES.PATIENT ? ROUTES.ACCOUNT : isAdminOrAbove(role) ? ROUTES.ADMIN_PERSONAL : ROUTES.DASHBOARD_PERSONAL;

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 md:hidden">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/40 backdrop-blur-[1px]" onClick={close} />

      {/* বাম দিক থেকে স্লাইড হয়ে আসা প্যানেল */}
      <aside className="absolute inset-y-0 left-0 flex w-[82%] max-w-xs flex-col bg-card shadow-2xl animate-in slide-in-from-left duration-200">
        <div className="kantha-divider" />

        <div className="flex items-center justify-between px-4 py-3">
          <span className="text-sm font-semibold text-muted-foreground">মেনু</span>
          <button
            type="button"
            onClick={close}
            className="flex h-8 w-8 items-center justify-center rounded-full text-foreground transition-colors hover:bg-secondary"
            aria-label="মেনু বন্ধ করুন"
          >
            <X className="h-4.5 w-4.5" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-3 pb-4">
          {/* উপরে — লগইন / প্রোফাইল কার্ড */}
          {isLoggedIn ? (
            <Link
              to={personalRoute}
              onClick={close}
              className="mb-3 flex items-center gap-3 rounded-xl bg-secondary/60 px-3 py-3"
            >
              <span className="flex h-11 w-11 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary text-sm font-bold text-primary-foreground">
                {profile?.avatar_url ? (
                  <img src={profile.avatar_url} alt="" className="h-full w-full object-cover" />
                ) : (
                  avatarInitial
                )}
              </span>
              <span className="min-w-0">
                <span className="block truncate text-sm font-semibold text-foreground">
                  {displayName}
                </span>
                <span className="block text-xs text-muted-foreground">প্রোফাইল দেখুন</span>
              </span>
            </Link>
          ) : (
            <Link
              to={ROUTES.LOGIN}
              onClick={close}
              className="mb-3 flex items-center justify-center gap-2 rounded-xl bg-primary px-4 py-3 text-sm font-semibold text-primary-foreground shadow-sm transition-transform active:scale-[0.98]"
            >
              <LogIn className="h-4 w-4" />
              লগইন করুন
            </Link>
          )}

          {!isLoggedIn && (
            <Link
              to={ROUTES.REGISTER}
              onClick={close}
              className="mb-4 flex items-center justify-center gap-2 rounded-xl border border-accent/40 bg-accent/10 px-4 py-2.5 text-sm font-semibold text-accent-foreground transition-colors hover:bg-accent/15"
            >
              <Sparkles className="h-4 w-4 text-accent" />
              ডাক্তার হিসেবে যোগ দিন
            </Link>
          )}

          {isStaff ? (
            <>
              <div className="space-y-0.5">
                <MenuLink to={personalRoute} icon={User} label="ব্যক্তিগত তথ্য" onClick={close} />
                {(role === ROLES.DOCTOR || role === ROLES.HOSPITAL) && (
                  <>
                    <MenuLink to={ROUTES.DASHBOARD_SHOP} icon={Store} label="চেম্বার" onClick={close} />
                    <MenuLink to={ROUTES.DASHBOARD_WEBSITE} icon={Globe2} label="ওয়েবসাইট" onClick={close} />
                  </>
                )}
                {isAdminOrAbove(role) && (
                  <MenuLink to={ROUTES.ADMIN} icon={ShieldCheck} label="অ্যাডমিন প্যানেল" onClick={close} />
                )}
                <MenuLink to={isAdminOrAbove(role) ? ROUTES.ADMIN_SETTINGS : ROUTES.DASHBOARD_SETTINGS} icon={Settings} label="সেটিংস" onClick={close} />
              </div>
            </>
          ) : (
            <div className="space-y-0.5">
              {isLoggedIn && role === ROLES.PATIENT && <>
                <MenuLink to={ROUTES.BLOOD_BANK} icon={Droplets} label="রক্ত ব্যাংক" onClick={close} />
                <MenuLink to={ROUTES.BLOOD_DONOR} icon={Droplets} label="স্বেচ্ছাসেবী রক্তদাতা" onClick={close} />
                <MenuLink to={ROUTES.AMBULANCE} icon={Ambulance} label="অ্যাম্বুলেন্স" onClick={close} />
                <div className="my-2 border-t border-border" />
              </>}
              {!isLoggedIn && <>
                <MenuLink to={ROUTES.BLOOD_BANK} icon={Droplets} label="রক্ত ব্যাংক" onClick={close} />
                <MenuLink to={ROUTES.AMBULANCE} icon={Ambulance} label="অ্যাম্বুলেন্স" onClick={close} />
                <div className="my-2 border-t border-border" />
              </>}
              <MenuLink to={ROUTES.HELP} icon={HelpCircle} label="সাহায্য" onClick={close} />
              <MenuLink to={ROUTES.ABOUT} icon={Info} label="আমাদের সম্পর্কে" onClick={close} />
              <MenuLink to={ROUTES.FEEDBACK} icon={MessageSquareHeart} label="মতামত জানান" onClick={close} />
              <MenuLink to={ROUTES.FAQ} icon={ShieldQuestion} label="সচরাচর জিজ্ঞাসিত প্রশ্ন" onClick={close} />
              <MenuLink to={ROUTES.TERMS} icon={ScrollText} label="শর্তাবলী" onClick={close} />
              <MenuLink to={ROUTES.PRIVACY} icon={ScrollText} label="প্রাইভেসি পলিসি" onClick={close} />
            </div>
          )}

          {/* নিচে — লগ আউট */}
          {isLoggedIn && (
            <>
              <div className="my-3 border-t border-border" />
              <button
                type="button"
                onClick={() => {
                  close();
                  signOut();
                }}
                className={cn(
                  "flex w-full items-center gap-2.5 rounded-lg px-3 py-2.5 text-sm font-semibold text-destructive transition-colors hover:bg-destructive/5"
                )}
              >
                <LogOut className="h-4 w-4" />
                লগ আউট
              </button>
            </>
          )}
        </div>

        {/* সবার নিচে — অ্যাপ ভার্সন */}
        <div className="border-t border-border px-4 py-3 text-center text-[11px] text-muted-foreground/70">
          {APP_VERSION}
        </div>
      </aside>
    </div>
  );
}
