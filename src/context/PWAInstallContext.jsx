import { createContext, useContext, useEffect, useMemo, useRef, useState, useCallback } from "react";
import { useLocation } from "react-router-dom";

const PWAInstallContext = createContext(null);

const STORAGE_KEYS = {
  installed: "pwa_installed",
  dismissCount: "pwa_install_dismiss_count",
  lastDismissedAt: "pwa_install_last_dismissed_at",
  interactionsSinceDismiss: "pwa_install_interactions_since_dismiss",
};

// dismiss করার পর কতদিন পর আবার সাজেশন দেখানো যাবে — প্রতিবার dismiss করলে
// অপেক্ষার সময় বাড়তে থাকে (ক্রমবর্ধমান ব্যাকঅফ), যাতে বারবার বিরক্ত না করে
const BACKOFF_INTERVALS_MS = [
  3 * 24 * 60 * 60 * 1000, // ১ম dismiss-এর পর: ৩ দিন
  7 * 24 * 60 * 60 * 1000, // ২য় dismiss-এর পর: ৭ দিন
  14 * 24 * 60 * 60 * 1000, // ৩য় dismiss-এর পর: ১৪ দিন
  30 * 24 * 60 * 60 * 1000, // এরপর থেকে সবসময়: ৩০ দিন
];

// dismiss করার পর সময়সীমা পার না হলেও, এতগুলো "মিনিংফুল ইন্টারঅ্যাকশন" (পেজ
// নেভিগেশন) হয়ে গেলে আবার সাজেশন দেখানো যাবে — যেটা আগে ঘটে সেটাই কার্যকর হবে
const INTERACTION_THRESHOLD = 8;

// অ্যাপ প্রথমবার খোলার পর কত মিলিসেকেন্ড অপেক্ষা করে প্রথম সাজেশন দেখানো হবে
// (একদম শুরুতেই দেখিয়ে গুরুত্বপূর্ণ প্রথম মুহূর্তে বিরক্ত করা এড়াতে)
const INITIAL_DELAY_MS = 20 * 1000;

// ট্যাব খোলা থাকা অবস্থায় প্রতি কতক্ষণ পরপর eligibility recheck করা হবে
const RECHECK_INTERVAL_MS = 60 * 1000;

// এসব রুটে ইনস্টল-ব্যানার দেখানো হবে না — এখানে ইউজার গুরুত্বপূর্ণ কাজে ব্যস্ত
// (লগইন/রেজিস্ট্রেশন/পাসওয়ার্ড রিসেট), তাই কোনোভাবে বিরক্ত করা ঠিক হবে না
const EXCLUDED_PATH_PREFIXES = ["/login", "/register", "/forgot-password", "/reset-password"];

function readNumber(key, fallback = 0) {
  const v = localStorage.getItem(key);
  const n = v ? Number(v) : NaN;
  return Number.isFinite(n) ? n : fallback;
}

function isStandaloneDisplayMode() {
  if (typeof window === "undefined") return false;
  return (
    window.matchMedia?.("(display-mode: standalone)")?.matches === true ||
    window.navigator?.standalone === true // iOS Safari-এর পুরনো প্রপার্টি
  );
}

function isIOSDevice() {
  if (typeof navigator === "undefined") return false;
  return /iphone|ipad|ipod/i.test(navigator.userAgent) && !window.MSStream;
}

