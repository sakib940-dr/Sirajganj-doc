import StaticContentPage from "@/components/shared/StaticContentPage.jsx";
import { useSiteSettings } from "@/hooks/useSiteSettings";

export default function AboutPage() {
  const { settings, loading } = useSiteSettings();
  return (
    <StaticContentPage title="আমাদের সম্পর্কে" content={settings.about_us_content} loading={loading} />
  );
}
