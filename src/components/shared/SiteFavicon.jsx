import { useEffect } from "react";
import { useSiteSettings } from "@/hooks/useSiteSettings";

// index.html-এ ডিফল্ট favicon স্ট্যাটিকভাবে বসানো আছে (/favicon.svg) — Super
// Admin CMS থেকে ফেভিকন আপলোড/পরিবর্তন করলে সেটা সাইটে দেখাতে হলে <link
// rel="icon"> ট্যাগটা রানটাইমে আপডেট করা দরকার। এই কম্পোনেন্ট কোনো UI
// রেন্ডার করে না — শুধু settings লোড হওয়ার পর ব্রাউজার ট্যাব আইকন সিঙ্ক করে।
// প্রতিটা পেজ-লোড/নতুন সেশনে useSiteSettings ডাটাবেস থেকে সরাসরি ফ্রেশ
// ভ্যালু আনে (কোনো cache নেই), তাই রিফ্রেশ/নতুন সেশনের পরও পরিবর্তন টিকে থাকে।
const DEFAULT_FAVICON_HREF = "/favicon.svg";
const DEFAULT_FAVICON_TYPE = "image/svg+xml";

export default function SiteFavicon() {
  const { settings, loading } = useSiteSettings();

  useEffect(() => {
    if (loading) return;

    let link = document.querySelector("link[rel='icon']");
    if (!link) {
      link = document.createElement("link");
      link.rel = "icon";
      document.head.appendChild(link);
    }

    if (settings.site_favicon_url) {
      // কাস্টম ফেভিকন সাধারণত svg না, তাই আগের type="image/svg+xml" রেখে দিলে
      // কিছু ব্রাউজার আইকনটা ইগনোর করতে পারে — তাই type সরিয়ে দেওয়া হচ্ছে,
      // যাতে ব্রাউজার নিজে থেকে ফাইলের প্রকৃত টাইপ সনাক্ত করে নেয়
      link.removeAttribute("type");
      link.href = settings.site_favicon_url;
    } else {
      link.setAttribute("type", DEFAULT_FAVICON_TYPE);
      link.href = DEFAULT_FAVICON_HREF;
    }
  }, [settings.site_favicon_url, loading]);

  return null;
}
