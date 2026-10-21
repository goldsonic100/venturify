# Migration content comparison pass — 2026-10-21

## Scope and method

This pass compared the complete repository SQL for known same-purpose migration candidates, checked selected live PostgreSQL catalog definitions, and queried `supabase_migrations.schema_migrations` for the six versions involved in the recent duplicate index/RLS optimization files. Queries were read-only. No production DDL, migration repair, or migration replay was performed.

## Findings

### 1. Three pairs of repository files have identical SQL bodies

| Earlier repository file (not in live migration ledger) | Later repository file (in live ledger) | Result |
|---|---|---|
| `20261021074500_add_missing_foreign_key_indexes.sql` | `20261021114604_add_missing_foreign_key_indexes.sql` | Same SQL body |
| `20261021074800_optimize_auth_rls_initplan_policies.sql` | `20261021114945_optimize_auth_rls_initplan_policies.sql` | Same SQL body |
| `20261021075200_optimize_workspace_activity_rls.sql` | `20261021115153_optimize_workspace_activity_rls.sql` | Same SQL body |

The live migration ledger contains the later versions (`20261021114604`, `20261021114945`, `20261021115153`) and not the earlier versions. This is consistent with the later files being the authoritative applied migration filenames. Do not rename the later files or mark the earlier files as applied. The earlier copies are not ledger entries, so whether to remove them is a repository-history/maintainer decision; this report intentionally leaves them untouched.

### 2. Foreign-key index migration: all 31 expected named indexes exist

Compared the index names and target tables from `20261021114604_add_missing_foreign_key_indexes.sql` against `pg_indexes` in the live database. **31/31 named indexes were present**, with the expected columns and ordinary btree index definitions. This confirms the current index footprint for that migration. It does not by itself prove that every index was first created by this exact migration.

### 3. Community-membership policy: high-confidence semantic match

Repository candidate `20261013020000_require_membership_for_community_posts.sql` and the live `Users create their own posts` INSERT policy both require:
- the new post's `user_id` to equal the authenticated user; and
- either a general post (`community_id IS NULL`) or a matching `community_members` row for the same user and community.

This is a high-confidence semantic equivalent for ledger entry `20261013220118_require_membership_to_post_in_communities`. It is not proof that the original file text has been recovered.

### 4. Daily founder-match cap has two distinct guard layers

The live database has both:
- `private.enforce_daily_founder_match_limit()`, a BEFORE INSERT row trigger that rejects attempts after six impressions and serializes inserts by locking the viewer profile row; and
- `private.verify_daily_founder_match_limit()`, an AFTER INSERT statement trigger that checks the inserted statement's viewer IDs against the daily count.

The repository has source for both the row guard (`20261013060000_limit_free_founder_matches_to_six_daily.sql`) and statement guard (`20261013061000_verify_daily_match_statement_limit.sql`). These are not duplicates: they are distinct protections. Do not drop one merely because both enforce a six-match limit.

### 5. Poll-vote integrity is a later corrective migration, not a recovered original

The live INSERT policy on `post_poll_votes` requires `user_id = auth.uid()` and checks that `post_poll_options.id = option_id` and `post_poll_options.poll_id = post_poll_votes.poll_id`. The repository's `20261019020000_fix_poll_vote_option_integrity.sql` creates this policy. This confirms the current integrity check, but does not reconstruct the historical `20261014012629_protect_poll_vote_identity` migration.

### 6. Consolidated checklist migration is structurally consistent with live objects

The current checklist source explicitly guards/creates the workspace-task composite unique constraint and checklist composite foreign key. The live database contains:
- `workspace_tasks_id_workspace_unique`;
- `workspace_task_checklist_task_workspace_fk`;
- the checklist table and four accepted-collaborator policies;
- the activity logging trigger and Realtime publication entry.

The original per-step checklist migration files remain unrecovered; the current consolidated files are the available source of truth for ongoing maintenance.

## Classification update

| Candidate group | Classification after this pass |
|---|---|
| Three index/RLS optimization filename pairs | Exact duplicate SQL bodies in repo; later filenames are the versions recorded in the live ledger |
| 31 foreign-key index names | All present in live catalog |
| Community membership INSERT policy | High-confidence semantic equivalent |
| Two daily founder-match limit guards | Distinct layered guards; preserve both |
| Poll vote identity/integrity | Current corrective policy verified; original historical source unrecovered |
| Checklist table/constraint/policies | Current consolidated source consistent with observed live objects; original split files unrecovered |

## Safe next action

Use the later ledger-tracked migration filenames as the operational history, preserve the read-only reconciliation report, and continue content comparison for remaining mismatches. Do not run `migration repair`, delete historical entries, or replay any of these migrations solely to make the local filenames look aligned. Any real schema correction should be a new migration with a new timestamp after a separate reviewed discrepancy is identified.
