# Step 04 — Location and nearest search

- Adds server-side distance helper and public-safe nearest doctor/ambulance RPCs.
- Removes the browser N+1-style location fetch (shops → products → client sort) for nearby listings.
- GPS coordinates can drive results even when reverse geocoding fails.
- Anonymous visitors restore `doctor_v1_last_location` from localStorage.
- Reverse geocoding remains best-effort enrichment only; it no longer blocks nearest results.

## Final release additions
- GPS-scoped nearby queries exclude Doctor/provider/Ambulance rows that do not have usable coordinates instead of presenting unknown-location rows as nearby.
- Existing Blood Bank RPCs are canonicalized in this step so public donor search remains privacy-safe and exact donor coordinates are never returned.
