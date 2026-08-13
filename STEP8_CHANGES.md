# Doctor Platform V1 — Step 8

## Included
- 10 starter Doctor profiles and 5 starter Chambers via `supabase/step8_demo_data.sql`
- Doctor portrait SVGs and Chamber logo SVGs under `public/demo/`
- Bangla medical category names + category icons
- Chamber/Hospital role support
- Chamber/Hospital registration request
- Chamber/Hospital can add approved Doctor profiles under its Chamber
- Doctor profile cards are larger on mobile and do not show consultation fee
- Doctor detail page shows fee, visiting time, contact and appointment
- Share button for Doctor profile; Chamber share already supported
- Dynamic page metadata + SEO defaults
- All image uploaders accept up to 1 MB and auto-compress large images to about 100–200 KB
- Fixed Doctor dashboard appointment button layout
- Super Admin setup instructions in the Admin credentials page

## Supabase action
Run `supabase/step8_upgrade.sql` ONCE on the existing new Supabase project.

Then run `supabase/step8_demo_data.sql` ONCE if you want the 10 starter doctors + 5 chambers.

The demo Auth seed rows are intentionally not password-login accounts. Real Doctor/Chamber accounts should be created through the app or Supabase Auth. The seeded public records can be removed later by Super Admin.

## Super Admin
Create the first Auth user in Supabase Authentication, then use the SQL shown in Admin → Login Access to promote it to `super_admin`.

Never put a Supabase secret/service-role key in the frontend or Vercel public environment.
