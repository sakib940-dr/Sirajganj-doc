# Step 05 — Doctor/provider relationship stabilization

`products` and `shops` remain in place so the current frontend keeps working, while `doctor_provider_links` becomes the normalized affiliation source.

Key change: a doctor can now be listed at multiple hospitals/chambers. Only duplicate `(doctor_id, shop_id)` listings are prevented.
