# Step 09 — Service layer and data consistency

Frontend appearance is unchanged. Core Supabase access for discovery, appointments and provider-dashboard summaries now sits in `src/services/`, which reduces page-level schema coupling.

Functional fixes included:
- Hospital dashboard approval check now recognizes approved hospital accounts.
- Removed legacy/non-existent `owner`, `seller_id`, and `hospital_id` filters.
- Hospital appointments are scoped by the hospital-owned shop and are allowed by Step 06 RLS.
- Product doctor chooser uses the safe provider RPC instead of reading private profiles.
- Re-runnable link/appointment backfills plus an admin integrity-summary RPC.
