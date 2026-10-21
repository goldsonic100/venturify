# Supabase migration source recovery — follow-up (2026-10-21)

## Result

The second pass did not find a trustworthy source blob for the unmatched historical filenames. GitHub's path-specific commit history returns no commits for sampled missing migration paths, including notification Realtime, social bookmarks/reposts, stories/polls, direct-conversation helper/serialization, founder feedback/shortlists, and checklist sub-migrations. The repository contains later or consolidated source for some of these features, but not the original per-entry files.

This is an important negative result: **we cannot truthfully claim to have recovered the original historical SQL**. The safe action is to preserve a provenance map and compare current objects to current candidate source, rather than generate replacement files under old timestamps.

## Recovery classifications

| Missing ledger entry or group | Current source/candidate | Live evidence | Classification |
|---|---|---|---|
| `20261013215539_enable_notifications_realtime` | No exact source file found | `public.notifications` is in `supabase_realtime` | Feature present; original SQL unrecovered |
| `20261013220118_require_membership_to_post_in_communities` | `20261013020000_require_membership_for_community_posts.sql` | Live INSERT policy requires membership when `community_id` is set | High-confidence semantic equivalent |
| `20261014000223_verify_daily_founder_match_statement_limit` | `20261013061000_verify_daily_match_statement_limit.sql` | Verification trigger/function exists; current DB also has a separate enforcement trigger | Current source for verification trigger present; exact original file/version mismatch remains |
| `20261014011721_hybrid_social_posts_bookmarks_reposts` | No exact source file found | `post_bookmarks` and `post_reposts` exist | Feature present; original SQL unrecovered |
| `20261014012032_index_social_post_ownership_queries` | No confidently matching source file | Post indexes exist, but origin and full intended index set were not proven | Unresolved; do not infer from partial index presence |
| `20261014012358_venturify_stories_polls_media` | No exact source file found | `stories`, `post_polls`, `post_poll_options`, and `post_poll_votes` exist | Feature present; original SQL unrecovered |
| `20261014012629_protect_poll_vote_identity` | Later hardening: `20261019020000_fix_poll_vote_option_integrity.sql` | Current INSERT policy ties the selected option to the same poll and to the authenticated voter | Later integrity fix is present; it is not proof of the original identity-policy SQL |
| `20261014150626_add_venturify_mention_notifications` | No exact source file found | `private.notify_venturify_mentions()` exists | Function present; original trigger/source wiring needs historical verification |
| `20261014153112_add_profile_interests` | No exact migration file found | `profiles.interests` exists | Feature present; original SQL unrecovered |
| `20261015160113_harden_direct_messaging_and_unread_indexes` | `20261015020000_harden_direct_message_access.sql` and `20261015030000_add_complete_unread_message_counts.sql`; later block-hardening migrations | Current grants/RLS, unread RPC, and indexes exist | Split/current candidates; full historical equivalence not asserted |
| `20261015160122_fix_empty_conversation_policy_helper` | Current helper exists in live DB; no exact source file found | `private.conversation_is_empty(uuid)` checks whether the conversation has members | Function body observable; original migration unrecovered |
| `20261015160227_serialize_direct_conversation_creation` | Later direct-message hardening/block migration history | Current RPC takes an advisory transaction lock for the normalized user pair and rejects blocked/self targets | Current behavior present; exact historical source/version unresolved |
| `20261015160631_add_secure_message_read_lookup` | No exact source file found | `public.get_my_message_read_ids(uuid[])` exists and filters to the authenticated user | Function present; original migration unrecovered |
| `20261015213303_founder_match_feedback` | No exact source file found | Table, constraints, owner-scoped RLS policies, and candidate index exist | Feature present; original SQL unrecovered |
| `20261015222149_create_founder_shortlists` | No exact source file found | Table, no-self-save checks, owner-scoped RLS policies, and candidate index exist | Feature present; original SQL unrecovered |
| `20261020221047`–`20261020221125` checklist table/RLS/activity/Realtime entries | `20261020290000_workspace_task_checklists.sql` + `20261020300000_checklist_item_integrity.sql` | Table, four access policies, scoped FK, activity trigger, and Realtime publication exist | Consolidated source verified for core feature; original per-step SQL unrecovered |
| `20261020221546_workspace_tasks_workspace_unique` | `20261020290000_workspace_task_checklists.sql` | Unique constraint `workspace_tasks_id_workspace_unique` exists | Consolidated source explicitly guards this constraint |
| `20261020221551_workspace_task_checklist_composite_fk` | `20261020290000_workspace_task_checklists.sql` | Composite FK `workspace_task_checklist_task_workspace_fk` exists | Consolidated source explicitly guards this constraint |

## Important live definitions checked

- `private.conversation_is_empty(uuid)`: returns true only when no `conversation_members` rows exist for the requested conversation.
- `public.get_my_message_read_ids(uuid[])`: returns only read receipts belonging to `(select auth.uid())`, limited to the requested message IDs.
- `public.get_my_unread_message_counts()`: counts unread incoming messages per conversation, scoped to the current user's membership.
- `public.get_or_create_direct_conversation(uuid)`: rejects unauthenticated/self/missing-profile/blocked targets, takes an advisory transaction lock on a normalized pair key, reuses an existing two-member conversation, or creates one with both members.
- `private.notify_venturify_mentions()`: parses @handles, deduplicates usernames within a post/comment, resolves profile usernames, and inserts mention notifications for other users.
- Poll vote INSERT policy: requires the authenticated user to own the vote and requires the selected option to belong to the same poll.

These definitions confirm current behavior; they do not reconstruct every historical GRANT, index, trigger, comment, or intermediate definition.

## Next safe reconciliation actions

1. Treat the 25 missing historical source entries as a provenance problem, not a production-schema problem. Keep the classification above.
2. For the 30 same-name/different-version candidates, compare complete SQL and catalog definitions before labeling any as exact or equivalent.
3. For unresolved entries with no historical source, do not invent files under old versions. If a future change is needed, create a new migration with a new version, reviewed for idempotence and current-schema compatibility.
4. Keep the read-only audit script and re-run it after each genuine source recovery.
5. Validate changes in a staging database or restored backup before any production migration-history repair.

No production SQL was executed or changed during this recovery pass.
