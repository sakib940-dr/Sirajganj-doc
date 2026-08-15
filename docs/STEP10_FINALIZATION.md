# Step 10 — Finalization

The final SQL validates the protected schema/RPC contract and records `doctor-v1-backend-v10` only after Steps 02–09 have succeeded.

The delivery includes `00_RUN_BACKEND_V10_ONCE.sql`, a transaction-wrapped concatenation of Steps 02–10. This is the file intended for the Supabase SQL Editor after taking a database backup.
