import StaticContentPage from "@/components/shared/StaticContentPage.jsx";
import { useSiteSettings } from "@/hooks/useSiteSettings";

export default function PrivacyPage() {
  const { settings, loading } = useSiteSettings();
  return (
    <StaticContentPage
      title="প্রাইভেসি পলিসি"
      content={settings.privacy_policy_content}
      loading={loading}
    />
  );
}
