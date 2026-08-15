# Regression Fix 21

এই hotfixটি Medical First-10 deploy-এর পর দেখা regressionগুলো restore করে।

## Fixed
- পুরোনো Doctor profile visibility/backfill
- Chamber/Hospital core public profile `website enabled` toggle-এর কারণে আর block হবে না
- GPS permission প্রতি browser session-এ auto-request হবে (browser permission `denied` না থাকলে)
- Sirajganj district reverse-geocode-কে ভুল করে Sirajganj Sadar ধরার alias bug fixed
- Patient Dashboard-এ GPS/district/upazila অনুযায়ী Doctor list
- Location RPC fail করলে legacy district/upazila query fallback
- Super Admin missing/disabled bootstrap recovery
- Login/profile bootstrap now uses own-profile RPC with frontend fallback

## Already applied Medical First-10 DB
Run only:
`supabase/production_upgrade/00_RUN_REGRESSION_HOTFIX21_ONCE.sql`

Then deploy the updated frontend. Do not rerun the older full master on the same production database.

## Browser note
If a visitor previously selected “Block” for location, browsers do not allow a website to silently reopen the permission prompt. The user must change the site location permission back to Ask/Allow once; after that the app auto-requests once per browser session.
