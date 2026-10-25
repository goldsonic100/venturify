# Phase 1 two-account release smoke test

Run this checklist against the deployed site after the latest main branch is published. Use two test accounts you control (Account A and Account B). Do not use real users' private content for testing.

Record each result as **PASS**, **FAIL**, or **BLOCKED**. A blocked test means the required account, setting, or test data is unavailable; it is not a pass.

## 1. Authentication and public visibility

- [ ] A visitor who is signed out can browse public pages but cannot like, follow, join a community, send a message, or create a collaboration request.
- [ ] A newly registered account does not appear in public founder discovery until email verification is complete.
- [ ] A verified but incomplete/new account does not appear in Discover until it meets the Level 5+ and at-least-one-community requirements.
- [ ] A qualifying founder appears in Discover, and the signed-in user's own account does not appear as a recommendation.
- [ ] The personalized match experience does not offer more than six daily matches to a free account.

## 2. Settings persistence and privacy

- [ ] Change a setting, save, refresh, and confirm the saved value is restored.
- [ ] Navigate between every Settings section using both mouse/touch and keyboard.
- [ ] Turn public profile visibility off; confirm a signed-out visitor cannot read the private profile or its posts.
- [ ] Turn public DMs off; confirm a non-following account cannot initiate a new direct conversation, while existing conversations remain available.
- [ ] Confirm the appearance setting works on the settings page and at least two other pages; test Light, Dark, and System where available.
- [ ] Confirm failed saves show an error and do not claim success.

## 3. Direct messages, notifications, and blocking

- [ ] Account A sends a direct message to Account B; B receives it and can reply.
- [ ] Refresh both accounts and confirm the conversation history remains.
- [ ] Confirm timestamps, unread state, and notification links behave consistently.
- [ ] Confirm a user who is not allowed to initiate a conversation cannot bypass the UI by changing a recipient selection.
- [ ] Block B from A; verify the blocked interaction is enforced, then unblock and verify the intended access returns.
- [ ] Confirm notification preference settings are respected for message notifications.

## 4. Communities and collaboration workspaces

- [ ] Account A joins a community and the membership count/status updates.
- [ ] Verify a free account cannot exceed the configured community membership limit.
- [ ] Account A sends a collaboration request to Account B; B can accept or decline it.
- [ ] Accepting a request creates or opens the shared workspace exactly once.
- [ ] Both collaborators can view and update permitted workspace tasks, milestones, and messages.
- [ ] A non-member cannot access a private workspace by guessing its URL or ID.
- [ ] Verify workspace status and notification updates after refreshing.

## 5. Safety and moderator access

- [ ] Submit a report using a test account and confirm it appears in moderator review.
- [ ] A normal account cannot access moderator-only data or actions.
- [ ] A moderator can review the report and apply an allowed moderation action.
- [ ] Confirm block/report controls remain usable on mobile and desktop.

## 6. Visual and accessibility sweep

- [ ] Check Home, Feed, Discover, Communities, Messages, Notifications, Profile, Settings, Collaborations, Workspace, and Moderator pages at mobile and desktop widths.
- [ ] Check that there is no horizontal overflow, clipped primary action, or stuck loading state.
- [ ] Keyboard users can reach primary controls and see focus indicators; skip links become visible on focus.
- [ ] Status messages announce loading, errors, and successful actions without relying only on color.
- [ ] Light and dark themes keep text, controls, and focus indicators readable.

## Release decision

- [ ] No critical security or privacy failures.
- [ ] No failed core account-to-account flows.
- [ ] All failed checks have a linked issue or follow-up PR.
- [ ] Any blocked checks are explicitly recorded and resolved before calling Phase 1 complete.

**Important:** This is a manual live-environment test matrix. Static GitHub Actions checks cannot prove Supabase permissions, account privacy, realtime delivery, or real two-account behavior by themselves.
