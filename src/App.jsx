import AppRoutes from "@/routes/AppRoutes.jsx";
import InstallPromptBanner from "@/components/shared/InstallPromptBanner.jsx";
import SiteFavicon from "@/components/shared/SiteFavicon.jsx";

export default function App() {
  return (
    <>
      <SiteFavicon />
      <AppRoutes />
      <InstallPromptBanner />
    </>
  );
}
