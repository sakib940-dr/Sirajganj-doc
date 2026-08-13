-- Step 21: Remove old Doctor V1/demo seed records from the EXISTING database.
-- Run once if Step 8 demo data was previously executed.
-- This targets only the known demo slugs/emails from the Doctor V1 seed.
-- It does NOT delete real doctor/hospital accounts.

begin;

-- Remove child records first where possible.
delete from public.product_images
where product_id in (
  select id from public.products
  where slug in ('doctor-01','doctor-02','doctor-03','doctor-04','doctor-05',
                 'doctor-06','doctor-07','doctor-08','doctor-09','doctor-10')
);

delete from public.products
where slug in ('doctor-01','doctor-02','doctor-03','doctor-04','doctor-05',
               'doctor-06','doctor-07','doctor-08','doctor-09','doctor-10');

delete from public.shops
where slug in ('chamber-01','chamber-02','chamber-03','chamber-04','chamber-05');

delete from public.profiles
where email in (
  'doctor01@sirajganjdoctor.demo','doctor02@sirajganjdoctor.demo',
  'doctor03@sirajganjdoctor.demo','doctor04@sirajganjdoctor.demo',
  'doctor05@sirajganjdoctor.demo','doctor06@sirajganjdoctor.demo',
  'doctor07@sirajganjdoctor.demo','doctor08@sirajganjdoctor.demo',
  'doctor09@sirajganjdoctor.demo','doctor10@sirajganjdoctor.demo',
  'demo.seller1@example.com','demo.seller2@example.com'
);

-- If the old demo auth users still exist, remove them separately in Supabase Auth
-- Dashboard > Authentication > Users. SQL cannot safely delete auth users from
-- client-facing tables in all project configurations.

commit;
