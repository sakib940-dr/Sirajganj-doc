# Step 02 — Canonical Schema Convergence

Frontend contract is preserved. This migration does not replay the historical SQL files.

Key outcomes:
- Legacy `visitor` -> `patient`, legacy `seller` -> `doctor` only when those legacy values still exist.
- Canonical roles: patient, doctor, hospital, admin, super_admin.
- Modern profile/provider/product/verification/location fields are additive and idempotent.
- Doctor + Hospital are both canonical provider roles.
- Verification history keeps multiple applications by removing the old `UNIQUE(user_id)` constraint.
- Baseline appointments/blood/ambulance objects are created only if an older production deployment skipped them.
- Canonical security-definer boolean helpers are defined once with fixed `search_path` and explicit grants.

No valid modern rows are deleted.
