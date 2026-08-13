import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabaseClient";

const DEFAULTS = {
  // General
  site_name: "সিরাজগঞ্জ ডাক্তার",
  site_motto: "",
  site_logo_url: "/doctor-logo.svg",
  site_favicon_url: "",
  // Hero section
  hero_title: "",
  hero_subtitle: "",
  hero_image_url: "",
  hero_button_text: "",
  hero_button_link: "",
  // About
  about_us_content: "",
  // Contact
  contact_phone: "",
  contact_email: "",
  contact_whatsapp: "",
  footer_address: "সিরাজগঞ্জ, রাজশাহী বিভাগ, বাংলাদেশ",
  contact_map_link: "",
  // Legal
  privacy_policy_content: "",
  terms_conditions_content: "",
  // Footer
  footer_content: "",
  footer_copyright: "",
  // SEO
  seo_meta_title: "",
  seo_meta_description: "",
  seo_meta_keywords: "",
};

export function useSiteSettings() {
  const [settings, setSettings] = useState(DEFAULTS);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    supabase
      .from("site_settings")
      .select("*")
      .then(({ data }) => {
        if (!active) return;
        const map = { ...DEFAULTS };
        (data ?? []).forEach((row) => {
          if (row.value) map[row.key] = row.value;
        });
        setSettings(map);
        setLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  return { settings, loading };
}