export function PWAInstallProvider({ children }) {
  const location = useLocation();
  const appOpenedAtRef = useRef(Date.now());

  const [deferredPrompt, setDeferredPrompt] = useState(null);
  const [installed, setInstalled] = useState(
    () => localStorage.getItem(STORAGE_KEYS.installed) === "true" || isStandaloneDisplayMode()
  );
  const [visible, setVisible] = useState(false);

  const ios = isIOSDevice();
  // Chromium-ভিত্তিক ব্রাউজারে beforeinstallprompt পাওয়া গেলে সরাসরি ইনস্টল
  // বাটন দেখানো যাবে; iOS Safari-তে সেই ইভেন্ট নেই, তাই ম্যানুয়াল নির্দেশনা
  // দেখানো হয়; বাকি ব্রাউজারে (Firefox ইত্যাদি) কিছুই দেখানো হয় না
  const canSuggest = !installed && (ios || !!deferredPrompt);

  // beforeinstallprompt ও appinstalled ইভেন্ট লিসেন করা (Chrome/Edge/Android)
  useEffect(() => {
    function handleBeforeInstallPrompt(e) {
      e.preventDefault();
      setDeferredPrompt(e);
    }
    function handleAppInstalled() {
      localStorage.setItem(STORAGE_KEYS.installed, "true");
      setInstalled(true);
      setDeferredPrompt(null);
      setVisible(false);
    }
    window.addEventListener("beforeinstallprompt", handleBeforeInstallPrompt);
    window.addEventListener("appinstalled", handleAppInstalled);
    return () => {
      window.removeEventListener("beforeinstallprompt", handleBeforeInstallPrompt);
      window.removeEventListener("appinstalled", handleAppInstalled);
    };
  }, []);

  // ইউজার হোম স্ক্রিন থেকে অ্যাপ খুলেছেন কিনা (standalone display-mode) — যদি হ্যাঁ,
  // অ্যাপ ইনস্টল করা আছে ধরে নিয়ে চিরস্থায়ীভাবে প্রম্পট বন্ধ করে দেওয়া হয়
  useEffect(() => {
    if (isStandaloneDisplayMode()) {
      localStorage.setItem(STORAGE_KEYS.installed, "true");
      setInstalled(true);
    }
  }, []);

  const isEligibleNow = useCallback(() => {
    if (!canSuggest) return false;
    if (EXCLUDED_PATH_PREFIXES.some((p) => location.pathname.startsWith(p))) return false;

    const dismissCount = readNumber(STORAGE_KEYS.dismissCount, 0);
    if (dismissCount === 0) {
      return Date.now() - appOpenedAtRef.current >= INITIAL_DELAY_MS;
    }

    const lastDismissedAt = readNumber(STORAGE_KEYS.lastDismissedAt, 0);
    const interval = BACKOFF_INTERVALS_MS[Math.min(dismissCount - 1, BACKOFF_INTERVALS_MS.length - 1)];
    const intervalPassed = Date.now() - lastDismissedAt >= interval;

    const interactions = readNumber(STORAGE_KEYS.interactionsSinceDismiss, 0);
    const interactionThresholdMet = interactions >= INTERACTION_THRESHOLD;

    return intervalPassed || interactionThresholdMet;
  }, [canSuggest, location.pathname]);

  // পর্যায়ক্রমে eligibility recheck করা হয় — ট্যাব খোলা থাকলে প্রতি মিনিটে,
  // এবং প্রতিবার রুট পাল্টালে (isEligibleNow dependency-এর মাধ্যমে)
  useEffect(() => {
    const check = () => setVisible(isEligibleNow());
    check();
    const timer = setInterval(check, RECHECK_INTERVAL_MS);
    return () => clearInterval(timer);
  }, [isEligibleNow]);

  // প্রতিটা রুট পরিবর্তনকে "ইউজার ইন্টারঅ্যাকশন" হিসেবে গণনা করা — dismiss-এর পর
  // যথেষ্ট ইন্টারঅ্যাকশন হয়ে গেলে সময়সীমার আগেও আবার প্রম্পট দেখানো যায়
  useEffect(() => {
    const dismissCount = readNumber(STORAGE_KEYS.dismissCount, 0);
    if (dismissCount > 0 && !installed) {
      const next = readNumber(STORAGE_KEYS.interactionsSinceDismiss, 0) + 1;
      localStorage.setItem(STORAGE_KEYS.interactionsSinceDismiss, String(next));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [location.pathname]);

  const dismiss = useCallback(() => {
    const dismissCount = readNumber(STORAGE_KEYS.dismissCount, 0) + 1;
    localStorage.setItem(STORAGE_KEYS.dismissCount, String(dismissCount));
    localStorage.setItem(STORAGE_KEYS.lastDismissedAt, String(Date.now()));
    localStorage.setItem(STORAGE_KEYS.interactionsSinceDismiss, "0");
    setVisible(false);
  }, []);

  const install = useCallback(async () => {
    if (!deferredPrompt) return { outcome: "unavailable" };
    setVisible(false);
    deferredPrompt.prompt();
    const choice = await deferredPrompt.userChoice;
    setDeferredPrompt(null);
    if (choice.outcome === "accepted") {
      localStorage.setItem(STORAGE_KEYS.installed, "true");
      setInstalled(true);
    } else {
      // ইউজার নেটিভ প্রম্পটেও "না" বললে সেটাও dismiss হিসেবে গণনা করা হয়,
      // যাতে ব্যাকঅফ লজিক অনুযায়ী পরে আবার সাজেশন আসে
      dismiss();
    }
    return choice;
  }, [deferredPrompt, dismiss]);

  const value = useMemo(
    () => ({
      visible,
      installed,
      isIOS: ios,
      canInstallDirectly: !!deferredPrompt,
      install,
      dismiss,
    }),
    [visible, installed, ios, deferredPrompt, install, dismiss]
  );

  return <PWAInstallContext.Provider value={value}>{children}</PWAInstallContext.Provider>;
}

export function usePWAInstall() {
  const ctx = useContext(PWAInstallContext);
  if (!ctx) {
    throw new Error("usePWAInstall অবশ্যই PWAInstallProvider-এর ভেতরে ব্যবহার করতে হবে");
  }
  return ctx;
}
