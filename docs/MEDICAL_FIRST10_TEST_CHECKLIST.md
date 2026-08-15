# Medical First 10 — Smoke Test Checklist

## Super Admin / location
- [ ] Login as a Patient, enable location, then refresh/re-login; saved location restores.
- [ ] Super Admin → Users shows last area and a Google Maps button for users with exact saved location.
- [ ] Google Maps opens the selected coordinates.
- [ ] Normal Admin cannot obtain exact all-user coordinates from the Super Admin RPC.

## Verification
- [ ] Pending Doctor first moves to Under Review, then can be approved/rejected.
- [ ] Pending Hospital first moves to Under Review, then can be approved/rejected.
- [ ] Rejected provider can resubmit a new pending verification; applicant cannot self-set approval/review status.
- [ ] Provider management page has no direct approve/reject bypass.

## Doctor affiliation
- [ ] Approved Hospital searches an approved Doctor and sends invitation.
- [ ] Doctor sees pending invitation and accepts/rejects it.
- [ ] Hospital cannot publish/schedule an unaccepted Doctor.
- [ ] Accepted Doctor appears in Hospital selectors.

## Schedule / appointment
- [ ] Doctor/Hospital saves weekly hours, slot duration and break.
- [ ] Add an unavailable exception date.
- [ ] Patient sees only generated available slots when a structured schedule exists.
- [ ] Break/unavailable/overlapping slot booking is rejected server-side.
- [ ] Patient can cancel active appointment with reason.
- [ ] Provider can confirm, reschedule, cancel, complete and mark no-show according to lifecycle.

## Blood donor / request
- [ ] Patient can become donor and later turn donor mode off.
- [ ] Available, Accept Requests and Public Phone behave independently.
- [ ] Public search hides private donor phone.
- [ ] Request requires requester profile phone and uses that server-side phone.
- [ ] Donor can accept/decline; accepted requester sees donor contact phone.
- [ ] Donor can mark donation complete; requester can cancel pending/accepted request.
- [ ] Duplicate active request to same donor within cooldown is blocked.

## Admin blood donor module
- [ ] Admin/Super Admin sees donor name, phone, address, blood group and status.
- [ ] Search and group/area/available filters work.
- [ ] Admin can toggle availability/request acceptance.
- [ ] Only Super Admin receives exact donor coordinates / Maps action.
- [ ] Blood Requests tab shows requester → donor with Admin-visible contact information and current status.

## Ambulance / analytics
- [ ] Public ambulance Call and Maps buttons still work.
- [ ] Admin dashboard uses real ambulance/donor counts.
- [ ] 7/30/90-day chart selector reloads data.
- [ ] Appointment status and blood-group charts render with empty-state safety.
