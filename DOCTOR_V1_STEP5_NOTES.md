# Doctor Platform V1 — Step 5

Implemented:
- Patient appointment request dialog from Doctor Details.
- Patient must be logged in with patient role.
- Appointment date/time/note.
- Appointment insert uses existing `public.appointments` RLS/triggers.
- Doctor appointment dashboard with pending/confirmed/completed/rejected actions.
- Patient appointment history route.
- Doctor dashboard navigation includes Appointment.
- Existing Step-2 appointment database schema is reused; no new destructive SQL required.

Test flow:
1. Login as Patient.
2. Open a verified Doctor profile.
3. Tap Appointment.
4. Select date and submit.
5. Login as Doctor.
6. Open Dashboard > Appointment.
7. Confirm/Reject.
8. Login as Patient and open `/appointments` to see status.
