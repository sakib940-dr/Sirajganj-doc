# Product Analytics — যা যোগ হলো

## কী কী ট্র্যাক হচ্ছে (প্রতিটি পণ্যের জন্য আলাদা)

| মেট্রিক | কখন বাড়ে |
|---|---|
| **Total Views** | কোনো ভিজিটর পণ্যের পেজ (`/product/:slug`) খুললে (একই লোডে একবারই গোনা হয়) |
| **Save Count** | লগইন করা ইউজার পণ্য পেজে ♥ বাটনে ক্লিক করে সেভ করলে (আনসেভ করলে কমে) |
| **Order Button Click Count** | নতুন **"অর্ডার করুন"** বাটনে ক্লিক করলে |

## "অর্ডার করুন" বাটন (আগে ছিল "হোয়াটসঅ্যাপে কিনুন")

- দোকানে **WhatsApp নম্বর** থাকলে → WhatsApp-এ খুলবে (আগের মতোই প্রি-ফিলড মেসেজসহ)।
- WhatsApp নম্বর না থাকলে কিন্তু **Facebook Page লিংক** থাকলে → সেই Facebook পেজ/মেসেঞ্জার খুলবে।
- দুটোর একটাও না থাকলে বাটন দেখাবে না (আগের আচরণের মতোই)।
- কোন চ্যানেলেই যাক, ক্লিক হওয়া মাত্র (page navigate হওয়ার আগেই, fire-and-forget ভাবে) `click_count` বাড়ে।

## Save (♥) বাটন

- শুধুমাত্র **লগইন করা ইউজার** সেভ করতে পারবেন। লগইন না থাকলে বাটনে ক্লিক করলে সরাসরি Login পেজে নিয়ে যাবে।
- Toggle বাটন — একবার ক্লিকে সেভ, আবার ক্লিকে আনসেভ। প্রতি ইউজার প্রতি পণ্য একবারই গণনা হয় (ডাটাবেসে unique constraint আছে)।

## Real-time আপডেট (Seller Dashboard → অ্যানালিটিক্স)

- Seller Dashboard-এর "অ্যানালিটিক্স" পেজে এখন প্রতিটি পণ্যের Views/Save/Click আলাদা টেবিলে দেখা যায়, সাথে উপরে সামারি কার্ড (মোট ভিউ, মোট সেভ, মোট অর্ডার ক্লিক)।
- এটি **Supabase Realtime** subscription ব্যবহার করে — কোনো ভিজিটর কোনো পণ্য দেখলে/সেভ করলে/ক্লিক করলে সেলারের Analytics পেজে পেজ রিফ্রেশ ছাড়াই কয়েক মুহূর্তের মধ্যে সংখ্যা আপডেট হয়ে যায় (near real-time)।
- **কোনো chart/গ্রাফ এখনো যোগ করা হয়নি** — শুধু সংখ্যা (এটা ইচ্ছাকৃতভাবে বাকি রাখা হয়েছে, পরবর্তী ধাপে করা যাবে)।

## Database পরিবর্তন — `supabase/migrations/0010_product_analytics.sql`

**Deploy করার সময় এই একটা ফাইল Supabase SQL Editor-এ রান করলেই যথেষ্ট** (idempotent — আগেই রান করা থাকলেও সমস্যা হবে না)।

- `products` টেবিলে ৩টা নতুন কলাম: `view_count`, `save_count`, `click_count` (সবগুলো `integer default 0`)।
- নতুন টেবিল `product_saves` (`product_id`, `user_id`) — RLS দিয়ে সুরক্ষিত, প্রতিটা ইউজার শুধু নিজেরটাই insert/delete/select করতে পারবে। Insert/Delete হলে trigger দিয়ে `products.save_count` automatically atomic ভাবে আপডেট হয়।
- দুটো `SECURITY DEFINER` RPC ফাংশন — `increment_product_view()` ও `increment_product_order_click()` — visitor/anon সহ যে কেউ কল করতে পারবে, কিন্তু শুধু নির্দিষ্ট কাউন্টার কলামটাই বাড়ে (এবং শুধু সক্রিয় পণ্যের জন্যই), অন্য কোনো ডেটা পরিবর্তনের অনুমতি নেই।
- `products` টেবিলকে Supabase-এর `supabase_realtime` publication-এ যোগ করা হয়েছে, যাতে Analytics পেজে real-time আপডেট কাজ করে।

**নতুন Edge Function বা deploy করার আলাদা কোনো ধাপ নেই** — শুধু SQL মাইগ্রেশনটা রান করলেই ফ্রন্টএন্ড কোড কাজ করবে।

## Frontend-এ পরিবর্তিত/নতুন ফাইল

- `src/hooks/useProductAnalytics.js` — **নতুন**: `trackProductView()`, `trackProductOrderClick()`, `useProductSave()`।
- `src/hooks/useProducts.js` — পণ্যের সাথে দোকানের `facebook_link`-ও select করা হচ্ছে (Order বাটনের fallback-এর জন্য)।
- `src/pages/public/ProductPage.jsx` — ভিউ ট্র্যাকিং, ♥ Save বাটন, "অর্ডার করুন" বাটন (WhatsApp/Facebook fallback + ক্লিক ট্র্যাকিং)।
- `src/pages/seller/AnalyticsPage.jsx` — সম্পূর্ণ নতুন করে লেখা হয়েছে: সামারি কার্ড + প্রতি-পণ্য টেবিল + Realtime subscription।

## যা ইচ্ছাকৃতভাবে ছোঁয়া হয়নি

- Admin Panel, Shop Settings, Gallery, Product CRUD ফর্ম, RLS-এর বিদ্যমান পলিসিগুলো — কোনোটাই পরিবর্তন হয়নি।
- Dashboard চার্ট/গ্রাফ — এখনো যোগ করা হয়নি (স্পেসিফিকেশন অনুযায়ী ইচ্ছাকৃতভাবে বাদ)।
- `ProductCard`/হোমপেজ/ক্যাটাগরি/সার্চ লিস্টিং UI অপরিবর্তিত (Save বাটন শুধু Product Detail পেজে, যাতে scope সীমিত থাকে)।
