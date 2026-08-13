# Step 14 — Role-specific menus, settings and logout flow

- Doctor/Hospital dashboard hamburger menu now starts with:
  1. ব্যক্তিগত তথ্য
  2. চেম্বার
  3. ওয়েবসাইট
  followed by operational dashboard items and সেটিংস.
- Admin/Super Admin no longer see About/Terms/Privacy directly in the hamburger/menu; these are grouped under সেটিংস.
- Removed “মূল সাইটে ফিরুন” from Admin/Super Admin panel.
- Doctor/Hospital/Admin/Super Admin personal details open inside their own dashboard shell, not the visitor shell.
- The brand/logo link is role-aware: patient/guest → visitor home; doctor/hospital → provider dashboard; admin/super admin → admin panel.
- The root visitor home route is role-aware for logged-in staff roles, so opening `/` does not expose the visitor homepage to them.
- Logout now signs out and automatically redirects to the visitor homepage.
- Added a staff-only personal details page so Doctor/Admin/Super Admin do not see patient-only saved-doctor content.
- Added a shared Settings page that contains Help, About, FAQ, Feedback, Terms and Privacy links.
- No Supabase SQL changes are required for this step.

Build note: the provided environment has an invalid/missing Vite executable in node_modules, so a local Vite production build could not be executed here. Source-level changes were packaged.
