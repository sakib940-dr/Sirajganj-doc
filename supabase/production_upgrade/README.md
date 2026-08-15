# Doctor V1 Backend V10 — production upgrade chain

This folder is the **only upgrade chain** to use for this backend repair release.
It is designed for the existing production database and intentionally does **not** replay the repository's overlapping historical SQL histories.

## Final production rule

After taking a database backup, run only:

`00_RUN_BACKEND_V10_ONCE.sql`

That file contains the exact current contents of Steps 02–10 inside one transaction. If a SQL statement fails, the transaction rolls back.

Do **not** additionally run:

- `doctor_v1_supabase_clean.sql`
- `supabase/migrations/*`
- historical `supabase/step*.sql`
- `step21_remove_demo_data.sql`

`01_preflight_audit.sql` is read-only and is retained as an optional diagnostic; it is not required when the final master runner is used.

## Step status

| Step | File | Final purpose | Status |
|---|---|---|---|
| 01 | `01_preflight_audit.sql` | Read-only production/schema preflight | Complete |
| 02 | `02_canonical_schema_convergence.sql` | Canonical additive schema + roles/helpers | Complete |
| 03 | `03_rls_rpc_security_hardening.sql` | RLS, role guards, private verification storage | Complete |
| 04 | `04_location_nearest_search.sql` | Server-side nearby Doctor/Ambulance + Blood Bank public-safe RPCs | Complete |
| 05 | `05_doctor_provider_relationships.sql` | Multi-provider Doctor affiliation model | Complete |
| 06 | `06_appointment_schedule_integrity.sql` | Appointment integrity, schedules, conflicts/slots | Complete |
| 07 | `07_admin_audit_hardening.sql` | Sensitive state audit trail | Complete |
| 08 | `08_performance_search.sql` | Indexes, catalog search, analytics RPC compatibility | Complete |
| 09 | `09_data_consistency_services.sql` | Safe backfills + privileged integrity summary | Complete |
| 10 | `10_final_verification.sql` | Structural release assertions/version marker | Complete |

## Frontend compatibility

The existing visual design and route pattern are retained. Frontend changes are limited to backend compatibility/functionality improvements such as signed verification-document previews, server-side location/search calls, normalized provider/appointment queries, and optional appointment slot selection.
