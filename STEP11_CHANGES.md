# Step 11 — Exact Location & Distance

- Auto GPS location remains available.
- Manual district/upazila selection remains available.
- Logged-in user's last exact GPS location is saved in `profiles` and reused.
- Guest users keep the location in the browser only; no personal location is written to Supabase.
- Chamber/Hospital can store exact latitude/longitude.
- Hospital/Chamber cards show a small exact distance when visitor GPS + chamber coordinates are available.
- Manual area selection deliberately does not show a fake distance.
- Added `distance_km()` SQL helper for future server-side sorting/filtering.
- Added a "বর্তমান অবস্থান ব্যবহার করুন" control to Chamber Settings.
