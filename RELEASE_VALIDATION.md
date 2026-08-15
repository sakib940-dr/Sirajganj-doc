# Backend V10 release validation

## Final master SQL
- File: `supabase/production_upgrade/00_RUN_BACKEND_V10_ONCE.sql`
- SHA-256: `0743a4f76896f5d0976506348c322b6300bcfa5dc34734dc6dce45f5f75e5387`
- Contains the exact current contents of Steps 02–10.
- One transaction: `BEGIN` → Steps 02–10 → `COMMIT`.
- Historical migrations/clean snapshot/demo-delete scripts are not embedded.

## Static checks completed
- All production-upgrade SQL files: string/comment/dollar-quote state closed and parenthesis balance = 0.
- Frontend/source RPC calls checked against final backend contract.
- 150 JS/JSX/TS/TSX source files parsed with the TypeScript parser: 0 syntax failures.
- `@/` alias import resolution: 0 missing local files.
- Changed non-JSX files pass `node --check`.
- Legacy broken seller dashboard query fields (`owner`, `seller_id`, `hospital_id`) are absent from active seller hooks/services/pages.
- Private verification buckets are not accessed with `getPublicUrl` by the new frontend path.

## Runtime-build limitation in this workspace
The uploaded/generated working package does not contain a usable dependency installation (its `node_modules` is only placeholder directories), and the execution environment could not complete a fresh npm registry install. Therefore a full Vite production bundle could not be executed locally. The final ZIP intentionally excludes `node_modules`; GitHub/Vercel should perform a clean dependency install from `package-lock.json`.

This limitation does not replace the post-deploy smoke tests in `FINAL_TEST_CHECKLIST.md`.
