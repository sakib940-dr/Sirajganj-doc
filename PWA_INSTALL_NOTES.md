# PWA Installation Experience — যা যোগ হলো

শুধু **"ইনস্টল করুন" প্রম্পট/সাজেশন এক্সপেরিয়েন্স** implement করা হয়েছে। বিদ্যমান
কোনো ফিচার/পেজ/ফ্লো পরিবর্তন হয়নি — নতুন কিছু "উপরে বসানো" হয়েছে মাত্র।

## যা করে

1. **অ্যাপ ইনস্টল করা না থাকলে** — মাঝে মাঝে (periodically) একটা ছোট, non-blocking
   কর্নার ব্যানার দেখায়: "বাজার অ্যাপ ইনস্টল করুন"।
2. **Dismiss (X) করলে** — সাথে সাথে আবার দেখাবে না। ক্রমবর্ধমান ব্যাকঅফ সময়
   অনুযায়ী আবার দেখাবে (৩ দিন → ৭ দিন → ১৪ দিন → ৩০ দিন), **অথবা** তার আগেই যদি
   ইউজার অ্যাপে যথেষ্ট ব্যবহার/নেভিগেশন করেন (৮টা পেজ ভিজিট) — যেটা আগে ঘটে।
3. **ইনস্টল হয়ে গেলে** — চিরস্থায়ীভাবে বন্ধ হয়ে যায়, আর কখনো দেখাবে না।
4. **কোনো জরুরি কাজে বাধা দেয় না** — এটা মোডাল/ওভারলে না, ছোট কর্নার ব্যানার
   মাত্র; Login/Register/Forgot-Password/Reset-Password পেজে একেবারেই দেখানো
   হয় না; মোবাইল ড্যাশবোর্ডের নিচের ন্যাভিগেশন বারের সাথে ওভারল্যাপ না করার
   জন্য পজিশনও এডজাস্ট করা আছে।
5. **Android / Desktop Chrome ও Edge** — নেটিভ `beforeinstallprompt` ইভেন্ট
   ব্যবহার করে সরাসরি "ইনস্টল করুন" বাটন দেখায়, ক্লিকে নেটিভ ইনস্টল ডায়ালগ
   খোলে।
6. **iOS Safari** — Apple `beforeinstallprompt` সাপোর্ট করে না, তাই সেখানে
   পরিবর্তে নির্দেশনা দেখানো হয়: শেয়ার বাটন থেকে **"Add to Home Screen"**।
7. **অসমর্থিত ব্রাউজার** (যেমন Firefox desktop) — কোনো ইনস্টল ক্ষমতা শনাক্ত না
   হলে ব্যানারটা আদৌ দেখায় না (নীরবে গ্রেসফুলি স্কিপ করে, কোনো error/ভাঙা UI
   দেখায় না)।

## কীভাবে কাজ করে (টেকনিক্যাল)

### PWA ইনফ্রাস্ট্রাকচার (নতুন)
- **`vite-plugin-pwa`** (production-grade, ব্যাপকভাবে ব্যবহৃত লাইব্রেরি) দিয়ে
  Web App Manifest ও একটা ন্যূনতম Service Worker স্বয়ংক্রিয়ভাবে জেনারেট হয়
  (`vite.config.js`-এ কনফিগার করা)।
- Service Worker শুধু build output (JS/CSS/HTML/আইকন) cache করে — কোনো
  Supabase API/ডাটা কল cache করে না, তাই ইউজার সবসময় সবশেষ পণ্য/দোকানের তথ্য
  দেখবেন (স্ট্যাল ডেটা দেখানোর ঝুঁকি নেই)।
- নতুন আইকন জেনারেট করা হয়েছে বিদ্যমান `favicon.svg` থেকে:
  `public/pwa-192x192.png`, `public/pwa-512x512.png`,
  `public/pwa-maskable-512x512.png` (Android-এর adaptive-icon সাপোর্টের জন্য
  safe-zone প্যাডিংসহ), `public/apple-touch-icon.png`।
