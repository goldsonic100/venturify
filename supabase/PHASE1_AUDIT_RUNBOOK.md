# Phase 1 production audit runbook

## Purpose
Use the read-only SQL report in `supabase/tests/phase1_readonly_audit.sql` to collect evidence about production RLS, SECURITY DEFINER function grants, storage policies, disabled triggers, and the migration ledger.

## Safety rules
- The audit SQL is read-only. It does not apply migrations, change grants, alter policies, or modify data.
- Run it in the intended Venturify Supabase project.
- Save/export the result sets before making changes.
- A SECURITY DEFINER warning is not automatically a vulnerability. Review the function body, caller requirements, effective EXECUTE grants, pinned search_path, and any trigger-only use before changing grants.
- Never remove EXECUTE from authenticated users without checking the frontend RPC calls and integration tests.
- Do not drop indexes solely because the advisor labels them unused.
- Do not rerun historical migrations to recreate missing SQL Editor tabs.

## Reconciliation workflow
1. Compare `supabase_migrations.schema_migrations` with the migration files in `supabase/migrations/`.
2. Treat filename/version differences as candidates for investigation, not proof of missing schema changes.
3. For each candidate, inspect the migration SQL and check its expected tables, columns, constraints, policies, functions, and triggers.
4. Mark a migration applied only when its effects are verified in the target project or its version is present in the migration ledger.
5. Record migrations applied manually outside the CLI ledger separately; do not fake ledger entries.

## Phase 1 exit criteria
- All public tables have appropriate RLS and reviewed policies.
- Storage buckets and object policies match intended public/private behavior.
- Every SECURITY DEFINER function has a documented caller model, pinned search_path where appropriate, and least-privilege EXECUTE grants.
- Sensitive RPCs cannot be invoked by anonymous users unless explicitly intended.
- Required triggers are enabled and duplicate legacy triggers are absent.
- Migration discrepancies have a documented resolution.
- Two-account tests cover private profiles, DMs, blocks, collaboration workspaces, and moderator access.
- Automated checks pass and the live site is smoke-tested.

## Known plan limitation
Leaked-password protection is not a Phase 1 blocker when the current Supabase plan does not include it. Track it as a plan limitation; do not ask the project owner to upgrade merely to close the checklist.
