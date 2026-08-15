# Medical Operations — First 10 Change Report

## 1. Super Admin last location
- Consented exact coordinates moved to `user_last_locations`.
- Signed-in user can save/read own last location.
- Super Admin Users page shows last area, update time, source/accuracy and Google Maps action.
- Regular Admin cannot retrieve all-user exact coordinates.
- No background tracking is introduced: a row exists only after the user previously consented to GPS or selected an area.

## 2. Unified provider verification
- Doctor/Hospital approval is routed through `review_provider_verification`.
- Canonical lifecycle is `pending → under_review → approved/rejected`; rejected providers resubmit as a new pending application.
- Applicant inserts are server-normalized to `pending` and applicants cannot forge status/admin review notes.
- Direct profile provider-status approval path is guarded.
- Verification decision synchronizes provider status.

## 3. Hospital ↔ Doctor affiliation
- Hospital sends invitation; Doctor accepts/rejects.
- Accepted affiliation is required before a Hospital can publish that Doctor or manage that Doctor's schedule.
- Deactivated/rejected affiliation is not publicly usable.

## 4. Structured schedule
- Weekly hours, slot duration, break period and unavailable-date exceptions.
- Atomic day save RPC.
- Public available-slot RPC excludes breaks, exceptions and overlapping active bookings.

## 5. Appointment lifecycle
- Pending/confirmed/rescheduled/completed/cancelled/no-show lifecycle.
- Patient cancellation reason; provider reschedule/cancel/complete/no-show actions.
- Appointment history + notification foundation.
- Server-owned time/duration normalization, structured-slot enforcement and overlap-safe advisory locking.

## 6. Blood donor profile
- Donor can turn donor mode off again.
- Availability, accepting requests and public phone are separate preferences.
- Blood address and donor update time supported.
- Future donation date rejected; request acceptance requires a profile phone.

## 7. Admin/Super Admin blood donor directory
- Separate admin module with donor name, phone, address, group, last donation, availability and request/public-phone state.
- Search/group/district/upazila/available filters.
- Admin moderation; exact donor map location only appears for Super Admin.

## 8. Blood request lifecycle
- Requester identity/phone comes from authenticated profile, not client parameters.
- Duplicate active request cooldown.
- Donor accept/decline/complete; requester cancel.
- Private donor phone stays out of public search but is shared with the requester after donor acceptance.
- Notifications and server-managed request numbers/status timestamps.
- Admin/Super Admin request monitor joins requester + donor names/phones; lifecycle transitions are audit-logged without copying request PII into audit metadata.

## 9. Ambulance operations
- Uses canonical `ambulance_services` table.
- Call and Google Maps direction click counters added.
- Existing public call/maps flow remains functional.

## 10. Modern Admin dashboard
- 7/30/90-day medical operations analytics.
- Medical stat cards, growth chart, appointment status chart and active-donor blood-group chart.
- Correct donor/ambulance counts and Super Admin saved-location count.

## Compatibility fixes included
- `admin-manage-user` Edge Function recognizes canonical Doctor/Hospital roles (legacy seller still accepted).
- Existing visual component/layout patterns were retained.
- Historical SQL files remain for history only; the new master runner is the deployment source of truth for this release.