- `index.html`-এ manifest link + theme-color + apple-mobile-web-app মেটা ট্যাগ
  যোগ করা হয়েছে।

### ইনস্টল-প্রম্পট লজিক (নতুন)
- **`src/context/PWAInstallContext.jsx`** — মূল লজিক:
  - `beforeinstallprompt` ও `appinstalled` ইভেন্ট লিসেন করে (Chrome/Edge/Android)।
  - `display-mode: standalone` / `navigator.standalone` চেক করে ইউজার হোম
    স্ক্রিন থেকে খুলেছেন কিনা বোঝে — সেক্ষেত্রে সাথে সাথে "ইনস্টল করা আছে" ধরে
    নিয়ে স্থায়ীভাবে `localStorage`-এ মার্ক করে দেয়।
  - Dismiss count, শেষ dismiss-এর সময়, ও dismiss-পরবর্তী ইন্টারঅ্যাকশন সংখ্যা
    — সবকিছু `localStorage`-এ ট্র্যাক করা হয় (ব্রাউজার/ট্যাব রিফ্রেশ/বন্ধ
    করলেও রিমেম্বার করার জন্য)।
  - প্রতি মিনিটে (এবং প্রতিটা রুট পরিবর্তনে) eligibility recheck হয়।
- **`src/components/shared/InstallPromptBanner.jsx`** — UI ব্যানার, প্ল্যাটফর্ম
  (iOS vs Android/Desktop) অনুযায়ী আলাদা কন্টেন্ট দেখায়।
- **`src/App.jsx`** — ব্যানারটা `<AppRoutes />`-এর পাশে (root লেভেলে) রেন্ডার
  করা হয়েছে, তাই এটা visitor, seller dashboard, admin panel — অ্যাপের সব
  জায়গায় consistently কাজ করে (route-ভিত্তিক exclusion শুধু auth পেজগুলোর
  জন্য প্রযোজ্য)।
- **`src/main.jsx`** — `PWAInstallProvider` যোগ করা হয়েছে (Router-এর ভেতরে,
  যেহেতু এটা route পরিবর্তন ট্র্যাক করে) + production বিল্ডে Service Worker
  রেজিস্টার করা হয়।

## Deploy করার সময় খেয়াল রাখুন

- **PWA ইনস্টল কাজ করার জন্য সাইটটা অবশ্যই HTTPS-এ (বা localhost-এ) থাকতে
  হবে** — এটা ব্রাউজারের নিজস্ব নিয়ম, কোনো কোড পরিবর্তনের বিষয় না। Vercel-এ
  ডিপ্লয় করলে এটা এমনিতেই HTTPS হয়ে যাবে।
- `npm run build` করলেই manifest ও service worker স্বয়ংক্রিয়ভাবে
  `dist/`-এ জেনারেট হয়ে যাবে — আলাদা কোনো ধাপ লাগবে না।
- Dev mode-এ (`npm run dev`) Service Worker রেজিস্টার হয় না (ইচ্ছাকৃতভাবে
  `devOptions.enabled: false` রাখা হয়েছে), তাই ডেভেলপমেন্টের সময় ক্যাশিং
  নিয়ে কোনো বিভ্রান্তি হবে না — এটা শুধু production build-এই সক্রিয় হবে।

## যা ছোঁয়া হয়নি

- Admin/Seller-এর কোনো ফাংশনালিটি
- অন্য কোনো UI/ফিচার — শুধু ব্যানার নতুন যোগ হয়েছে, আগের কিছু সরানো/পরিবর্তন
  করা হয়নি
- "নতুন ভার্সন এসেছে, রিফ্রেশ করুন" ধরনের কোনো update-notification UI
  ইচ্ছাকৃতভাবে বানানো হয়নি (স্কোপের বাইরে — শুধু ইনস্টল-এক্সপেরিয়েন্স চাওয়া
  হয়েছিল)
- Offline fallback পেজ বা ডাটা cache করার কোনো স্ট্র্যাটেজি — Service Worker
  শুধু app shell (JS/CSS/আইকন) cache করে, ডাটা/API cache করে না
