import { useState } from "react";
import { Share2, Check, Link2 } from "lucide-react";
import { shopPath } from "@/constants/routes";

/**
 * চেম্বার শেয়ার করার বাটন — Seller ও Visitor উভয়ের জন্য ব্যবহারযোগ্য।
 *
 * navigator.share() (Web Share API) সাপোর্ট করলে সেটাই ব্যবহার করে — এটাই
 * মোবাইলের নেটিভ শেয়ার শিট (WhatsApp, Facebook, Messenger, SMS ইত্যাদি সব
 * ইনস্টল করা অ্যাপ সহ) খুলে দেয়, এবং একটা প্লেইন https লিংক পাঠায় বলে সব
 * অ্যাপেই স্বাভাবিকভাবে কাজ করে।
 *
 * navigator.share() না থাকলে (বেশিরভাগ ডেস্কটপ ব্রাউজার) লিংকটা ক্লিপবোর্ডে
 * কপি করে দেয়, যাতে ইউজার নিজে যেকোনো জায়গায় পেস্ট করে শেয়ার করতে পারেন।
 */
export default function ShareShopButton({ shop, className = "", variant = "default" }) {
  const [status, setStatus] = useState("idle"); // idle | copied | unsupported

  const handleShare = async () => {
    const url = `${window.location.origin}${shopPath(shop.slug)}`;
    const shareData = {
      title: shop.shop_name,
      text: `${shop.shop_name} — দেখুন এই চেম্বারের সব ডাক্তার প্রোফাইল`,
      url,
    };

    if (navigator.share) {
      try {
        await navigator.share(shareData);
      } catch (err) {
        // ইউজার শেয়ার বাতিল করলে (AbortError) কিছু করার দরকার নেই
      }
      return;
    }

    try {
      await navigator.clipboard.writeText(url);
      setStatus("copied");
      setTimeout(() => setStatus("idle"), 2500);
    } catch {
      setStatus("unsupported");
      setTimeout(() => setStatus("idle"), 2500);
    }
  };

  const isGhost = variant === "ghost";

  return (
    <button
      type="button"
      onClick={handleShare}
      className={`inline-flex shrink-0 items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition-colors ${
        isGhost
          ? "text-muted-foreground hover:text-primary"
          : "border border-border bg-card text-muted-foreground hover:text-primary"
      } ${className}`}
      title="চেম্বারের লিংক শেয়ার করুন"
    >
      {status === "copied" ? (
        <>
          <Check className="h-4 w-4 text-primary" /> লিংক কপি হয়েছে
        </>
      ) : status === "unsupported" ? (
        <>
          <Link2 className="h-4 w-4" /> লিংক কপি করা যায়নি
        </>
      ) : (
        <>
          <Share2 className="h-4 w-4" /> শেয়ার করুন
        </>
      )}
    </button>
  );
}
