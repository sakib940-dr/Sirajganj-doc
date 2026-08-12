import {
  Palette,
  Sparkles,
  GalleryHorizontal,
  Info,
  Phone,
  Share2,
  ScrollText,
  PanelBottom,
  Search,
  Megaphone,
} from "lucide-react";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs.jsx";
import LoadingSpinner from "@/components/shared/LoadingSpinner.jsx";
import { useSiteSettingsAdmin } from "@/hooks/admin/useSiteSettingsAdmin.js";

import GeneralTab from "@/components/admin/cms/GeneralTab.jsx";
import HeroTab from "@/components/admin/cms/HeroTab.jsx";
import AboutTab from "@/components/admin/cms/AboutTab.jsx";
import ContactTab from "@/components/admin/cms/ContactTab.jsx";
import LegalTab from "@/components/admin/cms/LegalTab.jsx";
import FooterTab from "@/components/admin/cms/FooterTab.jsx";
import SEOTab from "@/components/admin/cms/SEOTab.jsx";
import SocialLinksTab from "@/components/admin/cms/SocialLinksTab.jsx";
import AnnouncementsTab from "@/components/admin/cms/AnnouncementsTab.jsx";
import BannerManagePage from "@/pages/admin/BannerManagePage.jsx";

const TABS = [
  { value: "general", label: "সাধারণ", icon: Palette },
  { value: "hero", label: "হিরো সেকশন", icon: Sparkles },
  { value: "banners", label: "ব্যানার/স্লাইডার", icon: GalleryHorizontal },
  { value: "about", label: "About Us", icon: Info },
  { value: "contact", label: "যোগাযোগ", icon: Phone },
  { value: "social", label: "সোশ্যাল লিংক", icon: Share2 },
  { value: "legal", label: "প্রাইভেসি ও শর্তাবলী", icon: ScrollText },
  { value: "footer", label: "ফুটার", icon: PanelBottom },
  { value: "seo", label: "SEO", icon: Search },
  { value: "announcement", label: "নোটিশ বার", icon: Megaphone },
];

export default function CMSPage() {
  const { values, loading, error, saveFields, clearFields } = useSiteSettingsAdmin();

  if (loading) return <LoadingSpinner label="লোড হচ্ছে..." />;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="flex items-center gap-2 text-xl font-bold" style={{ fontFamily: "'Tiro Bangla', serif" }}>
          <Palette className="h-5 w-5 text-primary" /> ওয়েবসাইট CMS প্যানেল
        </h1>
        <p className="text-sm text-muted-foreground">
          লোগো, হোমপেজ কনটেন্ট, About Us, যোগাযোগ তথ্য, সোশ্যাল লিংক, নীতিমালা, ফুটার ও SEO — সবকিছু এক জায়গা থেকে নিয়ন্ত্রণ করুন।
        </p>
      </div>

      {error && (
        <p className="rounded-lg border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">{error}</p>
      )}

      <Tabs defaultValue="general">
        <div className="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
          <TabsList>
            {TABS.map((t) => (
              <TabsTrigger key={t.value} value={t.value}>
                <t.icon className="h-4 w-4" />
                {t.label}
              </TabsTrigger>
            ))}
          </TabsList>
        </div>

        <TabsContent value="general">
          <GeneralTab values={values} saveFields={saveFields} clearFields={clearFields} />
        </TabsContent>
        <TabsContent value="hero">
          <HeroTab values={values} saveFields={saveFields} clearFields={clearFields} />
        </TabsContent>
        <TabsContent value="banners">
          <BannerManagePage />
        </TabsContent>
        <TabsContent value="about">
          <AboutTab values={values} saveFields={saveFields} clearFields={clearFields} />
        </TabsContent>
        <TabsContent value="contact">
          <ContactTab values={values} saveFields={saveFields} clearFields={clearFields} />
        </TabsContent>
        <TabsContent value="social">
          <SocialLinksTab />
        </TabsContent>
        <TabsContent value="legal">
          <LegalTab values={values} saveFields={saveFields} clearFields={clearFields} />
        </TabsContent>
        <TabsContent value="footer">
          <FooterTab values={values} saveFields={saveFields} clearFields={clearFields} />
        </TabsContent>
        <TabsContent value="seo">
          <SEOTab values={values} saveFields={saveFields} clearFields={clearFields} />
        </TabsContent>
        <TabsContent value="announcement">
          <AnnouncementsTab />
        </TabsContent>
      </Tabs>
    </div>
  );
}
