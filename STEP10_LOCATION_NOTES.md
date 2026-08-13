# Step 10 — Visitor Location

## New behavior
- Homepage: category section-এর ঠিক পরে "আপনার এলাকার ডাক্তার" section.
- Visitor can tap "অবস্থান অনুমতি দিন"; browser/PWA location permission is requested.
- Exact coordinates are not stored in Supabase.
- Reverse geocoding is used only to determine district/upazila.
- Visitor can manually select Sirajganj + any of its 9 upazilas.
- If an upazila is selected, that upazila's doctors appear first; immediately below, all doctors in the district appear.
- If only a district is selected, the district doctors appear in the top location section.
- Chamber/Hospital location is the source of a doctor's district/upazila.
- SQL file `supabase/step10_location.sql` adds location columns and seeds starter chamber locations.

## SQL
Run `supabase/step10_location.sql` after the earlier Step 8/9 SQL files. It is intentionally separate because the user plans to run it later.
