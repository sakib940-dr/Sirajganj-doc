import { Link } from "react-router-dom";
import { ChevronLeft, MessageCircle, Phone, Mail, HelpCircle } from "lucide-react";
import { ROUTES } from "@/constants/routes";
import { useSiteSettings } from "@/hooks/useSiteSettings";

// এই পেজটি নতুন কোনো ব্যাকএন্ড/টেবিল ছাড়াই বিদ্যমান site_settings-এর
// contact_phone / contact_whatsapp / contact_email ব্যবহার করে তৈরি —
// এই ফিল্ডগুলো আগে থেকেই CMS-এ (ContactTab) এডিট করা যেত, শুধু পাবলিক
// সাইটে এখন প্রথমবার দেখানো হচ্ছে।
export default function HelpPage() {
  const { settings } = useSiteSettings();

  const whatsappUrl = settings.contact_whatsapp
    ? `https://wa.me/${settings.contact_whatsapp.replace(/\D/g, "")}?text=${encodeURIComponent(
        "আসসালামু আলাইকুম, আমার একটা সাহায্য দরকার —"
      )}`
    : null;

  const channels = [
    whatsappUrl && {
      icon: MessageCircle,
      label: "হোয়াটসঅ্যাপে চ্যাট করুন",
      value: settings.contact_whatsapp,
      href: whatsappUrl,
    },
    settings.contact_phone && {
      icon: Phone,
      label: "কল করুন",
      value: settings.contact_phone,
      href: `tel:${settings.contact_phone.replace(/\s/g, "")}`,
    },
    settings.contact_email && {
      icon: Mail,
      label: "ইমেইল করুন",
      value: settings.contact_email,
      href: `mailto:${settings.contact_email}`,
    },
  ].filter(Boolean);

  return (
    <div className="container max-w-2xl py-6 md:py-10">
      <div className="mb-6 flex items-center gap-2">
        <Link
          to={ROUTES.HOME}
          className="flex h-8 w-8 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-secondary"
          aria-label="ফিরে যান"
        >
          <ChevronLeft className="h-5 w-5" />
        </Link>
        <div>
          <h1 className="text-xl font-bold md:text-2xl" style={{ fontFamily: "'Tiro Bangla', serif" }}>
            সাহায্য ও সাপোর্ট
          </h1>
          <p className="mt-0.5 text-sm text-muted-foreground">যেকোনো সমস্যায় আমাদের সাথে যোগাযোগ করুন</p>
        </div>
      </div>

      {channels.length === 0 ? (
        <p className="rounded-xl border border-dashed border-border bg-secondary/40 p-5 text-center text-sm text-muted-foreground">
          এই মুহূর্তে কোনো যোগাযোগের তথ্য যোগ করা হয়নি।
        </p>
      ) : (
        <div className="space-y-3">
          {channels.map((ch) => (
            <a
              key={ch.label}
              href={ch.href}
              target={ch.href.startsWith("http") ? "_blank" : undefined}
              rel="noreferrer"
              className="flex items-center gap-3.5 rounded-xl border border-border bg-card p-4 transition-colors hover:bg-secondary/50"
            >
              <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                <ch.icon className="h-5 w-5" />
              </span>
              <span>
                <span className="block text-sm font-semibold text-foreground">{ch.label}</span>
                <span className="block text-xs text-muted-foreground">{ch.value}</span>
              </span>
            </a>
          ))}
        </div>
      )}

      <Link
        to={ROUTES.FAQ}
        className="mt-4 flex items-center gap-3.5 rounded-xl border border-border bg-card p-4 transition-colors hover:bg-secondary/50"
      >
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-accent/15 text-accent">
          <HelpCircle className="h-5 w-5" />
        </span>
        <span>
          <span className="block text-sm font-semibold text-foreground">সচরাচর জিজ্ঞাসিত প্রশ্ন (FAQ)</span>
          <span className="block text-xs text-muted-foreground">দ্রুত উত্তরের জন্য FAQ দেখুন</span>
        </span>
      </Link>
    </div>
  );
}
