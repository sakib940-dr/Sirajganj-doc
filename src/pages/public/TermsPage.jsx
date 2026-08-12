import StaticContentPage from "@/components/shared/StaticContentPage.jsx";
import { useSiteSettings } from "@/hooks/useSiteSettings";

export default function TermsPage() {
  const { settings, loading } = useSiteSettings();
  return (
    <StaticContentPage
      title="শর্তাবলী (Terms & Conditions)"
      content={settings.terms_conditions_content}
      loading={loading}
    />
  );
}
