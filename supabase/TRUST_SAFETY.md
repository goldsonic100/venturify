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


## Protected moderator review workflow

The moderator review migration adds a private allowlist and two guarded RPCs:
- `public.moderator_list_reports(status, limit)` lists reports only for provisioned moderators.
- `public.moderator_update_report(report_id, status, notes)` records a decision, private notes, reviewer ID, and review time.
- The Safety panel's **Moderator review** control uses these RPCs. Ordinary signed-in users may see the control, but the database denies access unless their account is on the allowlist.
- The allowlist is in the non-exposed `private.moderators` table and is not readable/writable by browser roles. Authorization does not rely on user-editable profile metadata.
- The service-role/secret key must never be placed in browser code.

### Provision a moderator

After the migration has been reviewed and applied, a trusted project administrator must find the intended person's UUID in Supabase Dashboard → Authentication → Users, then run this in SQL Editor as the database owner (replace the placeholder with that exact UUID):

```sql
insert into private.moderators (user_id)
values ('REPLACE-WITH-AUTH-USER-UUID')
on conflict (user_id) do nothing;
```

To revoke moderator access:

```sql
delete from private.moderators
where user_id = 'REPLACE-WITH-AUTH-USER-UUID';
```

Do not run the placeholder SQL as-is. Provision only trusted accounts. The migration does not automatically make anyone a moderator, and it has not been applied to the live project by this change.


## Moderator dashboard

The dedicated `moderator.html` page adds Overview, Reports, Accounts, Content, and Systems tabs. The dashboard migration is additive and adds three guarded RPCs:

- `moderator_dashboard_overview()` returns aggregate counts for profiles, posts, comments, communities, memberships, reports, and messages.
- `moderator_list_users(query, limit, offset)` searches profile-level fields and follower/post counts. It deliberately does not return email addresses or authentication data.
- `moderator_list_recent_posts(query, limit)` lists public post content for review.

Apply `supabase/migrations/20261018160000_add_moderator_dashboard.sql` in the Supabase SQL Editor after the moderator review migration. The RPCs verify membership in `private.moderators` on every call. They do not expose private messages, auth credentials, session data, or the moderator allowlist.

The Systems tab reports database query success and current record counts only. It is not a hosting uptime, billing, email-delivery, or incident monitoring system. Account suspension/deletion is intentionally not included; those actions need a separate server-side workflow with an audit trail.
