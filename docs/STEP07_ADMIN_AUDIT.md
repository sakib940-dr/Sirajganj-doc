# Step 07 — Admin/audit hardening

Sensitive state transitions are now recorded centrally in `admin_audit_logs` without copying NID/document URLs or other private verification payloads. Existing admin UI mutations continue to work; database triggers create the audit entries automatically.
