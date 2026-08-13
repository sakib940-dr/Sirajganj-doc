-- ============================================================
-- Doctor V1 starter public data: 10 Doctors + 5 Chambers
-- These are seeded application records so Super Admin can manage/delete them.
-- They are NOT labeled as demo data in the public UI.
-- Auth rows are seed identities without passwords; create real accounts through registration when needed.
-- ============================================================

insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000001','doctor01@sirajganjdoctor.demo','{"full_name": "ডা. মোঃ রাকিব হাসান", "phone": "01711000001"}'::jsonb)
on conflict (id) do nothing;
insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000002','doctor02@sirajganjdoctor.demo','{"full_name": "ডা. ফারহানা আক্তার", "phone": "01711000002"}'::jsonb)
on conflict (id) do nothing;
insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000003','doctor03@sirajganjdoctor.demo','{"full_name": "ডা. মোঃ সাইফুল ইসলাম", "phone": "01711000003"}'::jsonb)
on conflict (id) do nothing;
insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000004','doctor04@sirajganjdoctor.demo','{"full_name": "ডা. তানভীর আহমেদ", "phone": "01711000004"}'::jsonb)
on conflict (id) do nothing;
insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000005','doctor05@sirajganjdoctor.demo','{"full_name": "ডা. নাজমুল হক", "phone": "01711000005"}'::jsonb)
on conflict (id) do nothing;
insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000006','doctor06@sirajganjdoctor.demo','{"full_name": "ডা. মাহমুদুল হাসান", "phone": "01711000006"}'::jsonb)
on conflict (id) do nothing;
insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000007','doctor07@sirajganjdoctor.demo','{"full_name": "ডা. সাবিহা রহমান", "phone": "01711000007"}'::jsonb)
on conflict (id) do nothing;
insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000008','doctor08@sirajganjdoctor.demo','{"full_name": "ডা. মেহেদী হাসান", "phone": "01711000008"}'::jsonb)
on conflict (id) do nothing;
insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000009','doctor09@sirajganjdoctor.demo','{"full_name": "ডা. শারমিন সুলতানা", "phone": "01711000009"}'::jsonb)
on conflict (id) do nothing;
insert into auth.users (id,email,raw_user_meta_data)
values ('a1000000-0000-0000-0000-000000000010','doctor10@sirajganjdoctor.demo','{"full_name": "ডা. আরিফুল ইসলাম", "phone": "01711000010"}'::jsonb)
on conflict (id) do nothing;

update public.profiles
set full_name='ডা. মোঃ রাকিব হাসান', phone='01711000001', email='doctor01@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000001';
update public.profiles
set full_name='ডা. ফারহানা আক্তার', phone='01711000002', email='doctor02@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000002';
update public.profiles
set full_name='ডা. মোঃ সাইফুল ইসলাম', phone='01711000003', email='doctor03@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000003';
update public.profiles
set full_name='ডা. তানভীর আহমেদ', phone='01711000004', email='doctor04@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000004';
update public.profiles
set full_name='ডা. নাজমুল হক', phone='01711000005', email='doctor05@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000005';
update public.profiles
set full_name='ডা. মাহমুদুল হাসান', phone='01711000006', email='doctor06@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000006';
update public.profiles
set full_name='ডা. সাবিহা রহমান', phone='01711000007', email='doctor07@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000007';
update public.profiles
set full_name='ডা. মেহেদী হাসান', phone='01711000008', email='doctor08@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000008';
update public.profiles
set full_name='ডা. শারমিন সুলতানা', phone='01711000009', email='doctor09@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000009';
update public.profiles
set full_name='ডা. আরিফুল ইসলাম', phone='01711000010', email='doctor10@sirajganjdoctor.demo', role='doctor', seller_status='approved', account_status='active'
where id='a1000000-0000-0000-0000-000000000010';

