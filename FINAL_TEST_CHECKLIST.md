# Backend V10 final smoke-test checklist

## SQL / release
- [ ] Full Supabase backup created before upgrade.
- [ ] Only `supabase/production_upgrade/00_RUN_BACKEND_V10_ONCE.sql` was run.
- [ ] SQL finished successfully (no historical migrations replayed).
- [ ] `select public.get_backend_schema_version();` returns `doctor-v1-backend-v10` for an authenticated privileged test session.
- [ ] Admin calls `get_backend_integrity_summary()` and records any historical anomalies for follow-up.

## Auth / roles / RLS
- [ ] Patient can read/update own profile but cannot change own role/provider/account status.
- [ ] Doctor/Hospital can submit verification but cannot self-approve.
- [ ] Admin can review provider status; only Super Admin can change protected role/account status.
- [ ] Anonymous visitor cannot directly read full `profiles` rows.
- [ ] Unapproved/inactive Doctor or provider is hidden from public Doctor/chamber results.

## Verification documents
- [ ] New verification photo/document upload succeeds.
- [ ] Page refresh still shows own private document via signed URL.
- [ ] Admin review can preview private verification evidence.
- [ ] Anonymous/public browser cannot open private verification object directly.

## Location / discovery
- [ ] Anonymous saved location restores after page reload.
- [ ] GPS permission success immediately loads nearby Doctors even if reverse geocoding fails.
- [ ] Manual district/upazila selection still works.
- [ ] GPS nearby results exclude rows without usable coordinates.
- [ ] Ambulances sort/filter by server-side distance when GPS is available.
- [ ] Blood donor directory still works and never exposes exact donor coordinates.

## Doctor / provider
- [ ] Doctor-owned chamber can publish its own Doctor profile.
- [ ] Hospital can select an approved Doctor and add the Doctor to its provider/chamber.
- [ ] Same Doctor can appear at multiple different providers.
- [ ] Same Doctor cannot be duplicated twice at the same provider.
- [ ] Provider dashboard counts load without legacy `owner/seller_id/hospital_id` query errors.

## Appointment
- [ ] Patient can create an appointment for a Doctor-owned chamber.
- [ ] Patient can create an appointment for a Hospital-owned Doctor.
- [ ] Patient identity is forced from `auth.uid()` server-side.
- [ ] Doctor/provider can confirm/cancel/complete allowed appointments.
- [ ] Patient cannot reschedule or alter Doctor note/identity fields through a crafted request.
- [ ] If structured schedules exist, available slots load and double booking is blocked.
- [ ] Existing free-form appointment time continues to work when no structured schedule is configured.

## Search / analytics
- [ ] Doctor directory query, synonyms, area filter, pagination and popular/latest sort work.
- [ ] Product/Doctor view and click counters still increment.
- [ ] Super Admin analytics dashboard still loads.

## Blood / ambulance
- [ ] Voluntary donor search works as anonymous visitor.
- [ ] Blood request creation works for logged-in patient.
- [ ] Donor can accept/decline a pending request; requester cannot forge donor transitions.
- [ ] Only verified ambulances are public; Admin can still manage all ambulance rows.

## Deploy
- [ ] Vercel/GitHub build succeeds with a clean dependency install.
- [ ] No console errors on Home, Doctor directory, Product/Doctor detail, Appointment, Provider dashboard, Admin and Blood/Ambulance pages.
