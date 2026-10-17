# Block-enforcement verification plan

This plan supplements the static checks in `scripts/check-block-enforcement.mjs`. It is not a substitute for running tests against a disposable PostgreSQL/Supabase test database.

## Preconditions

- Apply the trust-and-safety foundation migration in the disposable test database.
- Apply the block-enforcement migration only in that test database.
- Use three test accounts: Alice, Bob, and Casey.
- Confirm existing policies and grants on `conversation_members`, `messages`, `profiles`, `posts`, and `comments` before interpreting results.

## Required scenarios

1. **Profile visibility:** Alice blocks Bob. Verify Alice cannot select Bob's profile and Bob cannot select Alice's profile; an unrelated Casey can still see both according to existing visibility rules.
2. **Post visibility:** Create posts for Alice and Bob before blocking. Verify each side cannot select the other's posts while Casey's visibility is unchanged.
3. **Comments:** Verify a user cannot add a comment to the other user's post when either side has blocked the other. Confirm allowed comments on unrelated posts still work.
4. **Direct messages:** Put Alice and Bob in a conversation, then create a block in either direction. Verify message reads and inserts are denied for the blocked pair. Confirm Alice and Casey can still message when no block relationship exists.
5. **Conversation membership visibility:** As Alice, query the conversation's membership rows under the real `conversation_members` RLS policies. Confirm the membership lookup used by the restrictive message policy can detect Bob's membership. If it cannot, the current message policy may fail to detect the block and needs a security-definer helper or a different policy design.
6. **Sender identity:** Attempt to insert a message with a `sender_id` other than the authenticated user; it must fail.
7. **No unrelated regression:** Verify users still see and use their own content and permitted conversations, and that existing RLS policies continue to restrict private content.

## Scope limitations to review

- The current migration explicitly adds policies for SELECT and INSERT on profiles/posts/comments/messages. Review existing UPDATE/DELETE policies and interaction tables (likes, follows, community memberships, typing status, and read receipts) to decide whether blocked relationships must also prevent those actions.
- Static checks only verify the migration text. They do not prove PostgreSQL's effective policy composition, table grants, helper-function behavior, or runtime results.
- Do not run this migration against the live project until the disposable-database checks pass and the resulting behavior has been reviewed.
