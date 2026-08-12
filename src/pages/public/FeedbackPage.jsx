import { useState } from "react";
import { Link } from "react-router-dom";
import { ChevronLeft, Send, MessageSquareHeart } from "lucide-react";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { ROUTES } from "@/constants/routes";
import { useSiteSettings } from "@/hooks/useSiteSettings";
import { useAuth } from "@/hooks/useAuth";

// ফিডব্যাক সংরক্ষণের জন্য এখনো কোনো ডেটাবেস টেবিল নেই, তাই অপ্রয়োজনীয়
// backend পরিবর্তন এড়াতে এই পেজটি বিদ্যমান contact_whatsapp/contact_email
// (site_settings, ContactTab-এ এডিটযোগ্য) ব্যবহার করে ইউজারের লেখা মতামত
// সরাসরি WhatsApp/ইমেইলে পাঠানোর ব্যবস্থা করে।
export default function FeedbackPage() {
  const { settings } = useSiteSettings();
  const { profile } = useAuth();
  const [message, setMessage] = useState("");

  const hasChannel = Boolean(settings.contact_whatsapp || settings.contact_email);

  const buildText = () =>
    `মতামত (${profile?.full_name || "একজন রোগী"}):\n${message.trim()}`;

  const handleSendWhatsapp = () => {
    if (!message.trim() || !settings.contact_whatsapp) return;
    const digits = settings.contact_whatsapp.replace(/\D/g, "");
    window.open(`https://wa.me/${digits}?text=${encodeURIComponent(buildText())}`, "_blank", "noreferrer");
  };

  const handleSendEmail = () => {
    if (!message.trim() || !settings.contact_email) return;
    window.location.href = `mailto:${settings.contact_email}?subject=${encodeURIComponent(
      "মতামত/ফিডব্যাক"
    )}&body=${encodeURIComponent(buildText())}`;
  };

  return (
    <div className="container max-w-lg py-6 md:py-10">
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
            মতামত জানান
          </h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            আপনার পরামর্শ আমাদের আরও ভালো হতে সাহায্য করবে
          </p>
        </div>
      </div>

      <div className="rounded-xl border border-border bg-card p-5">
        <span className="mb-3 flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
          <MessageSquareHeart className="h-5 w-5" />
        </span>
        <Textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          rows={6}
          placeholder="আপনার মতামত, পরামর্শ বা কোনো সমস্যার কথা এখানে লিখুন..."
        />

        {!hasChannel ? (
          <p className="mt-3 text-xs text-muted-foreground">
            এই মুহূর্তে কোনো যোগাযোগ মাধ্যম যোগ করা নেই, তাই সরাসরি পাঠানো যাচ্ছে না।
          </p>
        ) : (
          <div className="mt-4 flex flex-wrap gap-2">
            {settings.contact_whatsapp && (
              <Button type="button" disabled={!message.trim()} onClick={handleSendWhatsapp}>
                <Send className="h-4 w-4" />
                হোয়াটসঅ্যাপে পাঠান
              </Button>
            )}
            {settings.contact_email && (
              <Button type="button" variant="outline" disabled={!message.trim()} onClick={handleSendEmail}>
                <Send className="h-4 w-4" />
                ইমেইলে পাঠান
              </Button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
