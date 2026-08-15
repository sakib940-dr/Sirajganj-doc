# Medical First 10 — Release Validation

## Automated checks
- Canonical master runner contains exact migrations 02–20 in order: PASS
- Master transaction boundary (`BEGIN` / `COMMIT`) check: PASS
- SQL lexical / quotes / dollar-body / parenthesis scan: PASS
- `SECURITY DEFINER` functions missing `SET search_path=public`: 0
- Self-referential RLS policy recursion in canonical migrations: 0
- Destructive/demo-data SQL in final master: 0
- Frontend/Edge Function JS/JSX/TS/TSX parser check: 159 files, 0 syntax failures
- Missing local imports: 0
- Frontend RPC calls without a canonical SQL function definition: 0 (28 calls checked)
- Active frontend references to legacy wrong `ambulances` / `blood_donors` tables: 0
- Active direct frontend `seller_status` update path: 0
- ZIP release excludes `node_modules` and VCS/cache folders.

## Master SQL
Run only:
`supabase/production_upgrade/00_RUN_MEDICAL_FIRST10_ONCE.sql`

Master SQL SHA-256 at validation time:
`54656098511cbcfd92de03d72cafab9622bb3d59f623ebeef28bf5d9c8aeb8c7`

## Build-environment note
A full Vite build could not be completed in this container because the local dependency installation was incomplete (`vite` binary unavailable), and a clean `npm ci` attempt failed in the container environment. This release therefore relies on successful source parser/import/RPC/SQL static gates above; Vercel should perform the clean dependency install/build during deployment.

## Deployment note
The updated `supabase/functions/admin-manage-user/index.ts` is a Supabase Edge Function and must be deployed separately from the Vercel frontend.
