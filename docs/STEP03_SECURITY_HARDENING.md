# Step 03 — RLS / RPC / Storage Security Hardening

Key fixes:
- Removes the approved-doctor `profiles` SELECT policy that could expose entire private profile rows.
- Adds `list_approved_doctors_for_provider()` returning only `id` + `full_name` to authenticated providers/admins.
- Canonical public shop/product visibility validates both provider and doctor approval/account state.
- Verification history is owner/admin only and applicants can edit only pending rows.
- Ambulance public visibility is limited to verified rows.
- Public media writes are folder-owner scoped (`<auth.uid()>/...`).
- Verification/NID/BMDC buckets are private; only the applicant/admin can read and signed URLs are used by the frontend compatibility patch.

## Final release additions
- Blood-request updates are transition-guarded: the requester can cancel an active request, while the donor owns accept/decline/completion transitions.
- Verification evidence buckets are private; existing verification screens use short-lived signed URLs while database fields may retain legacy public URLs or new object paths.
