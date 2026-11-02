# Supabase migration inventory

This file is an inventory of SQL migration files committed to `supabase/migrations/` on `main`. It is **not** proof that any migration has been applied to the production Supabase project.

## How to use this checklist

- Check a migration only after confirming it has been applied successfully to the intended Supabase project.
- Do not blindly rerun migrations to recover missing SQL Editor tabs.
- Before applying an older migration, inspect whether its changes already exist and whether it is safe to run again.
- Keep the original migration files in GitHub as the source of truth.

**Production application status:** Unverified from this repository inventory. Update the status only after checking Supabase's migration history or database objects.

**Files found:** 95

## Foundation, profiles, communities, discovery, and notifications

- [ ] `20261013000000_add_venturify_notification_triggers.sql` — application status not yet verified
- [ ] `20261013010000_add_communities_and_memberships.sql` — application status not yet verified
- [ ] `20261013020000_require_membership_for_community_posts.sql` — application status not yet verified
- [ ] `20261013030000_expand_venturify_founder_profiles.sql` — application status not yet verified
- [ ] `20261013060000_limit_free_founder_matches_to_six_daily.sql` — application status not yet verified
- [ ] `20261013061000_verify_daily_match_statement_limit.sql` — application status not yet verified
- [ ] `20261018_profile_username_cooldown.sql` — application status not yet verified
- [ ] `20261022180000_revoke_anon_founder_rpc_access.sql` — application status not yet verified
- [ ] `20261023211000_enforce_discover_founder_eligibility.sql` — application status not yet verified
- [ ] `20261023212000_preserve_public_eligible_founder_discovery.sql` — application status not yet verified
- [ ] `20261024220112_public_profile_email_verification.sql` — application status not yet verified
- [ ] `20261024223000_revoke_anon_discoverable_founder_rpc.sql` — application status not yet verified
- [ ] `20261027160000_backfill_missing_profile_usernames.sql` — application status not yet verified
- [ ] `20261029170000_create_profile_for_auth_user.sql` — application status not yet verified

## Messaging and conversation security

- [ ] `20261013050000_enable_message_realtime.sql` — application status not yet verified
- [ ] `20261014000000_messaging_read_receipts_and_typing.sql` — application status not yet verified
- [ ] `20261015020000_harden_direct_message_access.sql` — application status not yet verified
- [ ] `20261015030000_add_complete_unread_message_counts.sql` — application status not yet verified
- [ ] `20261016000000_revoke_anon_access_to_message_metadata.sql` — application status not yet verified
- [ ] `20261019030000_harden_blocked_conversation_metadata.sql` — application status not yet verified
- [ ] `20261020020000_add_message_reactions.sql` — application status not yet verified
- [ ] `20261020153110_restrict_message_reaction_grants.sql` — application status not yet verified
- [ ] `20261020200000_group_conversations_and_message_notifications.sql` — application status not yet verified
- [ ] `20261022120000_add_account_settings_and_message_privacy.sql` — application status not yet verified
- [ ] `20261022190000_message_delivery_notifications.sql` — application status not yet verified
- [ ] `20261022191000_index_notification_conversation.sql` — application status not yet verified
- [ ] `20261023200000_messaging_restrictive_block_policies.sql` — application status not yet verified
- [ ] `20261023210000_remove_duplicate_legacy_message_notifications.sql` — application status not yet verified
- [ ] `20261024215204_fix_private_dm_follow_direction.sql` — application status not yet verified
- [ ] `20261024224000_harden_poll_and_group_rpc_authorization.sql` — application status not yet verified

## Trust, safety, and moderation

- [ ] `20261016000000_add_trust_safety_foundation.sql` — application status not yet verified
- [ ] `20261017000000_enforce_user_blocks.sql` — application status not yet verified
- [ ] `20261018150000_add_moderator_review_workflow.sql` — application status not yet verified
- [ ] `20261018160000_add_moderator_dashboard.sql` — application status not yet verified
- [ ] `20261018170000_paginate_moderator_reports.sql` — application status not yet verified
- [ ] `20261018180000_paginate_moderator_posts.sql` — application status not yet verified
- [ ] `20261019030000_harden_blocked_conversation_metadata.sql` — application status not yet verified
- [ ] `20261019040000_fix_blocked_read_receipt_insert.sql` — application status not yet verified
- [ ] `20261020153000_enforce_block_restrictions.sql` — application status not yet verified
- [ ] `20261020173915_deny_direct_moderator_table_access.sql` — application status not yet verified
- [ ] `20261020180430_fix_workspace_task_delete_and_blocked_requests.sql` — application status not yet verified

## Collaboration workspaces, tasks, files, and activity

