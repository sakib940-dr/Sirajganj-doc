# Step 19 — Unified Profile Center

- Doctor/Hospital personal info, chamber/hospital info, and verification are now one combined provider profile center.
- Each section has its own Save button.
- Personal/chamber/proof drafts persist locally so refreshes do not erase in-progress fields.
- Uploaded images remain referenced in the form and are saved when that section is saved.
- Repeated name/phone/address fields were removed from the verification section.
- Phone visibility is explicit before saving.
- Empty fields use Bangla, light placeholder examples.
- Old personal/chamber/verification provider routes redirect to the combined center.
- Added idempotent SQL migration for phone visibility flags.
