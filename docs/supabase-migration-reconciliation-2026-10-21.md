# Supabase migration reconciliation audit — 2026-10-21

## Scope and safety

This audit compares the migration ledger returned by the connected Supabase project `edyssdvytwdvpqkmalow` with the filenames in `supabase/migrations/` on the repository's `main` branch.

It is an inventory, **not proof that SQL contents are equivalent**. A matching migration name with a different timestamp is only a candidate mapping. No migration was replayed, renamed, deleted, or marked applied as part of this audit.

## Snapshot

| Check | Result |
|---|---:|
| Supabase migration ledger entries | 68 |
| SQL migration files in repository | 64 |
| Exact `version_name.sql` matches | 13 |
| Ledger entries with a same-name repository candidate but a different filename/version | 30 |
| Ledger entries with no same-name repository file | 25 |
| Repository SQL files not exactly represented in the ledger | 51 |

The categories above overlap by design: the 43 ledger entries with a same-name file include 13 exact matches and 30 different-filename candidates. The 51 repository files that are not exact ledger filenames include the candidate files and files with no exact ledger entry.

## Entries with no same-name source file

These 25 ledger entries need source recovery or a content-based mapping to a migration that intentionally superseded/consolidated them:

- `20261013215539_enable_notifications_realtime`
- `20261013220118_require_membership_to_post_in_communities`
- `20261014000223_verify_daily_founder_match_statement_limit`
- `20261014011721_hybrid_social_posts_bookmarks_reposts`
- `20261014012032_index_social_post_ownership_queries`
- `20261014012358_venturify_stories_polls_media`
- `20261014012629_protect_poll_vote_identity`
- `20261014150626_add_venturify_mention_notifications`
- `20261014153112_add_profile_interests`
- `20261015160113_harden_direct_messaging_and_unread_indexes`
- `20261015160122_fix_empty_conversation_policy_helper`
- `20261015160227_serialize_direct_conversation_creation`
- `20261015160631_add_secure_message_read_lookup`
- `20261015213303_founder_match_feedback`
- `20261015222149_create_founder_shortlists`
- `20261020221047_workspace_task_checklist_table`
- `20261020221059_workspace_task_checklist_rls`
- `20261020221104_workspace_task_checklist_read_policy`
- `20261020221111_workspace_task_checklist_insert_policy`
- `20261020221113_workspace_task_checklist_update_policy`
- `20261020221114_workspace_task_checklist_delete_policy`
- `20261020221121_workspace_task_checklist_activity`
- `20261020221125_workspace_task_checklist_realtime`
- `20261020221546_workspace_tasks_workspace_unique`
- `20261020221551_workspace_task_checklist_composite_fk`

## Examples of same-name candidates with different versions

The ledger and repository disagree on filenames for multiple migrations. Examples:

| Ledger entry | Repository candidate |
|---|---|
| `20261013214047_add_venturify_notification_triggers` | `20261013000000_add_venturify_notification_triggers.sql` |
| `20261013215937_add_communities_and_memberships` | `20261013010000_add_communities_and_memberships.sql` |
| `20261013234834_expand_venturify_founder_profiles` | `20261013030000_expand_venturify_founder_profiles.sql` |
| `20261013235840_enable_message_realtime` | `20261013050000_enable_message_realtime.sql` |
| `20261014000113_limit_free_founder_matches_to_six_daily` | `20261013060000_limit_free_founder_matches_to_six_daily.sql` |
| `20261014143555_messaging_read_receipts_and_typing` | `20261014000000_messaging_read_receipts_and_typing.sql` |
| `20261016205215_add_workspace_task_due_dates` | `20261016204100_add_workspace_task_due_dates.sql` |
| `20261016211338_workspace_deadline_notifications` | `20261016210000_workspace_deadline_notifications.sql` |
| `20261018143231_enforce_user_blocks` | `20261017000000_enforce_user_blocks.sql` |
| `20261018144605_add_moderator_review_workflow` | `20261018150000_add_moderator_review_workflow.sql` |
| `20261020213132_add_workspace_activity_timeline` | `20261020230000_add_workspace_activity_timeline.sql` |
| `20261020215003_workspace_task_comments` | `20261020250000_workspace_task_comments.sql` |
| `20261021012647_consolidate_workspace_notifications` | `20261020310000_consolidate_workspace_notifications.sql` |

There are also multiple versions of the foreign-key-index, RLS-initplan, and workspace-activity optimization migrations in the repository. These need content/hash comparison before any copy is selected as canonical.

## Recommended reconciliation procedure

1. Export the current Supabase migration ledger and run the read-only audit script:
   `node scripts/audit-supabase-migrations.mjs migration-ledger.json supabase/migrations --report-only`
2. For each of the 25 entries above, inspect the historical Git commit/file (if available), and compare its SQL with current candidate files and the live schema.
3. Label each entry as **exact source recovered**, **content-equivalent consolidated migration verified**, or **source still missing**. Do not treat a similar filename as proof.
4. Recover exact historical source files where possible, or add a reconciliation note identifying a verified superseding migration when the source was intentionally consolidated. Avoid changing a migration's timestamp after it has been applied.
5. Separately verify that no unapplied repository migration is accidentally being proposed for production. Apply only new, reviewed migrations through the normal migration workflow.
6. Re-run the inventory after each recovery PR and keep the result in version control.

## Why this is not auto-fixed

The migration ledger is historical state. Renaming applied migrations, replaying old DDL, or marking entries as applied without comparing their SQL can create duplicate objects, change security policies, or make future deployments unsafe. The correct next action is content-level reconciliation, not filename normalization.
