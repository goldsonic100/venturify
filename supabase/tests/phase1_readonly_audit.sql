-- Venturify Phase 1: read-only production audit.
-- Safe to run in Supabase SQL Editor. This script makes no schema or data changes.
-- Review every result; findings are evidence for follow-up, not automatic fixes.

-- 1) Public tables and RLS status.
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced,
  CASE WHEN c.relrowsecurity THEN 'review policies below' ELSE 'ACTION: RLS is disabled' END AS finding
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p')
ORDER BY c.relname;

-- 2) SECURITY DEFINER functions: effective EXECUTE access and pinned search_path.
-- PUBLIC execute is checked via ACL expansion (not only has_function_privilege).
SELECT
  p.oid::regprocedure::text AS function_signature,
  pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_execute,
  pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute,
  EXISTS (
    SELECT 1
    FROM pg_catalog.aclexplode(COALESCE(p.proacl, pg_catalog.acldefault('f', p.proowner))) acl
    WHERE acl.grantee = 0 AND acl.privilege_type = 'EXECUTE'
  ) AS public_role_has_execute,
  EXISTS (
    SELECT 1 FROM pg_catalog.unnest(COALESCE(p.proconfig, ARRAY[]::text[])) cfg(setting)
    WHERE cfg.setting LIKE 'search_path=%'
  ) AS search_path_is_pinned,
  CASE
    WHEN EXISTS (
      SELECT 1 FROM pg_catalog.aclexplode(COALESCE(p.proacl, pg_catalog.acldefault('f', p.proowner))) acl
      WHERE acl.grantee = 0 AND acl.privilege_type = 'EXECUTE'
    ) THEN 'REVIEW: PUBLIC has EXECUTE'
    WHEN pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE') THEN 'REVIEW: anon has EXECUTE'
    WHEN NOT EXISTS (
      SELECT 1 FROM pg_catalog.unnest(COALESCE(p.proconfig, ARRAY[]::text[])) cfg(setting)
      WHERE cfg.setting LIKE 'search_path=%'
    ) THEN 'REVIEW: search_path is not pinned'
    ELSE 'No automatic flag from these checks; inspect function body and intended callers'
  END AS review_status,
  pg_catalog.pg_get_functiondef(p.oid) AS function_definition
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosecdef
ORDER BY p.oid::regprocedure::text;

-- 3) Policies on public tables: permissive/restrictive behavior and expressions.
SELECT
  schemaname, tablename, policyname, permissive, roles, cmd,
  qual AS using_expression, with_check
FROM pg_catalog.pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 4) Storage buckets and object policies (if Storage is enabled).
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
ORDER BY name;

SELECT schemaname, tablename, policyname, permissive, roles, cmd,
       qual AS using_expression, with_check
FROM pg_catalog.pg_policies
WHERE schemaname = 'storage'
ORDER BY tablename, policyname;

-- 5) Disabled user triggers in public schema.
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  t.tgname AS trigger_name,
  t.tgenabled AS enabled_state,
  p.oid::regprocedure::text AS trigger_function
FROM pg_catalog.pg_trigger t
JOIN pg_catalog.pg_class c ON c.oid = t.tgrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
JOIN pg_catalog.pg_proc p ON p.oid = t.tgfoid
WHERE n.nspname = 'public'
  AND NOT t.tgisinternal
  AND t.tgenabled <> 'O'
ORDER BY c.relname, t.tgname;

-- 6) Migration ledger currently recorded by Supabase CLI.
-- This is intentionally separate from repository filenames: version history
-- alone does not prove every expected schema effect is present.
SELECT version, name
FROM supabase_migrations.schema_migrations
ORDER BY version;
