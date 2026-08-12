# 🐛 Bug Fix Notes — Seller Panel Issue

## আসল সমস্যা যা রিপোর্ট করা হয়েছিল:
> "Seller login হয়, কিন্তু panel normal visitor এর মতোই দেখায় — product add, profile
> edit, store manage কিছুই কাজ করে না।"

## 🔍 রুট কজ (Root Cause)

এটা কোনো UI/CSS বা routing সমস্যা ছিল না। **আসল সমস্যা ছিল দুটো জায়গায়:**

### 1️⃣ Database এ Critical Bug (মূল কারণ)

`supabase/migrations/0001_init.sql`-এ একটা trigger (`prevent_self_role_change`)
ছিল যেটা **নিজের role/seller_status বদলানো আটকানোর জন্য বানানো হয়েছিল** (security
এর জন্য)। কিন্তু এই trigger এতটাই কড়া ছিল যে এটা `request_seller_status()` নামের
নিরাপদ RPC function-কেও ব্লক করে দিচ্ছিল।

**ফলাফল:** যখনই কেউ Register পেজে "আমি দোকান খুলতে চাই" টিক দিয়ে অ্যাকাউন্ট
খুলতো, RPC কল হতো ঠিকই, কিন্তু trigger সেটা ব্লক করে দিতো (silently — কোনো error
দেখা যেত না কারণ frontend সেই error চেকই করতো না)। ফলে ডাটাবেসে `role` কখনো
`'seller'` হতো না, `'visitor'`-ই থেকে যেত।

এই ফিক্সটা `0004_fix_role_trigger.sql` নামে **আলাদা একটা migration ফাইলে আগে
থেকেই ছিল** — কিন্তু README-তে শুধু `0001_init.sql` রান করতে বলা হয়েছিল, `0004`
রান করার কথা কোথাও উল্লেখ ছিল না! তাই বেশিরভাগ ইউজার এই bug fix-টাই কখনো
প্রয়োগ করেননি।

**একই কারণে `profiles.email` কলাম এবং phone সেভ করার ফিক্স
(`0002_profiles_contact_info.sql`)-ও README-তে উল্লেখ ছিল না।**

### 2️⃣ Frontend এ Race Condition (দ্বিতীয় কারণ)

এমনকি Database ঠিক থাকলেও, `RegisterPage.jsx`-এ:
- `request_seller_status()` RPC কল করার পর তার **error চেক করা হতো না**
- RPC সফল হলেও, ডাটাবেসে role বদলে যাওয়ার সাথে সাথে **local React state
  (AuthContext) রিফ্রেশ না করেই সরাসরি `/dashboard`-এ navigate করে দেওয়া হতো**
- `AuthContext`-এর `onAuthStateChange` listener (যেটা profile fetch করে) একটা
  আলাদা async flow-এ চলে, এবং navigate হয়ে যাওয়ার সময় সেটা তখনো শেষ না হওয়ার
  সম্ভাবনা ছিল

**ফলাফল:** `ProtectedRoute` তখনকার (পুরনো/অসম্পূর্ণ) role দেখে বুঝতে পারতো
seller না, তাই সরাসরি Home page-এ (visitor experience) redirect করে দিতো —
এটাই দেখতে "normal visitor এর মতো panel" মনে হচ্ছিল।

---

## ✅ যা যা Fix করা হয়েছে

| # | ফাইল | সমস্যা | সমাধান |
|---|------|--------|--------|
| 1 | `supabase/migrations/0001_init.sql` | `request_seller_status()` RPC trigger দ্বারা silently block হতো | Bypass flag merge করা হলো (0004-এর ফিক্স সরাসরি 0001-এ) |
| 2 | `supabase/migrations/0001_init.sql` | `profiles.email` কলাম ছিল না, phone সেভ হতো না | email কলাম + trigger fix merge করা হলো (0002-এর ফিক্স) |
| 3 | `src/context/AuthContext.jsx` | Auth state change এর সময় `loading` flag আপডেট হতো না — ProtectedRoute তাড়াহুড়ো করে ভুল redirect করতো | `onAuthStateChange` এ `loading` প্রপারলি সেট করা হলো |
| 4 | `src/context/AuthContext.jsx` | Profile fetch fail হলে (trigger lag) সরাসরি null সেট হয়ে যেত | একবার retry যোগ করা হলো (700ms পর) |
| 5 | `src/context/AuthContext.jsx` | `refreshProfile()` stale session id ব্যবহার করতো | Explicit userId parameter নিতে পারে এখন |
| 6 | `src/pages/public/RegisterPage.jsx` | RPC error চেক হতো না, silent failure | Error চেক + user কে জানানো হয় |
| 7 | `src/pages/public/RegisterPage.jsx` | Navigate করার আগে profile refresh হতো না | `refreshProfile()` await করে তারপর navigate |
| 8 | `src/components/layout/Header.jsx` | Seller-দের জন্য আলাদা label ছিল না | "সেলার ড্যাশবোর্ড" label যোগ হলো |
| 9 | `src/pages/seller/ProductEditPage.jsx` | Error handling দুর্বল ছিল | try/catch + RLS-specific error message যোগ হলো |
| 10 | `src/pages/seller/ShopSettingsPage.jsx` | Error handling দুর্বল ছিল | try/catch + RLS-specific error message যোগ হলো |
| 11 | `README.md` | Migration instructions অসম্পূর্ণ ছিল | পরিষ্কার instructions + warning যোগ হলো |

---

## 🚀 Deploy করার সময় যা করতে হবে

### নতুন (Fresh) Supabase প্রজেক্টে:
শুধু **`supabase/migrations/0001_init.sql`** রান করলেই যথেষ্ট — সব ফিক্স এতে
merge করা আছে। `0002`, `0003`, `0004` ঐচ্ছিক (0003 শুধু demo data-এর জন্য)।

### বিদ্যমান (Existing) Supabase প্রজেক্টে (যদি আগেই পুরনো 0001 রান করা থাকে):
নিচের ফাইলগুলো ক্রমানুসারে (SQL Editor এ) রান করুন:
1. `0002_profiles_contact_info.sql`
2. `0004_fix_role_trigger.sql`

এই দুটো idempotent (`create or replace`, `if not exists` ব্যবহার করা) — আবার
রান করলেও কোনো ক্ষতি নেই।

---

## 🧪 কীভাবে টেস্ট করবেন

1. নতুন একটা Seller account দিয়ে Register করুন ("আমি দোকান খুলতে চাই" টিক দিয়ে)
2. Supabase Dashboard → Table Editor → `profiles` টেবিলে গিয়ে verify করুন যে
   নতুন রো-তে `role = 'seller'` এবং `seller_status = 'pending'` আছে
3. Admin অ্যাকাউন্ট দিয়ে লগইন করে Admin Panel → সেলার ম্যানেজমেন্ট থেকে
   Approve করুন
4. Seller অ্যাকাউন্ট দিয়ে আবার লগইন করুন → Header-এ "সেলার ড্যাশবোর্ড" দেখা
   উচিত → ক্লিক করলে Sidebar সহ Dashboard দেখা উচিত
5. দোকানের তথ্য → shop তৈরি করুন → Save করুন
6. পণ্যসমূহ → নতুন পণ্য → Product তৈরি করুন → Save করুন

সব ধাপ smooth ভাবে কাজ করা উচিত।
