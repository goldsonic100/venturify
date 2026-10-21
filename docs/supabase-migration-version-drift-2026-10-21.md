# Remaining Supabase migration version drift — 2026-10-21

## Scope

This report refreshes the read-only comparison after PRs #46 and #53 restored/renamed the three optimization sources and corrected the two workspace-notification filenames to match the live ledger. It compares filenames and migration names only, plus live object checks already performed in the companion audit reports. A filename match is not proof of SQL equivalence.

No production DDL was executed and no migration was replayed or marked applied.

## Current inventory

Snapshot from the connected Supabase project `edyssdvytwdvpqkmalow` and repository `main`:

- 68 migration ledger entries.
- 64 SQL files under `supabase/migrations/`.
- 15 exact `version_name.sql` matches.
- 28 ledger entries have a same-name repository file with a different timestamp.
- 25 ledger entries have no same-name repository file.
- 49 repository SQL files are not exact ledger filenames.

These categories overlap: 15 exact matches + 28 same-name/different-version candidates + 25 entries without same-name files = 68 ledger entries. The 49 non-exact repository files include version-drift candidates and files with no exact ledger counterpart.

## Same-name files whose version differs

These are candidate source mappings, not yet safe to rename automatically:

| Ledger version/name | Repository file |
|---|---|
| `20261013214047_add_venturify_notification_triggers` | `20261013000000_add_venturify_notification_triggers.sql` |
| `20261013215937_add_communities_and_memberships` | `20261013010000_add_communities_and_memberships.sql` |
| `20261013234834_expand_venturify_founder_profiles` | `20261013030000_expand_venturify_founder_profiles.sql` |
| `20261013235840_enable_message_realtime` | `20261013050000_enable_message_realtime.sql` |
| `20261014000113_limit_free_founder_matches_to_six_daily` | `20261013060000_limit_free_founder_matches_to_six_daily.sql` |
| `20261014143555_messaging_read_receipts_and_typing` | `20261014000000_messaging_read_receipts_and_typing.sql` |
| `20261016005314_tighten_function_execute_grants` | `20261015000000_tighten_function_execute_grants.sql` |
| `20261016005517_enforce_free_community_membership_limit` | `20261015010000_enforce_free_community_membership_limit.sql` |
| `20261016122641_revoke_anon_access_to_message_metadata` | `20261016000000_revoke_anon_access_to_message_metadata.sql` |
| `20261016203038_create_collaboration_requests` | `20261016010000_create_collaboration_requests.sql` |
| `20261016203214_create_collaboration_workspaces_and_tasks` | `20261016020000_create_collaboration_workspaces_and_tasks.sql` |
| `20261016203449_add_collaboration_activity_notifications` | `20261016025000_add_collaboration_activity_notifications.sql` |
| `20261016203504_add_workspace_context_to_notifications` | `20261016030000_add_workspace_context_to_notifications.sql` |
| `20261016203726_add_private_workspace_chat` | `20261016040000_add_private_workspace_chat.sql` |
| `20261016203912_add_private_workspace_file_storage` | `20261016050000_add_private_workspace_file_storage.sql` |
| `20261016205215_add_workspace_task_due_dates` | `20261016204100_add_workspace_task_due_dates.sql` |
| `20261016211338_workspace_deadline_notifications` | `20261016210000_workspace_deadline_notifications.sql` |
| `20261016211523_index_notification_task_id` | `20261016212000_index_notification_task_id.sql` |
| `20261018143231_enforce_user_blocks` | `20261017000000_enforce_user_blocks.sql` |
| `20261018144605_add_moderator_review_workflow` | `20261018150000_add_moderator_review_workflow.sql` |
| `20261020213132_add_workspace_activity_timeline` | `20261020230000_add_workspace_activity_timeline.sql` |
| `20261020213314_workspace_notifications` | `20261020240000_workspace_notifications.sql` |
| `20261020215003_workspace_task_comments` | `20261020250000_workspace_task_comments.sql` |
| `20261020215658_realtime_task_comments` | `20261020260000_realtime_task_comments.sql` |
| `20261020215934_task_comment_notifications` | `20261020270000_task_comment_notifications.sql` |
| `20261020220456_workspace_task_priority_labels` | `20261020280000_workspace_task_priority_labels.sql` |
| `20261020221722_checklist_item_integrity` | `20261020300000_checklist_item_integrity.sql` |
| `20261021012724_notification_feed_indexes` | `20261020320000_notification_feed_indexes.sql` |

The three index/RLS optimization migration pairs are intentionally omitted from this table because their duplicate bodies and canonical ledger versions were already compared in the companion content-comparison report. The two notification filenames corrected in PR #53 are also now exact ledger matches.

## Ledger entries with no same-name repository file

The 25 unmatched entries are documented in `docs/supabase-migration-source-recovery-2026-10-21.md`. Important examples include early social post/bookmark/repost and story/poll migrations, several direct-message hardening helpers, founder feedback/shortlists, and the original individual checklist migrations. The consolidated checklist source is present and was compared with the live table, policies, composite key, activity trigger, and Realtime publication; it does not recover each original historical file byte-for-byte.

## Live-schema evidence already checked

- All 31 expected foreign-key indexes from the ledger-matched index migration exist with expected table/definition.
- All 33 public tables have row-level security enabled.
- The community post insert policy requires the authenticated author and, for community posts, membership in that community.
- Both daily founder-match enforcement triggers are present and intentionally retained as distinct layers.
- The poll-vote insert policy constrains vote ownership and ensures the chosen option belongs to the same poll.
- The consolidated checklist objects match the live checklist structure and controls.
- Messaging and collaboration smoke checks documented in the existing reports passed, including restrictive blocked-user checks, group/direct conversation helper behavior in a rolled-back test, recipient message notification trigger, and one workspace-created notification source.

## Safe next actions

1. Keep the remaining 28 same-name/version mismatches as candidates until each file's SQL is compared with historical commit contents or live schema behavior. Do not bulk-rename by filename alone.
2. Recover exact source for the 25 unmatched ledger entries from Git history where possible. Where a later consolidated migration replaced several originals, record the verified mapping rather than inventing original SQL.
3. For any apparent schema mismatch, write a new forward-only migration after a focused regression test; do not replay old migrations to “repair” the ledger.
4. Return to the user-facing collaboration/messaging flow after this inventory: verify the opportunity-to-collaboration action and two-account messaging end-to-end, since database smoke checks cannot prove the deployed UI works in a real browser.

## References

- `docs/supabase-migration-reconciliation-2026-10-21.md`
- `docs/supabase-migration-source-recovery-2026-10-21.md`
- `docs/supabase-migration-content-comparison-2026-10-21.md`
- `scripts/audit-supabase-migrations.mjs`
