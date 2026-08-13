# Step 9 — Web Builder + Bangla Directions

- Added a simple chamber/hospital Website Builder.
- Added persistent `shops.website_config` JSONB via `supabase/step9_website_builder.sql`.
- Added Bangla search examples relevant to Sirajganj/medical search.
- Added Bangla `দিকনির্দেশনা` button on chamber and doctor detail pages.
- Direction falls back to a Google Maps directions URL generated from the chamber address when no map link is supplied.
- Added Website Builder navigation to Doctor/Chamber dashboard.
- Public chamber page now respects website enabled/disabled and builder section toggles.