- [ ] `20261016010000_create_collaboration_requests.sql` — application status not yet verified
- [ ] `20261016020000_create_collaboration_workspaces_and_tasks.sql` — application status not yet verified
- [ ] `20261016025000_add_collaboration_activity_notifications.sql` — application status not yet verified
- [ ] `20261016030000_add_workspace_context_to_notifications.sql` — application status not yet verified
- [ ] `20261016040000_add_private_workspace_chat.sql` — application status not yet verified
- [ ] `20261016050000_add_private_workspace_file_storage.sql` — application status not yet verified
- [ ] `20261016204100_add_workspace_task_due_dates.sql` — application status not yet verified
- [ ] `20261016210000_workspace_deadline_notifications.sql` — application status not yet verified
- [ ] `20261016212000_index_notification_task_id.sql` — application status not yet verified
- [ ] `20261016223000_task_assignment_update_notifications.sql` — application status not yet verified
- [ ] `20261019050000_validate_workspace_task_assignees.sql` — application status not yet verified
- [ ] `20261020010000_guard_workspace_identity_updates.sql` — application status not yet verified
- [ ] `20261020175822_auto_create_workspaces_on_collaboration_acceptance.sql` — application status not yet verified
- [ ] `20261020180333_deduplicate_collaboration_outcome_notifications.sql` — application status not yet verified
- [ ] `20261020180430_fix_workspace_task_delete_and_blocked_requests.sql` — application status not yet verified
- [ ] `20261020213000_add_workspace_milestones.sql` — application status not yet verified
- [ ] `20261020230000_add_workspace_activity_timeline.sql` — application status not yet verified
- [ ] `20261020232922_collaboration_task_notifications.sql` — application status not yet verified
- [ ] `20261020240000_workspace_notifications.sql` — application status not yet verified
- [ ] `20261020250000_workspace_task_comments.sql` — application status not yet verified
- [ ] `20261020260000_realtime_task_comments.sql` — application status not yet verified
- [ ] `20261020270000_task_comment_notifications.sql` — application status not yet verified
- [ ] `20261020280000_workspace_task_priority_labels.sql` — application status not yet verified
- [ ] `20261020290000_workspace_task_checklists.sql` — application status not yet verified
- [ ] `20261020300000_checklist_item_integrity.sql` — application status not yet verified
- [ ] `20261021012647_consolidate_workspace_notifications.sql` — application status not yet verified
- [ ] `20261021075200_optimize_workspace_activity_rls.sql` — application status not yet verified
- [ ] `20261021115153_optimize_workspace_activity_rls.sql` — application status not yet verified
- [ ] `20261021120351_prevent_reverse_pending_collaboration_duplicates.sql` — application status not yet verified
- [ ] `20261021122729_deduplicate_workspace_created_notifications.sql` — application status not yet verified
- [ ] `20261021160000_remove_duplicate_workspace_message_notification_trigger.sql` — application status not yet verified
- [ ] `20261021180000_task_comment_integrity.sql` — application status not yet verified
- [ ] `20261021190000_restrict_checklist_item_updates.sql` — application status not yet verified
- [ ] `20261023110000_private_workspace_presence.sql` — application status not yet verified
- [ ] `20261023213000_limit_collaboration_request_update_columns.sql` — application status not yet verified
- [ ] `20261023214000_limit_collaboration_workspace_update_columns.sql` — application status not yet verified
- [ ] `20261023220000_tighten_workspace_task_comment_edit_policy.sql` — application status not yet verified
- [ ] `20261023221000_allow_authorized_workspace_file_replacements.sql` — application status not yet verified
- [ ] `20261023222000_limit_workspace_milestone_update_columns.sql` — application status not yet verified
- [ ] `20261023223000_limit_workspace_task_update_columns.sql` — application status not yet verified
- [ ] `20261023224000_limit_workspace_checklist_update_columns.sql` — application status not yet verified
- [ ] `20261023225000_limit_workspace_comment_update_columns.sql` — application status not yet verified
- [ ] `20261023230000_limit_workspace_message_insert_columns.sql` — application status not yet verified
- [ ] `20261023231000_restrict_workspace_activity_event_writes.sql` — application status not yet verified

## Account settings and privacy

- [ ] `20261022120000_add_account_settings_and_message_privacy.sql` — application status not yet verified
- [ ] `20261022140000_enforce_account_feature_preferences.sql` — application status not yet verified
- [ ] `20261030184616_tighten_account_settings_access.sql` — application status not yet verified

## Other / additional migrations

- [ ] `20261015000000_tighten_function_execute_grants.sql` — application status not yet verified
- [ ] `20261015010000_enforce_free_community_membership_limit.sql` — application status not yet verified
- [ ] `20261019020000_fix_poll_vote_option_integrity.sql` — application status not yet verified
- [ ] `20261020174108_unified_venture_opportunities.sql` — application status not yet verified
- [ ] `20261020320000_notification_feed_indexes.sql` — application status not yet verified
- [ ] `20261021074500_add_missing_foreign_key_indexes.sql` — application status not yet verified
- [ ] `20261021074800_optimize_auth_rls_initplan_policies.sql` — application status not yet verified
- [ ] `20261021114604_add_missing_foreign_key_indexes.sql` — application status not yet verified
- [ ] `20261021114945_optimize_auth_rls_initplan_policies.sql` — application status not yet verified
- [ ] `20261021170000_restrict_notification_updates.sql` — application status not yet verified

---

Generated from the repository's current migration directory. This inventory does not modify the database and does not execute SQL.
