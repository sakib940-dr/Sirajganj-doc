-- Seller-side সংশোধন — নিচের কলামগুলো যোগ করা হচ্ছে:
--   ১. shops.messenger_link      — সেলারের ডেডিকেটেড Messenger লিংক (Facebook Page
--      লিংক থেকে আলাদা, "Order Now" এর Messenger অপশনে সরাসরি এটাই ব্যবহৃত হবে)
--   ২. products.name_en          — পণ্যের ইংরেজি নাম (সার্চ মেটাডেটা)
--   ৩. products.name_bn          — পণ্যের বাংলা নাম (সার্চ মেটাডেটা)
--   ৪. products.search_keywords  — কমা-দিয়ে-আলাদা সমার্থক শব্দ/কীওয়ার্ড (সার্চ মেটাডেটা)
--
-- Idempotent: বারবার রান করলেও সমস্যা নেই। বিদ্যমান কোনো টেবিল/পলিসি/ডেটা মোছা বা
-- পরিবর্তন করা হয়নি — শুধু নতুন, ঐচ্ছিক (nullable) কলাম যোগ করা হয়েছে।

alter table public.shops
  add column if not exists messenger_link text;

alter table public.products
  add column if not exists name_en text,
  add column if not exists name_bn text,
  add column if not exists search_keywords text;
