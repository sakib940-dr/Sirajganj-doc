# Doctor Platform V1 — Converted Base

This is Version 1 converted from the approved local marketplace codebase.

Core mapping:
- Seller account → Doctor account
- Visitor account → Patient account
- Shop → Chamber
- Product → Doctor Profile
- Product Details → Doctor Details
- Seller verification → Doctor verification
- Super Admin / Admin → retained

The new Supabase schema is provided separately as `doctor_v1_supabase_clean.sql`.


# বাজার — বাংলা Local Marketplace (MVP v1)

React + Vite + Tailwind + shadcn/ui + Supabase দিয়ে তৈরি একটি সম্পূর্ণ বাংলা মাল্টি-শপ মার্কেটপ্লেস।

## ১. Tech Stack

- React 18 + Vite
- Tailwind CSS + shadcn/ui (component pattern)
- Supabase (Auth, PostgreSQL, Storage)
- React Router v6
- GitHub + Vercel (deployment)

## ২. প্রজেক্ট চালু করার ধাপ

### ধাপ ১ — Dependencies ইনস্টল করুন

```bash
npm install
```

### ধাপ ২ — Supabase Project তৈরি করুন

1. [supabase.com](https://supabase.com) এ গিয়ে একটি নতুন Project তৈরি করুন।
2. Project Settings → API থেকে **Project URL** ও **anon public key** কপি করুন।

### ধাপ ৩ — Environment Variable সেট করুন

`.env.example` ফাইলটি কপি করে `.env` বানান এবং মান বসান:

```bash
cp .env.example .env
```

```
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-public-key
```

### ধাপ ৪ — Database Migration রান করুন

**নতুন (fresh) Supabase প্রজেক্টের জন্য শুধু এই একটা ফাইলই যথেষ্ট:**

Supabase Dashboard → **SQL Editor** এ গিয়ে `supabase/migrations/0001_init.sql` ফাইলের সম্পূর্ণ কন্টেন্ট কপি-পেস্ট করে Run করুন।

> ⚠️ **গুরুত্বপূর্ণ:** `0001_init.sql`-এ আগে একটা bug ছিল যার কারণে "সেলার হতে চাই" আবেদন
> (register করার সময়) silently ব্যর্থ হতো এবং role কখনো `seller` হতো না — ফলে
> সেলার login করেও Dashboard-এ normal visitor-এর মতো panel দেখাতো। **এই bug এখন
> সরাসরি `0001_init.sql`-এর মধ্যেই ফিক্স করা আছে**, তাই এই আপডেটেড ফাইলটা রান করলে
> এই সমস্যা আর হবে না। (`0004_fix_role_trigger.sql` ফাইলটা শুধু পুরনো/আগে-থেকে-বানানো
> প্রজেক্টের জন্য দরকার — নতুন প্রজেক্টে এটা রান করার দরকার নেই, তবে রান করলে ক্ষতিও নেই।)

এতে তৈরি হবে:
- ৮টি টেবিল (`profiles` — email/phone সহ, `shops`, `categories`, `products`, `product_images`, `shop_gallery`, `banners`, `site_settings`)
- Row Level Security (RLS) পলিসি সব টেবিলে
- Signup হলে স্বয়ংক্রিয়ভাবে `profiles` তৈরি হওয়ার Trigger (email, phone, full_name সহ)
- `request_seller_status()` RPC — ভিজিটর নিরাপদে সেলার হওয়ার আবেদন করতে পারবে (bug-fixed)
- ৫টি Storage Bucket (`shop-logos`, `shop-banners`, `shop-gallery`, `product-images`, `site-assets`)

**পুরনো প্রজেক্ট আপগ্রেড করছেন?** যদি আপনার Supabase প্রজেক্টে আগে থেকেই পুরনো
`0001_init.sql` রান করা থাকে, তাহলে `0002_profiles_contact_info.sql` এবং
`0004_fix_role_trigger.sql` ফাইল দুটোও (SQL Editor এ) আলাদা করে রান করুন — এই bug
fix গুলো আপনার বিদ্যমান ডাটাবেসেও প্রয়োগ করার জন্য।

### ধাপ ৫ — নিজেকে প্রথম Super Admin বানান

1. প্রথমে ওয়েবসাইটে সাধারণভাবে Register করুন (`/register`)।
2. Supabase SQL Editor-এ গিয়ে (মাইগ্রেশন ফাইলের একদম শেষে থাকা কমেন্ট দেখুন):

```sql
update public.profiles
set role = 'super_admin', seller_status = 'none'
where id = (select id from auth.users where email = 'your-admin-email@example.com');
```

### ধাপ ৬ — Development সার্ভার চালু করুন

```bash
npm run dev
```

`http://localhost:5173` এ ওয়েবসাইট দেখা যাবে।

## ৩. GitHub-এ পুশ করা

```bash
git init
git add .
git commit -m "Initial commit: Bangla Marketplace MVP"
git branch -M main
git remote add origin https://github.com/your-username/your-repo.git
git push -u origin main
```

## ৪. Vercel-এ Deploy করা

1. [vercel.com](https://vercel.com) এ গিয়ে GitHub রিপোজিটরি Import করুন।
2. Framework Preset: **Vite** (স্বয়ংক্রিয়ভাবে সনাক্ত হবে)।
3. Environment Variables যোগ করুন (Vercel Project Settings → Environment Variables):
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
4. Deploy চাপুন।

## ৫. প্রজেক্ট স্ট্রাকচার সংক্ষেপে

```
src/
├── components/    # ui, layout, shared, auth, seller, admin কম্পোনেন্ট
├── constants/     # roles.js, routes.js
├── context/       # AuthContext (session + role + seller_status)
├── hooks/         # useAuth, useCategories, useShops, useProducts
├── layouts/       # MainLayout, DashboardLayout, AdminLayout
├── pages/         # public/, seller/, admin/
├── routes/        # AppRoutes.jsx — সব route এখানে
└── lib/           # supabaseClient.js, utils.js
```

## ৬. User Role ও Access

| Role | Access |
|---|---|
| Visitor | Homepage, Category, Shop, Product দেখা, Search, Register |
| Seller (Pending) | Dashboard-এ শুধু "অনুমোদনের অপেক্ষায়" বার্তা দেখতে পারবে |
| Seller (Approved) | নিজের Shop/Product/Gallery ম্যানেজ করতে পারবে |
| Super Admin | সম্পূর্ণ Admin Panel — Seller Approval, Category, Product, Banner, Settings |

## ৭. বর্তমান Development Status

- ✅ Phase 0 — Project Setup
- ✅ Phase 1 — Database, RLS, Authentication (email + phone সহ Registration)
- ✅ Phase 2 — Public Website (Homepage + Admin Banner, Category, Shop, Product, Search, WhatsApp Buy বাটন)
- ✅ Phase 3 — Seller Dashboard (Shop Info, Product CRUD, Gallery — সবই কার্যকর, ছবি আপলোডে ১০০ KB সীমা)
- ✅ Phase 4 — Admin Panel (User Management + Password Reset, Seller Approval, Category, Product, Banner, Site Settings — সবই কার্যকর ও Header/Footer-এ প্রতিফলিত)
- ⬜ Phase 5 — Polish, Full Responsive QA

## ৮.০ Phase 5 আপডেট
- ✅ Favicon যোগ হয়েছে
- ✅ Forgot Password / Reset Password ফ্লো (সেলার/ভিজিটর নিজেই ইমেইল দিয়ে reset করতে পারবে, Login পেজে লিংক আছে)
- ⬜ আসল মোবাইল ফোনে টেস্টিং (deploy করার পর নিজে যাচাই করে নিন)
- ⬜ আসল Subdomain routing (`shopname.yoursite.com`) — চাইলে ভবিষ্যতে যোগ করা যাবে, Vercel Wildcard Domain + DNS লাগবে

## ৮.১ Demo Data (Seed) — অ্যাপে কিছু না দেখালে

`supabase/migrations/0003_seed_demo_data.sql` রান করলে তৈরি হবে:
- ৬টি সাধারণ Category (ফ্যাশন, ইলেকট্রনিক্স, খাবার, ঘর সাজানো, স্বাস্থ্য-সৌন্দর্য, বই)
- ২টি Demo Seller অ্যাকাউন্ট (ইতিমধ্যে Approved) তাদের Shop-সহ
- প্রতি Shop-এ ৩টি করে Demo Product

**Demo Login:**
| ইমেইল | পাসওয়ার্ড |
|---|---|
| demo.seller1@example.com | DemoPass123 |
| demo.seller2@example.com | DemoPass123 |

এটি চালানোর পর Homepage-এ Category/Shop/Product দেখা যাবে এবং Admin Dashboard-এর Stats-এ সংখ্যা দেখাবে। **এগুলো শুধু Demo-এর জন্য** — আসল সেলার যোগ হওয়া শুরু করলে "ব্যবহারকারী ম্যানেজমেন্ট" বা "সেলার ম্যানেজমেন্ট" পেজ থেকে demo সেলার দুটো মুছে ফেলতে পারবেন।

## ৮. গুরুত্বপূর্ণ নিরাপত্তা নোট

- **Password কখনো plain text-এ কোথাও সংরক্ষণ করা হয় না** — Supabase Auth নিজেই hash করে রাখে, Admin Panel থেকেও তা দেখা যায় না। এটি একটি ইচ্ছাকৃত ডিজাইন সিদ্ধান্ত, নিরাপত্তার জন্য।
- নতুন Admin account সরাসরি email/password দিয়ে তৈরি করা হয় না (এতে `service_role` key browser-এ এক্সপোজ করা লাগতো, যা নিরাপদ না)। বদলে, **যেকোনো Registered User-কে "ব্যবহারকারী ম্যানেজমেন্ট" পেজ থেকে Admin বানানো/সরানো যায়** — একই ফলাফল, নিরাপদ পদ্ধতিতে।
- সেলার ছবি আপলোডের সময় ১০০ KB সীমা ক্লায়েন্ট সাইডে চেক করা হয় — Image Resizer (TinyPNG, Squoosh ইত্যাদি) দিয়ে ছবি ছোট করার নির্দেশনা ফর্মেই দেখানো হয়।
- Shop-এর URL (`/shop/slug`) আসলে path-based — সত্যিকারের Subdomain (যেমন `shopname.yoursite.com`) চাইলে Vercel-এ Wildcard Domain কনফিগার করতে হবে এবং আলাদা DNS + middleware সেটআপ লাগবে, যা এই MVP-তে নেই।

## ৯. Admin Panel দেখা না গেলে (404 বা ফাঁকা পেজ)

এর সবচেয়ে সাধারণ কারণ দুটো:

1. **`vercel.json` missing ছিল** — এখন যোগ করা হয়েছে। React SPA-তে `/admin`, `/dashboard`, `/shop/xyz` সরাসরি URL দিয়ে খুললে বা রিফ্রেশ করলে Vercel সেটাকে real file হিসেবে খুঁজে 404 দেখায়, যদি না তাকে বলে দেওয়া হয় সব route-কে `index.html`-এ পাঠাতে। Redeploy করার পর এটা ঠিক হয়ে যাবে।
2. **আপনি এখনো Super Admin না হলে** — Login করা থাকলেও role `super_admin` না হলে `/admin`-এ ঢুকতে চাইলে স্বয়ংক্রিয়ভাবে Homepage-এ Redirect হবে (কোনো error দেখাবে না)। ধাপ ৫ (উপরে) অনুসরণ করে নিজেকে Super Admin বানিয়ে নিন।

## ১০.১ নতুন Role সিস্টেম — Admin ও Super Admin (আপডেট)

আগের একক `super_admin` role এখন দুই ভাগে ভাগ করা হয়েছে:

| Role | পারবে | পারবে না |
|---|---|---|
| **Admin** | Admin Panel অ্যাক্সেস, সেলার অনুমোদন/ভেরিফিকেশন, ক্যাটাগরি/পণ্য/ব্যানার/সাইট সেটিংস ম্যানেজ করা | নতুন Admin/Super Admin বানানো, কারো role/account status পরিবর্তন করা |
| **Super Admin** | সব কিছু — role পরিবর্তন, ব্যান/আনব্যান/ডিলিট, প্রতি দোকানের পণ্য সীমা বাড়ানো/কমানো, "লগইন অ্যাক্সেস" পেজ | — |

**ডিপ্লয় করার সময় করণীয়:**

1. Supabase SQL Editor-এ `supabase/migrations/0006_role_and_admin_update.sql` রান করুন (idempotent, নতুন ও বিদ্যমান দুই ধরনের প্রজেক্টেই)। এটি আপনার আগের সব `super_admin` ইউজারকে স্বয়ংক্রিয়ভাবে `admin`-এ রূপান্তর করবে (একবারই — আবার রান করলে সমস্যা হবে না)।
2. রান করার পর অন্তত একজনকে ম্যানুয়ালি আসল Super Admin বানান (মাইগ্রেশন ফাইলের শুরুতে SQL কমেন্ট দেওয়া আছে)।
3. নতুন Edge Function ডিপ্লয় করুন (ব্যান/আনব্যান/ডিলিটের জন্য):

```bash
supabase functions deploy admin-manage-user
```

**নিরাপত্তা সংক্রান্ত একটি সিদ্ধান্ত:** মূল স্পেসিফিকেশনে "User Credentials" পেজে পাসওয়ার্ড প্লেইন টেক্সটে সংরক্ষণের কথা বলা হয়েছিল। এটি বাস্তবায়ন করা হয়নি, কারণ প্লেইন-টেক্সট পাসওয়ার্ড সংরক্ষণ একটি গুরুতর নিরাপত্তা ঝুঁকি (ডাটাবেস ফাঁস হলে সব ইউজারের পাসওয়ার্ড উন্মুক্ত হয়ে যায়) এবং এই প্রজেক্টের নিজস্ব নিরাপত্তা নীতির (উপরে ৮ নং সেকশন দেখুন) সরাসরি বিপরীত। এর বদলে "লগইন অ্যাক্সেস" পেজে (শুধুমাত্র Super Admin) বিদ্যমান নিরাপদ পাসওয়ার্ড-রিসেট ফ্লো ব্যবহার করা হয়েছে — কোনো পাসওয়ার্ড কখনো ডাটাবেসে বা কোথাও প্লেইন টেক্সটে সংরক্ষিত হয় না।

## ১০. Password Reset (Super Admin → Seller)

Super Admin এখন "ব্যবহারকারী ম্যানেজমেন্ট" পেজ থেকে যেকোনো ইউজারের পাসওয়ার্ড রিসেট করতে পারবেন। এটি কাজ করে একটি Supabase **Edge Function** এর মাধ্যমে (`supabase/functions/admin-reset-password`), কারণ পাসওয়ার্ড পরিবর্তন করতে `service_role` key লাগে যা কখনো browser-এ রাখা নিরাপদ না — তাই এটা সার্ভার সাইডে চলে।

**যেভাবে কাজ করে:**
- Admin "পাসওয়ার্ড রিসেট" বাটনে ক্লিক করলে একটি র‍্যান্ডম নতুন পাসওয়ার্ড তৈরি হয় ও সেট হয়ে যায়
- নতুন পাসওয়ার্ডটি **শুধু একবার**, স্ক্রিনে দেখানো হয় (কপি করার অপশনসহ) — কোথাও সংরক্ষণ করা হয় না
- Admin সেটা কপি করে নিরাপদ কোনো চ্যানেলে (ফোনে বলে, বা ব্যক্তিগত মেসেজে) সেলারকে জানিয়ে দেবেন

**Deploy করার নিয়ম:**
```bash
# Supabase CLI ইনস্টল না থাকলে আগে ইনস্টল করুন: https://supabase.com/docs/guides/cli
supabase login
supabase link --project-ref your-project-ref
supabase functions deploy admin-reset-password
```
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` — এই তিনটি Secret Supabase Edge Function-এ Deploy করার সময় স্বয়ংক্রিয়ভাবেই available থাকে, আলাদা করে সেট করতে হয় না।

> **নোট:** এই সিস্টেমেও কোথাও plain-text পাসওয়ার্ড ডাটাবেসে সংরক্ষিত হয় না — শুধু Admin নতুন পাসওয়ার্ড *সেট* করতে পারেন এবং একবার দেখতে পারেন, যা সেলারের কাছে পৌঁছে দেওয়ার জন্যই যথেষ্ট।
