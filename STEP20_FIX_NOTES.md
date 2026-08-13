# Step 20 — Profile Center Error Fix

Fixed:
1. profiles.address missing -> migration adds it.
2. Hospital photo bucket not found -> use existing `shop-gallery`, create/repair it and policies.
3. shops insert RLS blocked pending doctors/hospitals -> provider profile/chamber can now be saved while account is active, even before verification approval.
4. Added missing unified verification columns.
5. Kept `.env` out of the ZIP.

Run only `supabase/step20_profile_storage_rls_fix.sql` on the existing Supabase project.
