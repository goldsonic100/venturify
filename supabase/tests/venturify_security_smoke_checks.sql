-- Read-only Venturify security/regression smoke checks.
-- Run in Supabase SQL Editor after migrations. Every row should return passed = true.
WITH public_tables AS (
  SELECT c.relname, c.relrowsecurity
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind IN ('r','p')
),
checks AS (
  SELECT
    'all_public_tables_have_rls'::text AS check_name,
    NOT EXISTS (SELECT 1 FROM public_tables WHERE NOT relrowsecurity) AS passed,
    (SELECT count(*)::text FROM public_tables) || ' public tables inspected' AS detail
  UNION ALL
  SELECT
    'symmetric_pending_collaboration_index',
    EXISTS (
      SELECT 1 FROM pg_catalog.pg_indexes
      WHERE schemaname='public'
        AND indexname='collaboration_requests_one_pending_pair_symmetric_idx'
    ),
    'One pending request per founder pair, either direction'
  UNION ALL
  SELECT
    'no_duplicate_pending_collaboration_pairs',
    NOT EXISTS (
      SELECT 1
      FROM public.collaboration_requests
      WHERE status='pending'
      GROUP BY LEAST(requester_id, recipient_id), GREATEST(requester_id, recipient_id)
      HAVING count(*) > 1
    ),
    'No founder pair has multiple pending requests'
  UNION ALL
  SELECT
    'message_reactions_rls_enabled',
    COALESCE((
      SELECT c.relrowsecurity
      FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname='message_reactions' AND c.relkind IN ('r','p')
    ), false),
    'Message reactions table has row-level security enabled'
  UNION ALL
  SELECT
    'block_guards_for_messages',
    (
      SELECT count(*) = 2
      FROM pg_catalog.pg_policies
      WHERE schemaname='public'
        AND tablename='messages'
        AND permissive='RESTRICTIVE'
        AND policyname IN ('Block enforcement guard: messages select','Block enforcement guard: messages insert')
    ),
    'Restrictive read and insert block guards are present'
  UNION ALL
  SELECT
    'sensitive_rpc_not_executable_by_anon',
    NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public'
        AND p.proname = ANY (ARRAY[
          'get_or_create_direct_conversation',
          'create_group_conversation',
          'get_poll_results',
          'moderator_dashboard_overview',
          'moderator_list_recent_posts',
          'moderator_list_recent_posts_page',
          'moderator_list_reports',
          'moderator_list_reports_page',
          'moderator_list_users',
          'moderator_update_report'
        ])
        AND pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')
    ),
    'Sensitive RPCs are not executable by anon'

  UNION ALL
  SELECT
    'collaboration_acceptance_workspace_trigger_enabled',
    EXISTS (
      SELECT 1 FROM pg_catalog.pg_trigger t
      JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      JOIN pg_catalog.pg_proc p ON p.oid=t.tgfoid
      WHERE n.nspname='public' AND c.relname='collaboration_requests'
        AND t.tgname='collaboration_request_status_change' AND t.tgenabled='O'
        AND p.proname='handle_collaboration_request_status_change' AND NOT t.tgisinternal
    ),
    'Acceptance trigger for idempotent workspace creation is enabled'
  UNION ALL
  SELECT
    'free_community_membership_limit_guard_enabled',
    EXISTS (
      SELECT 1 FROM pg_catalog.pg_trigger t
      JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      JOIN pg_catalog.pg_proc p ON p.oid=t.tgfoid
      WHERE n.nspname='public' AND c.relname='community_members'
        AND t.tgname='enforce_free_community_membership_limit' AND t.tgenabled='O'
        AND p.proname='enforce_free_community_membership_limit' AND NOT t.tgisinternal
    ),
    'Free-plan community membership cap is enforced in the database'
  UNION ALL
  SELECT
    'daily_founder_match_limit_guards_enabled',
    (
      SELECT count(DISTINCT t.tgname)=2
      FROM pg_catalog.pg_trigger t
      JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      JOIN pg_catalog.pg_proc p ON p.oid=t.tgfoid
      WHERE n.nspname='public' AND c.relname='founder_match_impressions'
        AND t.tgname IN ('enforce_daily_founder_match_limit','verify_daily_founder_match_limit')
        AND t.tgenabled='O' AND p.proname IN ('enforce_daily_founder_match_limit','verify_daily_founder_match_limit')
        AND NOT t.tgisinternal
    ),
    'Daily founder-match limit has both enforcement and verification triggers'
  UNION ALL
  SELECT
    'public_security_definer_functions_pin_search_path',
    NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_proc p
      JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.prosecdef
        AND NOT EXISTS (
          SELECT 1
          FROM pg_catalog.unnest(COALESCE(p.proconfig, ARRAY[]::text[])) AS cfg(setting)
          WHERE cfg.setting LIKE 'search_path=%'
        )
    ),
    'Every public SECURITY DEFINER function pins its search_path'

  UNION ALL
  SELECT
    'workspace_created_notification_has_single_source',
    (
      NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public'
          AND p.proname='handle_collaboration_request_status_change'
          AND pg_catalog.strpos(pg_catalog.pg_get_functiondef(p.oid), 'workspace_created') > 0
      )
      AND EXISTS (
        SELECT 1
        FROM pg_catalog.pg_trigger t
        JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
        JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        JOIN pg_catalog.pg_proc p ON p.oid=t.tgfoid
        WHERE n.nspname='public'
          AND c.relname='collaboration_workspaces'
          AND t.tgname='notify_workspace_activity'
          AND t.tgenabled='O'
          AND p.proname='notify_workspace_activity'
          AND NOT t.tgisinternal
      )
    ),
    'Workspace-created notices are emitted only by the workspace activity trigger'

  UNION ALL
  SELECT
    'workspace_chat_has_single_notification_trigger',
    (
      EXISTS (
        SELECT 1
        FROM pg_catalog.pg_trigger t
        JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
        JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        JOIN pg_catalog.pg_proc p ON p.oid=t.tgfoid
        WHERE n.nspname='public'
          AND c.relname='workspace_messages'
          AND t.tgname='notify_project_chat_message'
          AND t.tgenabled='O'
          AND p.proname='notify_project_chat_message'
          AND NOT t.tgisinternal
      )
      AND NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_trigger t
        JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
        JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public'
          AND c.relname='workspace_messages'
          AND t.tgname='workspace_message_notifications'
          AND NOT t.tgisinternal
      )
    ),
    'Project chat has one notification trigger; duplicate legacy handler is absent'

  UNION ALL
  SELECT
    'account_settings_rls_and_owner_policies',
    (
      EXISTS (SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='account_settings' AND c.relrowsecurity)
      AND (SELECT count(*)=3 FROM pg_catalog.pg_policies p WHERE p.schemaname='public' AND p.tablename='account_settings' AND p.policyname IN ('Users can read their own account settings','Users can create their own account settings','Users can update their own account settings'))
    ),
    'Account preferences have RLS and owner-only read, create, and update policies'

  UNION ALL
  SELECT
    'private_profile_and_post_policies_respect_visibility',
    (
      EXISTS (SELECT 1 FROM pg_catalog.pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Profiles are visible by account privacy' AND cmd='SELECT')
      AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policies WHERE schemaname='public' AND tablename='profiles' AND policyname='Profiles are publicly readable')
      AND EXISTS (SELECT 1 FROM pg_catalog.pg_policies WHERE schemaname='public' AND tablename='posts' AND policyname='Posts respect account privacy' AND cmd='SELECT')
      AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_policies WHERE schemaname='public' AND tablename='posts' AND policyname='Posts are publicly readable')
      AND EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='private' AND p.proname='is_profile_public' AND p.prosecdef AND EXISTS (SELECT 1 FROM pg_catalog.unnest(COALESCE(p.proconfig, ARRAY[]::text[])) cfg(setting) WHERE cfg.setting LIKE 'search_path=%'))
    ),
    'Profile and post public-read policies honor private-account settings through a pinned SECURITY DEFINER helper'

  UNION ALL
  SELECT
    'messageable_founder_rpc_and_dm_preference_guard',
    (
      EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='get_messageable_founder_ids' AND p.prosecdef AND EXISTS (SELECT 1 FROM pg_catalog.unnest(COALESCE(p.proconfig, ARRAY[]::text[])) cfg(setting) WHERE cfg.setting LIKE 'search_path=%'))
      AND EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='get_discoverable_founder_ids' AND p.prosecdef AND EXISTS (SELECT 1 FROM pg_catalog.unnest(COALESCE(p.proconfig, ARRAY[]::text[])) cfg(setting) WHERE cfg.setting LIKE 'search_path=%'))
      AND EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='get_or_create_direct_conversation' AND pg_catalog.strpos(pg_catalog.pg_get_functiondef(p.oid), 'public_dms') > 0 AND pg_catalog.strpos(pg_catalog.pg_get_functiondef(p.oid), 'only accepts messages from people they follow') > 0)
    ),
    'Founder picker uses an allowlist RPC and the direct-conversation RPC enforces closed-DM preferences'

  UNION ALL
  SELECT
    'messaging_realtime_tables_published',
    (
      SELECT count(DISTINCT tablename)=3
      FROM pg_catalog.pg_publication_tables
      WHERE pubname='supabase_realtime'
        AND schemaname='public'
        AND tablename IN ('messages','message_reactions','message_reads')
    ),
    'Messages, reactions, and read receipts are published for the live chat subscriptions'

  UNION ALL
  SELECT
    'message_recipient_notification_trigger_enabled',
    EXISTS (
      SELECT 1
      FROM pg_catalog.pg_trigger t
      JOIN pg_catalog.pg_class c ON c.oid=t.tgrelid
      JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
      JOIN pg_catalog.pg_proc p ON p.oid=t.tgfoid
      WHERE n.nspname='public'
        AND c.relname='messages'
        AND t.tgname='venturify_notify_message'
        AND t.tgenabled='O'
        AND p.proname='venturify_notify_message'
        AND NOT t.tgisinternal
        AND pg_catalog.strpos(pg_catalog.pg_get_functiondef(p.oid), 'auth.uid() is distinct from new.sender_id') > 0
    ),
    'Message sends notify other conversation members only when the authenticated sender matches the message sender'
)
SELECT check_name, passed, detail
FROM checks
ORDER BY check_name;
