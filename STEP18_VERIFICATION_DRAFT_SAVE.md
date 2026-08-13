# Step 18 — Verification form draft/section saving

- Each verification section can be saved independently.
- Section 1: personal/institution information.
- Section 2: professional/verification proof.
- Section 3: chamber/hospital information.
- Server persistence uses the existing `seller_verifications` table; no new SQL is required.
- Form fields are also cached in localStorage as a draft while typing, so accidental refresh does not immediately erase unsaved input.
- Existing pending applications are updated; rejected applications can start a new application; approved applications remain locked.
- No `.env` file is included.
