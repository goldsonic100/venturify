-- Read-only verification for the social notification trigger cleanup.
-- Each table must have exactly one generic notification trigger and no
-- legacy venturify_notify_* trigger.
WITH expected(table_name, generic_trigger, legacy_trigger) AS (
  VALUES
    ('comments'::text, 'notify_on_new_comment'::text, 'venturify_notify_comment'::text),
    ('follows'::text, 'notify_on_new_follow'::text, 'venturify_notify_follow'::text),
    ('likes'::text, 'notify_on_new_like'::text, 'venturify_notify_like'::text)
)
SELECT
  e.table_name,
  EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname=e.table_name
      AND t.tgname=e.generic_trigger AND NOT t.tgisinternal AND t.tgenabled='O'
  ) AS generic_trigger_enabled,
  NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_trigger t
    JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname=e.table_name
      AND t.tgname=e.legacy_trigger AND NOT t.tgisinternal
  ) AS legacy_trigger_absent
FROM expected e
ORDER BY e.table_name;
