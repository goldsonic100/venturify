# Trust & safety foundation

This additive migration introduces the database foundation for account blocking and content reporting:

- `public.user_blocks`: a user can block and later unblock another account.
- `public.content_reports`: signed-in users can report one profile, post, or comment using a constrained reason list.
- Row Level Security prevents users from creating blocks as someone else, reading unrelated reports, or changing report status/notes through the public client.

## Apply the migration

1. Open the Venturify Supabase project.
2. Open **SQL Editor** and create a query.
3. Copy and run `supabase/migrations/20261016000000_add_trust_safety_foundation.sql`.
4. Confirm both tables exist and RLS is enabled in **Table Editor**.

The migration is additive and does not modify existing tables or policies.

## Important scope / remaining work

This is a database foundation, not a complete user-facing moderation feature yet.

- Add report and block controls to the feed, profile, comments, and messages UI.
- Update feed/discovery/message queries and interaction policies to enforce blocks consistently in both directions.
- Build a trusted moderator review workflow (for example, a protected server-side function with an explicit moderator role). Do **not** expose report status/notes updates to ordinary authenticated users or put a service-role key in browser code.
- Add abuse-rate limits, appeal/deletion handling, and test with two accounts before launch.

Reports are private to the reporter under the current client policies. There is intentionally no public client policy that lets users browse all reports or alter moderation decisions.
