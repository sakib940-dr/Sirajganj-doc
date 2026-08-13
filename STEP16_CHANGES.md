# Step 16 — Blood Bank + Ambulance + Mobile-first service foundation

## Added
- Blood Bank public directory.
- Patient voluntary blood donor profile: blood group, last donation date, volunteer toggle, public phone toggle.
- Public donor directory exposes only volunteers; phone appears only when the donor opts to publish it.
- Donor search can be filtered by 8 blood groups and sorted by current GPS distance when available.
- Blood request flow: requester selects a volunteer donor and sends date/time, reason, hospital and location.
- Blood requests appear in the patient's dashboard; if the patient is a volunteer donor, incoming requests also appear there with accept/decline actions.
- Request/phone actions are unavailable for non-volunteer donors; hidden phone does not disable in-app requests.
- Ambulance public directory with call and Google Maps direction actions.
- Super Admin/Admin ambulance management page.
- Compact home shortcuts for Blood Bank and Ambulance.
- Patient dashboard shortcuts for blood and ambulance services.
- Mobile menu shortcuts for public/patient users.
- Hospital/chamber role compatibility in the new migration, including hospital-owned chambers that can contain multiple doctor profiles while each doctor remains limited to one profile.

## SQL
Run later, once, on the same new Supabase project:
`supabase/step16_blood_ambulance.sql`

Do not rerun the older consolidated SQL files.

## Important privacy behavior
- A blood donor must explicitly enable voluntary donor mode before appearing in the public directory.
- A donor's phone is public only when `blood_public_phone=true`.
- Exact donor coordinates are never returned by the public donor RPC; only a calculated distance is returned.
- In-app blood requests can still be sent to an active volunteer even when phone sharing is disabled.
