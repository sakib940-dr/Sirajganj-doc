# Step 13 — Role-specific dashboard isolation

- Doctor/Chamber-Hospital login -> provider dashboard.
- Admin login -> Admin dashboard.
- Super Admin login -> Super Admin-capable Admin dashboard.
- Patient login -> Patient dashboard.
- `/dashboard` rejects Admin/Super Admin/Patient and redirects to their own dashboard.
- `/admin` rejects Doctor/Hospital/Patient and redirects to their own dashboard.
- `/patient/dashboard` rejects non-patients and redirects to the correct dashboard.
- Login no longer honors a stale protected URL as the destination; it always resolves the authenticated DB role first.
- Added a simple Bangla Patient Dashboard.
