# Step 12 — Doctor Card + Section Listing

- Homepage doctor cards are now wider horizontal cards on mobile, with the profile photo on the left and name/degree/specialty/designation clearly visible on the right.
- Secondary card text is intentionally smaller to keep the card compact and readable.
- Homepage horizontal doctor rows show a maximum of 10 cards and remain touch-scrollable.
- Every major homepage section now exposes a **সব দেখুন** action when content exists, including categories, location doctors, popular doctors, chambers and latest doctors.
- Added a dedicated `/doctors` directory page.
- Directory page shows doctors as a vertical list, 20 per page, with **আগের পাতা / পরের পাতা** pagination when more results exist.
- Directory supports district/upazila filters and popular/latest sections.
- Existing public search remains available.
- No new Supabase SQL is required for this UI/listing change.
