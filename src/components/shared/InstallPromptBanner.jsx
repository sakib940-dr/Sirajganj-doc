import { Download, X, Share } from "lucide-react";
import { usePWAInstall } from "@/context/PWAInstallContext.jsx";

// একটা ছোট, non-blocking কর্নার ব্যানার — কোনো মোডাল/ওভারলে না থাকায় এটা কখনো
// ইউজারের চলমান কাজে (ফর্ম পূরণ, স্ক্রলিং ইত্যাদি) বাধা দেয় না, শুধু বন্ধ করার
// (X) অপশনসহ একটা সাজেশন দেখায়
export default function InstallPromptBanner() {
  const { visible, installed, isIOS, canInstallDirectly, install, dismiss } = usePWAInstall();

  if (!visible || installed) return null;

  return (
    <div
      role="dialog"
      aria-label="অ্যাপ ইনস্টল করার সাজেশন"
      className="fixed inset-x-3 bottom-20 z-50 mx-auto max-w-md rounded-xl border border-border bg-card p-4 shadow-lg animate-in fade-in-0 slide-in-from-bottom-4 md:inset-x-auto md:bottom-4 md:right-4 md:w-96"
    >
      <button
        type="button"
        onClick={dismiss}
        aria-label="বন্ধ করুন"
        className="absolute right-2 top-2 flex h-7 w-7 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-secondary hover:text-foreground"
      >
        <X className="h-4 w-4" />
      </button>

      <div className="flex items-start gap-3 pr-6">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary text-primary-foreground">
          <Download className="h-5 w-5" />
        </span>
        <div className="flex-1">
          <p className="text-sm font-semibold text-foreground">বাজার অ্যাপ ইনস্টল করুন</p>

          {isIOS ? (
            <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
              হোম স্ক্রিনে যোগ করতে নিচের শেয়ার <Share className="inline h-3.5 w-3.5 align-text-bottom" /> বাটনে ট্যাপ
              করে <span className="font-medium text-foreground">"Add to Home Screen"</span> নির্বাচন করুন।
            </p>
          ) : (
            <>
              <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                দ্রুত অ্যাক্সেস ও ভালো অভিজ্ঞতার জন্য হোম স্ক্রিনে যোগ করুন — কোনো অ্যাপ স্টোরের দরকার নেই।
              </p>
              {canInstallDirectly && (
                <button
                  type="button"
                  onClick={install}
                  className="mt-3 inline-flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-xs font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
                >
                  <Download className="h-3.5 w-3.5" />
                  ইনস্টল করুন
                </button>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
