# Backend V10 deployment runbook

## Before deployment
1. Back up the production Supabase database.
2. Keep the currently working frontend deployment available for rollback.
3. Do **not** replay `doctor_v1_supabase_clean.sql`, `supabase/migrations/*`, or historical `supabase/step*.sql`.

## SQL — one run
Open Supabase SQL Editor and run **only**:

`supabase/production_upgrade/00_RUN_BACKEND_V10_ONCE.sql`

The file wraps Steps 02–10 in one transaction. If any statement fails, copy the exact error before retrying.

## Frontend deploy
After SQL succeeds, deploy this V10 project to GitHub/Vercel using the existing environment variables.

## Smoke tests
- Patient login/register/profile
- Doctor and hospital login + approved/pending boundary
- Hospital adds an approved Doctor to its chamber
- Public Doctor/chamber pages still hide unapproved entities
- GPS location and manual-area browsing
- Nearby ambulance sorting
- Patient appointment to Doctor-owned chamber
- Patient appointment to Hospital-owned Doctor
- Doctor appointment management
- Hospital appointment management
- Verification upload/reload/admin preview (private signed image)
- Admin approve/reject, account status/role controls
- Doctor directory search + pagination

## Post-deploy database check
As Admin, call `get_backend_integrity_summary()` and verify orphan/missing-affiliation counts. Existing historical anomalies are reported rather than silently deleted.
