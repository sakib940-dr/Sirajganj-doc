# Step 10 — Visitor Location & Area Doctor Sections

Implemented:
- Location permission request on first homepage visit, with a manual retry button.
- Exact coordinates are not stored in Supabase.
- Reverse-geocodes only to district/upazila.
- Manual district/upazila selection.
- Sirajganj's 9 upazilas are available.
- After the category section, selected-area doctors appear first.
- If an upazila is selected, the next section shows all doctors in the selected district.
- Doctor location is derived from the Chamber/Hospital's district/upazila.
- Chamber/Hospital settings now include district/upazila fields.
- Added supabase/step10_location.sql; run later after Step 8/9 SQL.
