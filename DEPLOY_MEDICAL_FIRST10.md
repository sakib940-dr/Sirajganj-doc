# Deploy — Medical Operations First 10

## Run order
1. Take a Supabase database backup.
2. In Supabase SQL Editor run **only** `supabase/production_upgrade/00_RUN_MEDICAL_FIRST10_ONCE.sql`.
3. Deploy the updated Edge Function: `supabase functions deploy admin-manage-user` (or deploy the same file from the Supabase Dashboard function editor).
4. Push this project to GitHub and let Vercel deploy the frontend.
5. Run `docs/MEDICAL_FIRST10_TEST_CHECKLIST.md`.

## Do not run
- `supabase/production_upgrade/history/00_RUN_BACKEND_V10_ONCE_DO_NOT_RUN.sql`
- `doctor_v1_supabase_clean.sql`
- old `supabase/migrations/*`
- old `step*.sql`
- `step21_remove_demo_data.sql`

The new master runner already includes the prior backend foundation (02–10) plus the medical first-10 continuation (11–20) in one transaction.
