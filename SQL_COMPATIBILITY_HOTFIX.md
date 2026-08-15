# SQL compatibility hotfix

The first release could fail on an existing Doctor V1 database with PostgreSQL error `42P13` because `CREATE OR REPLACE FUNCTION` attempted to rename the input parameter of `public.is_doctor_account_public(uuid)` from the historical `p_owner_id` to `p_doctor_id`. PostgreSQL does not permit changing input parameter names through `CREATE OR REPLACE`.

This release preserves the historical parameter name `p_owner_id`.

A second compatibility issue was also fixed proactively: `public.search_blood_donors(text,double precision,double precision,integer)` grows from 8 returned columns to 10. PostgreSQL cannot change a function TABLE return shape with `CREATE OR REPLACE`, so Step 16 now explicitly drops that RPC signature and recreates it before restoring grants.

Because the master migration is wrapped in `BEGIN ... COMMIT`, a failure before COMMIT should not leave the batch applied. Open a fresh SQL Editor query and rerun the corrected `supabase/production_upgrade/00_RUN_MEDICAL_FIRST10_ONCE.sql`.
