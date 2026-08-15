# Step 08 — Performance and search

Adds trigram/text and high-value composite indexes, plus a public-safe paginated doctor catalog RPC. The directory keeps synonym expansion in the client, but shop lookup + product lookup + text/category filtering now runs as one server request.

## Final release additions
- Existing Product/Doctor view/click counter RPCs and the Super Admin analytics RPC are canonicalized so schema drift cannot break existing analytics screens after the upgrade.
