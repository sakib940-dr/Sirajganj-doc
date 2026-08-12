import { Link } from "react-router-dom";
import { Store } from "lucide-react";
import { ROUTES } from "@/constants/routes";
import { useSiteSettings } from "@/hooks/useSiteSettings";

export default function Footer() {
  const { settings } = useSiteSettings();
  return (
    <footer className="mt-20 border-t border-border bg-primary text-primary-foreground">
      <div className="container grid gap-8 py-12 md:grid-cols-3">
        <div>
          <div className="flex items-center gap-2">
            {settings.site_logo_url ? (
              <img
                src={settings.site_logo_url}
                alt={settings.site_name}
                className="h-9 w-9 rounded-lg object-cover"
              />
            ) : (
              <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent text-accent-foreground">
                <Store className="h-5 w-5" />
              </span>
            )}
            <span className="text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
              {settings.site_name}
            </span>
          </div>
          <p className="mt-3 max-w-xs text-sm text-primary-foreground/70">
            আপনার এলাকার সব চেম্বার, সব ডাক্তার প্রোফাইল — এক জায়গায়। স্থানীয় ব্যবসাকে ডিজিটাল পরিচিতি দিতে {settings.site_name}।
          </p>
        </div>

        <div>
          <h4 className="mb-3 text-sm font-semibold text-accent">দ্রুত লিংক</h4>
          <ul className="space-y-2 text-sm text-primary-foreground/80">
            <li><Link to={ROUTES.HOME}>হোমপেজ</Link></li>
            <li><Link to={ROUTES.SEARCH}>ডাক্তার প্রোফাইল খুঁজুন</Link></li>
            <li><Link to={ROUTES.REGISTER}>ডাক্তার হিসেবে যোগ দিন</Link></li>
            <li><Link to={ROUTES.ABOUT}>আমাদের সম্পর্কে</Link></li>
            <li><Link to={ROUTES.FAQ}>সচরাচর জিজ্ঞাসিত প্রশ্ন</Link></li>
            <li><Link to={ROUTES.TERMS}>শর্তাবলী</Link></li>
            <li><Link to={ROUTES.PRIVACY}>প্রাইভেসি পলিসি</Link></li>
          </ul>
        </div>

        <div>
          <h4 className="mb-3 text-sm font-semibold text-accent">যোগাযোগ</h4>
          <p className="text-sm text-primary-foreground/80">{settings.footer_address}</p>
          {settings.contact_phone && (
            <p className="mt-1 text-sm text-primary-foreground/80">{settings.contact_phone}</p>
          )}
          {settings.contact_email && (
            <p className="mt-1 text-sm text-primary-foreground/80">{settings.contact_email}</p>
          )}
        </div>
      </div>
      <div className="border-t border-primary-foreground/10 py-4 text-center text-xs text-primary-foreground/60">
        © {new Date().getFullYear()} {settings.site_name}। সর্বস্বত্ব সংরক্ষিত।
      </div>
    </footer>
  );
}
