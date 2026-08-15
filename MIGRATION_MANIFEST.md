# Backend V10 migration manifest

Production execution entrypoint: `supabase/production_upgrade/00_RUN_BACKEND_V10_ONCE.sql`

Ordered embedded migrations:
1. `02_canonical_schema_convergence.sql`
2. `03_rls_rpc_security_hardening.sql`
3. `04_location_nearest_search.sql`
4. `05_doctor_provider_relationships.sql`
5. `06_appointment_schedule_integrity.sql`
6. `07_admin_audit_hardening.sql`
7. `08_performance_search.sql`
8. `09_data_consistency_services.sql`
9. `10_final_verification.sql`

Step 01 is a read-only audit and is intentionally not embedded in the mutating master transaction.
Historical SQL is reference material only for this release.
