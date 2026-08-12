import { Outlet } from "react-router-dom";
import Header from "@/components/layout/Header.jsx";
import Footer from "@/components/layout/Footer.jsx";
import VisitorBottomNav from "@/components/layout/VisitorBottomNav.jsx";
import MobileSideMenu from "@/components/layout/MobileSideMenu.jsx";
import { MobileMenuProvider } from "@/context/MobileMenuContext.jsx";

export default function MainLayout() {
  return (
    <MobileMenuProvider>
      <div className="flex min-h-screen flex-col">
        <Header />
        {/* মোবাইলে নিচের Bottom Navigation যাতে পেজের কনটেন্ট/ফুটার ঢেকে না ফেলে,
            তাই এখানে bottom padding — ডেস্কটপে (md+) bottom nav লুকানো থাকে বলে
            padding-ও লাগে না */}
        <main className="flex-1 pb-20 md:pb-0">
          <Outlet />
        </main>
        <Footer />
        <VisitorBottomNav />
        {/* Header-এর বাইরে, sibling হিসেবে রেন্ডার করা — Header-এ backdrop-blur
            (backdrop-filter) থাকায় সেটা fixed-position ডিসেন্ডেন্টদের জন্য নতুন
            containing block তৈরি করে ফেলত, ফলে এই drawer viewport-এর বদলে
            Header-এর ছোট্ট বক্সের ভেতর আটকে (clip হয়ে) থাকত এবং ক্লিক করলেও
            দৃশ্যমানভাবে খুলত না। এখানে সরিয়ে আনায় সেই সমস্যা আর নেই। */}
        <MobileSideMenu />
      </div>
    </MobileMenuProvider>
  );
}
