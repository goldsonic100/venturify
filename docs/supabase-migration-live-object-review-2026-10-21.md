# Live-object review for unmatched migration ledger entries

Reviewed against the live Supabase catalog on 2026-10-21 for project `edyssdvytwdvpqkmalow`. This is a follow-up to `supabase-migration-reconciliation-2026-10-21.md`.

## Important interpretation

A live object can show that a feature is present, but it cannot reconstruct the exact SQL that created it. The classifications below distinguish **feature present** from **historical source recovered**. No migration was replayed, renamed, or marked applied during this review.

## Strong evidence of consolidated or differently named source

| Ledger entry or cluster | Live evidence | Assessment |
|---|---|---|
| `20261013220118_require_membership_to_post_in_communities` | The `posts` insert policy requires `community_members` membership when `community_id` is set; repository has `20261013020000_require_membership_for_community_posts.sql` with the same condition. | **High-confidence equivalent**; preserve the older source filename and document the ledger filename difference. |
| `20261014000223_verify_daily_founder_match_statement_limit` | `private.verify_daily_founder_match_limit()` and the `verify_daily_founder_match_limit` statement trigger exist; repository has `20261013061000_verify_daily_match_statement_limit.sql`. The current database also has a second enforcement trigger. | **Feature present, source likely equivalent**; compare both trigger definitions before any future consolidation. Do not drop either trigger just because names overlap. |
| `20261020221047` through `20261020221125` checklist table/RLS/read/insert/update/delete/activity/realtime entries | Checklist table, four named access policies, task/workspace composite FK, immutable-identity guard, activity logging, completion notification, indexes, and Realtime publication are present. Repository has consolidated `20261020290000_workspace_task_checklists.sql` plus `20261020300000_checklist_item_integrity.sql`. | **Feature present and consolidated source identified**; historical per-step SQL is still not recovered. |
| `20261020221546_workspace_tasks_workspace_unique` | `workspace_tasks_id_workspace_unique` exists as a unique constraint/index. | **Feature present**; the checklist consolidated migration contains a guarded creation of this constraint. |
| `20261020221551_workspace_task_checklist_composite_fk` | `workspace_task_checklist_task_workspace_fk` exists on checklist items. | **Feature present**; the consolidated checklist migration creates the scoped relationship. |

## Features confirmed present; exact historical source still needs content-level matching

| Ledger entry/cluster | Live evidence | Remaining source task |
|---|---|---|
| `20261013215539_enable_notifications_realtime` | `public.notifications` is in `supabase_realtime`. | Recover the original SQL or record the exact publication operation in a provenance note. |
| `20261014011721_hybrid_social_posts_bookmarks_reposts` | `post_bookmarks` and `post_reposts` exist in the live schema. | Find the original SQL/commit and compare table constraints, policies, and indexes. |
| `20261014012032_index_social_post_ownership_queries` | The live catalog has post-related indexes; this audit did not prove which indexes were created by this exact entry. | Compare index definitions to historical migration source. |
| `20261014012358_venturify_stories_polls_media` | `stories`, `post_polls`, `post_poll_options`, and `post_poll_votes` exist. | Recover/compare the original DDL and media/storage handling. |
| `20261014012629_protect_poll_vote_identity` | Poll-vote table and option/poll foreign keys exist; repository has a later poll integrity fix. | Recover the original vote identity policy and compare against current RLS policies. |
| `20261014150626_add_venturify_mention_notifications` | `public.notify_venturify_mentions()` exists. | Compare its trigger wiring and notification type handling to the historical source. |
| `20261014153112_add_profile_interests` | `profiles.interests` exists. | Recover the original column migration if available. |
| `20261015160113_harden_direct_messaging_and_unread_indexes` | Message/conversation tables have member RLS; unread/read RPCs and relevant indexes exist. Repository splits direct-message access and unread counts across separate files. | Compare grants, policies, indexes, and RPC bodies as a unit; don't infer equivalence from the names. |
| `20261015160122_fix_empty_conversation_policy_helper` | `private.conversation_is_empty(uuid)` exists and is used by the creator-membership policy. | Recover and compare exact helper body and grants. |
| `20261015160227_serialize_direct_conversation_creation` | Direct-conversation RPC exists; member table has its current constraints/indexes. | Verify the RPC's locking/uniqueness behavior against the missing migration's historical source. |
| `20261015160631_add_secure_message_read_lookup` | `public.get_my_message_read_ids(uuid[])` exists; `message_reads` has RLS and indexes. | Compare RPC body, grants, and policies against original source. |
| `20261015213303_founder_match_feedback` | `founder_match_feedback` table, feedback check, user-owned RLS policies, and candidate index exist. | Recover the original source; current object presence is not a source replacement. |
| `20261015222149_create_founder_shortlists` | `founder_shortlists` table, no-self-save/status constraints, owner RLS policies, and candidate index exist. | Recover the original source and compare policies/index definitions. |

## Safe next actions

1. Recover exact historical SQL from Git objects, branch refs, PR patches, or any retained migration exports for the entries still missing source.
2. For every recovered source, compare normalized SQL and object definitions with the live catalog. Mark it **exact**, **equivalent**, **partially represented**, or **unresolved**.
3. Keep the checklist feature as a consolidated source only if its full DDL and policy coverage remain verified; don't fabricate the eight historical migration files with invented timestamps.
4. For all entries whose SQL cannot be recovered, keep an explicit unresolved record. Do not create placeholder SQL, re-run DDL, or use `migration repair` as a shortcut.
5. Continue ordinary feature development with new uniquely versioned migrations while preserving this audit trail.

## Scope limitations

This review confirms selected tables, columns, policies, triggers, indexes, functions, and Realtime publication membership through catalog queries. It does not compare every original migration byte-for-byte and is not a substitute for a tested backup/restore or staging deployment.
