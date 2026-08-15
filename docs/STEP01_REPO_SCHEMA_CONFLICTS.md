# Step 01 — Repository Schema Conflict Map

This is a repo-level scan. It does **not** claim which definition is live in production; Step 01's preflight SQL is designed to reveal that later.

## Migration sources found

- Incremental chain: `supabase/migrations/0001_init.sql` ... `0023_appointment_v1_ui_support.sql`
- Standalone upgrades: `step8`, `step9`, `step10`, `step11`, `step16`, `step17`, `step19`, `step20`, `step21`
- Consolidated snapshot: `supabase/doctor_v1_supabase_clean.sql`
- Destructive helper: `supabase/step21_remove_demo_data.sql`

## High-risk overlapping definitions

| Object | Overlap observed | Risk |
|---|---|---|
| `prevent_self_role_change()` | many definitions across migrations and clean snapshot | Final behavior depends on last script run |
| `request_seller_status()` | multiple marketplace and doctor-era definitions | Old role semantics can reappear |
| `is_super_admin()` / `is_admin_or_above()` | repeated definitions | Privilege behavior can drift |
| `is_doctor_account_public()` | step8, step16, clean snapshot | `doctor` vs `doctor/hospital` behavior differs |
| `shops` public/insert policies | several generations | Hospital provider visibility/creation can regress |
| `products` public/insert policies | several generations | Hospital-owned doctor/chamber content can regress |
| `seller_verifications` policies | repeated | Verification write/read scope depends on final version |
| Storage policies | marketplace + provider rewrites | Some later policies are broad authenticated bucket writes |

## Concrete role conflict

`step8_upgrade.sql` and `step16_blood_ambulance.sql` intentionally recognize both:

```text
doctor, hospital
```

as provider roles for shop/chamber ownership.

Later parts of `doctor_v1_supabase_clean.sql` contain policies/helpers that use `role='doctor'` only. Re-running that snapshot after the provider upgrades can therefore remove hospital behavior.

## Security item queued for Step 03

`step20_profile_storage_rls_fix.sql` contains provider storage policies that allow any authenticated user to insert/update/delete in provider buckets based only on bucket id. This should be tightened to owner-path checks in the security pass rather than silently changed in Step 01.

## Location item queued for Step 04

Current exact visitor coordinates are stored in `profiles.location_latitude/location_longitude`; provider coordinates are stored on `shops.latitude/longitude`. Existing location search is substantially client-side and will be normalized in the location/performance steps without changing the current frontend UX.

## Files excluded from the future canonical runner

The final Step-10 runner must **not** replay these historical files automatically:

- `doctor_v1_supabase_clean.sql`
- legacy `migrations/0001...0023`
- legacy `step*.sql`
- `step21_remove_demo_data.sql`

They remain in the repo as history/reference. The new production upgrade lives only under `supabase/production_upgrade/`.
