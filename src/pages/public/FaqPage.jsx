import { useState } from "react";
import { Link } from "react-router-dom";
import { ChevronLeft, ChevronDown, HelpCircle } from "lucide-react";
import { ROUTES } from "@/constants/routes";
import { cn } from "@/lib/utils";

// সাধারণ প্রশ্নোত্তর — এগুলো স্ট্যাটিক টেক্সট (কোনো ডেটাবেস/CMS নির্ভরতা
// নেই), তাই backend-এ নতুন কিছু যোগ করার দরকার হয়নি। ভবিষ্যতে চাইলে এটি
// CMS-চালিত করা যাবে।
const FAQ_ITEMS = [
  {
    q: "কীভাবে কোনো ডাক্তার প্রোফাইল অর্ডার করব?",
    a: "ডাক্তার প্রোফাইলের পেজে গিয়ে 'অর্ডার করুন' বাটনে চাপ দিলে সরাসরি চেম্বারের WhatsApp/Messenger/ফোন নম্বরে যোগাযোগ করতে পারবেন। এখান থেকে সরাসরি পেমেন্ট করার দরকার নেই — চেম্বারদারের সাথে কথা বলেই অর্ডার নিশ্চিত করুন।",
  },
  {
    q: "ডাক্তার প্রোফাইলের দাম বা মান নিয়ে সমস্যা হলে কী করব?",
    a: "ডাক্তার প্রোফাইলের consultation fee, visiting schedule বা appointment সংক্রান্ত যেকোনো বিষয়ে সংশ্লিষ্ট ডাক্তার/চেম্বারের সাথে সরাসরি যোগাযোগ করুন। সমস্যা সমাধান না হলে আমাদের 'সাহায্য' পাতা থেকে অ্যাডমিনের সাথে যোগাযোগ করতে পারেন।",
  },
  {
    q: "আমি কীভাবে ডাক্তার (চেম্বারদার) হিসেবে যুক্ত হতে পারি?",
    a: "রেজিস্ট্রেশন পেজ থেকে সাধারণ অ্যাকাউন্ট খুলুন, তারপর ড্যাশবোর্ড থেকে 'ডাক্তার হতে চাই' আবেদন করুন। অ্যাডমিন অনুমোদন করলেই আপনার চেম্বার মার্কেটপ্লেসে দেখা যাবে।",
  },
  {
    q: "সংরক্ষিত (Saved) ডাক্তার প্রোফাইল কোথায় পাব?",
    a: "নিচের নেভিগেশন বার থেকে 'সংরক্ষিত' ট্যাবে গেলে আপনার পছন্দ করে রাখা সব ডাক্তার প্রোফাইল একসাথে দেখতে পাবেন। এর জন্য লগইন করা থাকতে হবে।",
  },
  {
    q: "পাসওয়ার্ড ভুলে গেলে কী করব?",
    a: "লগইন পেজে 'পাসওয়ার্ড ভুলে গেছেন?' লিংকে চাপ দিয়ে আপনার ইমেইলে পাসওয়ার্ড রিসেট লিংক পাঠানো যাবে।",
  },
  {
    q: "আমার প্রোফাইল তথ্য (নাম, ছবি, ফোন) কীভাবে পরিবর্তন করব?",
    a: "নিচের নেভিগেশন বার থেকে 'প্রোফাইল' ট্যাবে গিয়ে নাম, ফোন নম্বর, লিঙ্গ ও প্রোফাইল ছবি যেকোনো সময় আপডেট করতে পারবেন।",
  },
];

export default function FaqPage() {
  const [openIndex, setOpenIndex] = useState(0);

  return (
    <div className="container max-w-2xl py-6 md:py-10">
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
            সচরাচর জিজ্ঞাসিত প্রশ্ন
          </h1>
          <p className="mt-0.5 text-sm text-muted-foreground">দ্রুত উত্তর পেতে নিচের প্রশ্নগুলো দেখুন</p>
        </div>
      </div>

      <div className="space-y-2.5">
        {FAQ_ITEMS.map((item, i) => {
          const open = openIndex === i;
          return (
            <div
              key={i}
              className="overflow-hidden rounded-xl border border-border bg-card transition-colors"
            >
              <button
                type="button"
                onClick={() => setOpenIndex(open ? -1 : i)}
                className="flex w-full items-center justify-between gap-3 px-4 py-3.5 text-left"
              >
                <span className="flex items-start gap-2.5 text-sm font-semibold text-foreground">
                  <HelpCircle className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
                  {item.q}
                </span>
                <ChevronDown
                  className={cn(
                    "h-4 w-4 shrink-0 text-muted-foreground transition-transform",
                    open && "rotate-180"
                  )}
                />
              </button>
              {open && (
                <p className="px-4 pb-4 pl-[2.1rem] text-sm leading-relaxed text-muted-foreground">
                  {item.a}
                </p>
              )}
            </div>
          );
        })}
      </div>

      <div className="mt-6 rounded-xl border border-dashed border-border bg-secondary/40 p-4 text-center text-sm text-muted-foreground">
        উত্তর খুঁজে পাননি?{" "}
        <Link to={ROUTES.HELP} className="font-semibold text-primary hover:underline">
          সাহায্য পাতায়
        </Link>{" "}
        যান।
      </div>
    </div>
  );
}
