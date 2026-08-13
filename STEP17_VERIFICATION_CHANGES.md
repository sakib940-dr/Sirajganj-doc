# Step 17 — Verification Flow + Hospital Photos

- Pending Doctor/Hospital dashboard now shows a clear **ভেরিফিকেশন করুন** action that opens the verification form.
- Mobile hamburger menu now includes **ভেরিফিকেশন করুন** directly below Website for Doctor/Hospital accounts.
- Doctor verification is compact and organized into 3 sections.
- Doctor NID is NOT mandatory. BMDC is the primary verification method.
- Doctor form explains that only the front side of NID may be requested if BMDC online verification is not possible.
- Hospital verification supports one selected proof: BMDC, Trade License, or NID front.
- Hospital verification also uses a compact 3-section form.
- Hospital settings support up to 4 profile/building photos, each accepting up to 1 MB before automatic 100–200 KB compression.
- Hospital public page displays those photos prominently above the main profile content.
- Added `supabase/step17_verification_hospital_photos.sql` for new columns/policies.
- No `.env` file is included in this ZIP.
