# Step 06 — Appointment integrity and schedule foundation

- Fixes hospital-owned chamber appointment validation by validating `products.doctor_id` and doctor/provider affiliation rather than `shops.owner_id = doctor_id`.
- Adds structured `appointment_start`, duration, schedules and exceptions without removing the legacy date/time columns.
- Prevents same-doctor/same-start double booking with a transaction advisory lock.
- Provider owners can view/manage appointments for their own chamber/hospital.
- Adds public-safe available-slot RPC. Existing free time input remains usable when no structured schedule exists.