insert into public.shops
(id,owner_id,shop_name,slug,logo_url,banner_url,about,phone,whatsapp_number,address,google_map_link,chamber_name,chamber_type,visiting_days,visiting_time,consultation_fee,assistant_phone,is_active)
values
('b1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','সিরাজগঞ্জ হার্ট কেয়ার','chamber-01','/demo/chamber-1.svg','/demo/chamber-banner-1.svg','সিরাজগঞ্জের রোগীদের জন্য নির্ভরযোগ্য চিকিৎসা সেবা ও বিশেষজ্ঞ ডাক্তারদের চেম্বার।','01712000001','880171200001','এসএস রোড, সিরাজগঞ্জ সদর','https://maps.google.com/?q=এসএস+রোড,+সিরাজগঞ্জ+সদর','সিরাজগঞ্জ হার্ট কেয়ার','চেম্বার','শনি – বৃহস্পতি','বিকেল ৪টা – রাত ৯টা',NULL,'01712000001',true)
on conflict (id) do update set shop_name=excluded.shop_name, logo_url=excluded.logo_url, banner_url=excluded.banner_url, address=excluded.address;
insert into public.shops
(id,owner_id,shop_name,slug,logo_url,banner_url,about,phone,whatsapp_number,address,google_map_link,chamber_name,chamber_type,visiting_days,visiting_time,consultation_fee,assistant_phone,is_active)
values
('b1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000002','সিরাজগঞ্জ মেডিকেল সেন্টার','chamber-02','/demo/chamber-2.svg','/demo/chamber-banner-2.svg','সিরাজগঞ্জের রোগীদের জন্য নির্ভরযোগ্য চিকিৎসা সেবা ও বিশেষজ্ঞ ডাক্তারদের চেম্বার।','01712000002','880171200002','বাজার স্টেশন, সিরাজগঞ্জ সদর','https://maps.google.com/?q=বাজার+স্টেশন,+সিরাজগঞ্জ+সদর','সিরাজগঞ্জ মেডিকেল সেন্টার','চেম্বার','শনি – বৃহস্পতি','বিকেল ৪টা – রাত ৯টা',NULL,'01712000002',true)
on conflict (id) do update set shop_name=excluded.shop_name, logo_url=excluded.logo_url, banner_url=excluded.banner_url, address=excluded.address;
insert into public.shops
(id,owner_id,shop_name,slug,logo_url,banner_url,about,phone,whatsapp_number,address,google_map_link,chamber_name,chamber_type,visiting_days,visiting_time,consultation_fee,assistant_phone,is_active)
values
('b1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000003','মা ও শিশু ক্লিনিক','chamber-03','/demo/chamber-3.svg','/demo/chamber-banner-3.svg','সিরাজগঞ্জের রোগীদের জন্য নির্ভরযোগ্য চিকিৎসা সেবা ও বিশেষজ্ঞ ডাক্তারদের চেম্বার।','01712000003','880171200003','মুজিব সড়ক, সিরাজগঞ্জ সদর','https://maps.google.com/?q=মুজিব+সড়ক,+সিরাজগঞ্জ+সদর','মা ও শিশু ক্লিনিক','চেম্বার','শনি – বৃহস্পতি','বিকেল ৪টা – রাত ৯টা',NULL,'01712000003',true)
on conflict (id) do update set shop_name=excluded.shop_name, logo_url=excluded.logo_url, banner_url=excluded.banner_url, address=excluded.address;
insert into public.shops
(id,owner_id,shop_name,slug,logo_url,banner_url,about,phone,whatsapp_number,address,google_map_link,chamber_name,chamber_type,visiting_days,visiting_time,consultation_fee,assistant_phone,is_active)
values
('b1000000-0000-0000-0000-000000000004','a1000000-0000-0000-0000-000000000004','সিরাজগঞ্জ চক্ষু ও অর্থোপেডিক সেন্টার','chamber-04','/demo/chamber-4.svg','/demo/chamber-banner-4.svg','সিরাজগঞ্জের রোগীদের জন্য নির্ভরযোগ্য চিকিৎসা সেবা ও বিশেষজ্ঞ ডাক্তারদের চেম্বার।','01712000004','880171200004','হাসপাতাল রোড, সিরাজগঞ্জ সদর','https://maps.google.com/?q=হাসপাতাল+রোড,+সিরাজগঞ্জ+সদর','সিরাজগঞ্জ চক্ষু ও অর্থোপেডিক সেন্টার','চেম্বার','শনি – বৃহস্পতি','বিকেল ৪টা – রাত ৯টা',NULL,'01712000004',true)
on conflict (id) do update set shop_name=excluded.shop_name, logo_url=excluded.logo_url, banner_url=excluded.banner_url, address=excluded.address;
insert into public.shops
(id,owner_id,shop_name,slug,logo_url,banner_url,about,phone,whatsapp_number,address,google_map_link,chamber_name,chamber_type,visiting_days,visiting_time,consultation_fee,assistant_phone,is_active)
values
('b1000000-0000-0000-0000-000000000005','a1000000-0000-0000-0000-000000000005','সিরাজগঞ্জ ডায়াগনস্টিক সেন্টার','chamber-05','/demo/chamber-5.svg','/demo/chamber-banner-5.svg','সিরাজগঞ্জের রোগীদের জন্য নির্ভরযোগ্য চিকিৎসা সেবা ও বিশেষজ্ঞ ডাক্তারদের চেম্বার।','01712000005','880171200005','এসএস রোড, সিরাজগঞ্জ সদর','https://maps.google.com/?q=এসএস+রোড,+সিরাজগঞ্জ+সদর','সিরাজগঞ্জ ডায়াগনস্টিক সেন্টার','চেম্বার','শনি – বৃহস্পতি','বিকেল ৪টা – রাত ৯টা',NULL,'01712000005',true)
on conflict (id) do update set shop_name=excluded.shop_name, logo_url=excluded.logo_url, banner_url=excluded.banner_url, address=excluded.address;

insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000001',(select id from public.categories where slug='cardiology'),'ডা. মোঃ রাকিব হাসান','doctor-01','ডা. মোঃ রাকিব হাসান একজন অভিজ্ঞ হৃদরোগ বিশেষজ্ঞ। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',800,'/demo/doctor-1.svg',true,'এমবিবিএস, এফসিপিএস','হৃদরোগ বিশেষজ্ঞ','BMDC-10001',800,'শনি, সোম, বুধ','বিকেল ৫টা – রাত ৮টা','/demo/doctor-1.svg',true,'a1000000-0000-0000-0000-000000000001',1200,90,150,12)
on conflict (slug) do nothing;
insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000001',(select id from public.categories where slug='gynecology-obstetrics'),'ডা. ফারহানা আক্তার','doctor-02','ডা. ফারহানা আক্তার একজন অভিজ্ঞ স্ত্রী ও প্রসূতি বিশেষজ্ঞ। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',700,'/demo/doctor-2.svg',true,'এমবিবিএস, এফসিপিএস','স্ত্রী ও প্রসূতি বিশেষজ্ঞ','BMDC-10002',700,'রবি, মঙ্গল, বৃহস্পতি','বিকেল ৪টা – রাত ৭টা','/demo/doctor-2.svg',true,'a1000000-0000-0000-0000-000000000002',1127,87,143,11)
on conflict (slug) do nothing;
insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000002',(select id from public.categories where slug='pediatrics'),'ডা. মোঃ সাইফুল ইসলাম','doctor-03','ডা. মোঃ সাইফুল ইসলাম একজন অভিজ্ঞ শিশু বিশেষজ্ঞ। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',600,'/demo/doctor-3.svg',true,'এমবিবিএস, এমডি','শিশু বিশেষজ্ঞ','BMDC-10003',600,'শনি, সোম, বুধ','সন্ধ্যা ৬টা – রাত ৯টা','/demo/doctor-3.svg',true,'a1000000-0000-0000-0000-000000000003',1054,84,136,10)
on conflict (slug) do nothing;
insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000002',(select id from public.categories where slug='ophthalmology'),'ডা. তানভীর আহমেদ','doctor-04','ডা. তানভীর আহমেদ একজন অভিজ্ঞ চক্ষু বিশেষজ্ঞ। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',700,'/demo/doctor-4.svg',true,'এমবিবিএস, এফসিপিএস','চক্ষু বিশেষজ্ঞ','BMDC-10004',700,'রবি, মঙ্গল, বৃহস্পতি','বিকেল ৫টা – রাত ৮টা','/demo/doctor-4.svg',true,'a1000000-0000-0000-0000-000000000004',981,81,129,9)
on conflict (slug) do nothing;
insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000003',(select id from public.categories where slug='dentistry'),'ডা. নাজমুল হক','doctor-05','ডা. নাজমুল হক একজন অভিজ্ঞ দন্ত চিকিৎসক। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',500,'/demo/doctor-5.svg',true,'বিডিএস, এফসিপিএস','দন্ত চিকিৎসক','BMDC-10005',500,'শনি – বৃহস্পতিবার','সন্ধ্যা ৫টা – রাত ৯টা','/demo/doctor-5.svg',true,'a1000000-0000-0000-0000-000000000005',908,78,122,8)
on conflict (slug) do nothing;
insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000003',(select id from public.categories where slug='medicine'),'ডা. মাহমুদুল হাসান','doctor-06','ডা. মাহমুদুল হাসান একজন অভিজ্ঞ মেডিসিন বিশেষজ্ঞ। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',600,'/demo/doctor-6.svg',true,'এমবিবিএস, এফসিপিএস','মেডিসিন বিশেষজ্ঞ','BMDC-10006',600,'শনি, সোম, বুধ','বিকেল ৪টা – রাত ৮টা','/demo/doctor-6.svg',true,'a1000000-0000-0000-0000-000000000006',835,75,115,7)
on conflict (slug) do nothing;
insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000004',(select id from public.categories where slug='dermatology'),'ডা. সাবিহা রহমান','doctor-07','ডা. সাবিহা রহমান একজন অভিজ্ঞ চর্মরোগ বিশেষজ্ঞ। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',700,'/demo/doctor-7.svg',true,'এমবিবিএস, এমডি','চর্মরোগ বিশেষজ্ঞ','BMDC-10007',700,'রবি, মঙ্গল, বৃহস্পতি','বিকেল ৫টা – রাত ৮টা','/demo/doctor-7.svg',true,'a1000000-0000-0000-0000-000000000007',762,72,108,6)
on conflict (slug) do nothing;
insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000004',(select id from public.categories where slug='orthopedics'),'ডা. মেহেদী হাসান','doctor-08','ডা. মেহেদী হাসান একজন অভিজ্ঞ অর্থোপেডিক বিশেষজ্ঞ। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',800,'/demo/doctor-8.svg',true,'এমবিবিএস, এমএস','অর্থোপেডিক বিশেষজ্ঞ','BMDC-10008',800,'শনি, সোম, বুধ','সন্ধ্যা ৬টা – রাত ৯টা','/demo/doctor-8.svg',true,'a1000000-0000-0000-0000-000000000008',689,69,101,5)
on conflict (slug) do nothing;
insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000005',(select id from public.categories where slug='ent'),'ডা. শারমিন সুলতানা','doctor-09','ডা. শারমিন সুলতানা একজন অভিজ্ঞ নাক-কান-গলা বিশেষজ্ঞ। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',650,'/demo/doctor-9.svg',true,'এমবিবিএস, এমডি','নাক-কান-গলা বিশেষজ্ঞ','BMDC-10009',650,'রবি, মঙ্গল, বৃহস্পতি','বিকেল ৪টা – রাত ৭টা','/demo/doctor-9.svg',true,'a1000000-0000-0000-0000-000000000009',616,66,94,4)
on conflict (slug) do nothing;
insert into public.products
(shop_id,category_id,name,slug,description,price,thumbnail_url,is_active,degree,designation,bmdc_registration_no,consultation_fee,visiting_days,visiting_time,profile_photo_url,verified_badge,doctor_id,view_count,save_count,click_count,sold_count)
values
('b1000000-0000-0000-0000-000000000005',(select id from public.categories where slug='neurology'),'ডা. আরিফুল ইসলাম','doctor-10','ডা. আরিফুল ইসলাম একজন অভিজ্ঞ স্নায়ুরোগ বিশেষজ্ঞ। সিরাজগঞ্জে রোগী দেখেন এবং প্রয়োজন অনুযায়ী পরামর্শ ও চিকিৎসা প্রদান করেন।',900,'/demo/doctor-10.svg',true,'এমবিবিএস, এফসিপিএস','স্নায়ুরোগ বিশেষজ্ঞ','BMDC-10010',900,'শনি, সোম, বুধ','সন্ধ্যা ৬টা – রাত ৯টা','/demo/doctor-10.svg',true,'a1000000-0000-0000-0000-000000000010',543,63,87,3)
on conflict (slug) do nothing;

-- Optional check
select p.full_name, p.role, p.seller_status from public.profiles p
where p.role='doctor' and p.email like '%@sirajganjdoctor.demo'
order by p.created_at;