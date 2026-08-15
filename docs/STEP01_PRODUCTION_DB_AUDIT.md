# Step 01 — Production Database Audit Foundation

## Scope

Frontend: **unchanged**.

This step does not attempt to guess the live Supabase schema. The repository is not connected to the production database in this workspace, so Step 01 creates a reliable audit foundation that can be run against production later, before the mutating Steps 02–10.

## What was added

- `supabase/production_upgrade/01_preflight_audit.sql` — read-only catalog/data-shape diagnostic.
- `supabase/production_upgrade/README.md` — canonical home for the upcoming 10-step upgrade chain.
- This audit report.

## Repository findings

### Critical — three competing schema histories

The repository contains:

- `supabase/migrations/0001_init.sql` through `0023_appointment_v1_ui_support.sql` (with no tracked `0003` migration file),
- standalone scripts such as `step8_upgrade.sql`, `step10_location.sql`, `step16_blood_ambulance.sql`, `step21_location_distance.sql`,
- a large consolidated `doctor_v1_supabase_clean.sql`.

These are not one deterministic migration history.

### Critical — `doctor_v1_supabase_clean.sql` is not a safe production upgrade source

The file contains multiple generations of the same functions/policies. Examples found in the repository scan:

- `prevent_self_role_change` defined many times,
- `request_seller_status` defined repeatedly,
- `is_super_admin` / `is_admin_or_above` redefined,
- public visibility and insert policies for `shops` / `products` re-created with different role assumptions.

This file should be treated as a historical/consolidated snapshot, not a file to re-run on an existing production DB.

### Critical — provider role behavior changed between scripts

`step8_upgrade.sql` and `step16_blood_ambulance.sql` allow provider ownership for:

- `doctor`
- `hospital`

But later sections of `doctor_v1_supabase_clean.sql` recreate some visibility/insert behavior with `role='doctor'` only.

The real production behavior therefore depends on which script was run last.

### High — duplicate policy/function definitions indicate drift risk

Repo-level scan found repeated definitions of major policies/functions. Repetition itself is not automatically wrong when using `DROP POLICY IF EXISTS` + recreate, but because definitions differ by generation, the repo cannot currently tell us the live production truth.

### High — destructive/non-schema helper file lives beside migrations

`supabase/step21_remove_demo_data.sql` deletes demo data. It must never be included automatically in the new production upgrade chain.

### Medium — stale documentation

The root README still mixes marketplace-era guidance (`visitor`, `seller`, `shop`, `product`) with the converted doctor platform model. It also references a `0003_seed_demo_data.sql` that is not present in the uploaded repository.

Documentation cleanup will be handled after the schema is stabilized; changing README wording is not required for Step 01.

## What the preflight SQL reports

When finally run against production, Step 01 reports:

1. Presence/missing state of core tables.
2. RLS enabled/disabled state.
3. Presence of critical columns used by the current frontend/domain.
4. SECURITY DEFINER vs SECURITY INVOKER posture of critical functions, including configured `search_path`.
5. Current RLS policies for sensitive tables.
6. Current triggers on profiles/provider/appointment domain tables.
7. Current `profiles` role/status distribution, useful for detecting old `visitor`/`seller` values before conversion migrations.

It intentionally does **not** create/drop/alter persistent objects.

## Step 02 handoff

Step 02 should create the canonical migration/convergence layer. It should:

- normalize role constraints without destroying valid production rows,
- converge provider/hospital/doctor RLS policies to one definition,
- make final function/policy definitions explicit and idempotent,
- avoid replaying the historical migration files,
- preserve frontend behavior.
