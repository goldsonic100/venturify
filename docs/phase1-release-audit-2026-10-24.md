# Venturify Phase 1 release audit — 2026-10-24

## Scope

This audit covers the Phase 1 founder ecosystem (verified Level 5+ discovery, communities, profiles/reputation, opportunities, collaboration requests/workspaces, messaging/privacy, notifications), the settings/navigation and responsive UI baseline, and repository-side regression checks.

## Verified in this pass

- The live Supabase migration ledger includes `20261024215204 / fix_private_dm_follow_direction`.
- The live `get_messageable_founder_ids()` definition now checks that a private-DM recipient follows the sender when public DMs are disabled.
- The live `20261024220112 / public_profile_email_verification` migration adds a trusted `profiles.email_verified` flag, synchronizes it from `auth.users.email_confirmed_at`, and prevents profile updates from forging it. A live consistency query found 0 mismatches across 3 profiles.
- The live `create_group_conversation(text, uuid[])` definition applies the same follow direction and no longer contains the old sender-follows-recipient condition.
- Existing direct conversations remain eligible after a privacy preference changes; both functions continue to check block restrictions.
- PR #195 fixed over-escaped assertions in the messaging regression script. Its relevant CI checks passed.
- PR #196 fixed private-DM preference enforcement. Its repository regression workflows passed before the migration was applied.
- The migrations used in this pass were applied to the connected Supabase project, and the live function definitions were queried afterward.

## Automated gate

The new `Phase 1 release gate` workflow runs the existing static regression suites together in one job on pull requests and pushes to `main`. It checks JavaScript syntax and local routes, founder eligibility, opportunity/collaboration flow, messaging/privacy, account settings, profile/feed/reputation, notifications, trust/moderation, workspace integrity, and visual/mobile baselines.

These tests are **static source and migration checks**. They do not sign in to real user accounts or exercise browser interactions against the live Supabase project.

## Security findings to resolve before calling Phase 1 fully release-ready

- The latest Supabase Security Advisor still reports 13 authenticated-callable `SECURITY DEFINER` functions. Some are intentionally callable RPCs, but each should be reviewed for an explicit authorization check and least-privilege grants.
- The latest Security Advisor also reports a leaked-password-protection warning. Confirm the Auth setting in the Supabase dashboard and rerun the advisor before release; the advisor result observed during this audit was still warning.
- Historical migration source filenames and ledger versions have known drift documented in the existing `docs/supabase-migration-*` reports. Do not replay or rename an already-applied migration based on its filename alone. The new private-DM migration source has been aligned to its actual ledger version.

## Manual release checks still required

These require an authenticated browser session and separate accounts; they are not claimed as completed by the static checks.

- [ ] Account A sends a DM to Account B when B has public DMs enabled; verify delivery, unread count, notification, read state, and refresh/reconnect behavior.
- [ ] Turn B's public DMs off. Confirm A cannot start a new DM unless B follows A; confirm an existing direct conversation remains usable.
- [ ] Repeat the private-DM preference check for group-chat creation.
- [ ] Verify a block prevents new messages, group inclusion, and conversation access in both directions.
- [ ] Create an opportunity, send a collaboration request, accept it as the other account, and confirm both participants can open the same workspace and non-participants cannot.
- [ ] Verify community join/leave, follow/unfollow, profile edits, and displayed reputation as an ordinary account.
- [ ] Verify moderator review actions with a moderator account, then confirm a normal account cannot access moderator data or actions.
- [ ] On mobile Safari, test settings tabs, notifications, feed, messages, collaboration workspace, and light/dark appearance for overflow, keyboard/focus behavior, and recoverable loading/error states.
- [ ] After the final merge, confirm the GitHub Pages deployment workflow succeeds and the deployed site reflects the release commit.

## Release status

**Not yet marked fully release-ready.** The code and automated regression gate have been strengthened, and the private-DM preference bug is fixed in the live database. Final release sign-off remains blocked on confirming the leaked-password-protection advisor finding and completing the real-account/browser checks above.
