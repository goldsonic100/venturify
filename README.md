# Venturify

**Learn from what didn't work. Build what comes next.**

Venturify is a founder community and startup post-mortem project. It brings together founder profiles, public posts, communities, discovery, and trust-and-safety tools so founders can share lessons and find people to build with.

## Current project areas

- Founder profiles and public posts
- Founder discovery and community membership
- Supabase-backed authentication and data
- Trust-and-safety controls for reporting content and blocking accounts
- Protected moderator review and dashboard pages
- GitHub Pages static-site deployment

Feature availability depends on the current frontend and the Supabase migrations applied to the connected project. Treat the dashboard and moderation tools as in-progress until tested with separate ordinary-user and moderator accounts.

## Run locally

Because this is a static site, you can open `index.html` in a modern browser or serve the repository with a local static web server. Some authentication redirects and browser features may require serving it over HTTP rather than opening the file directly.

The frontend uses the Supabase JavaScript client and the project's publishable key. A publishable key is designed for browser use, but it is not a substitute for Row Level Security (RLS). Never put a Supabase service-role/secret key, database password, or other server secret in frontend files.

## Supabase setup and migrations

The repository's SQL migrations live in `supabase/migrations/`. Review the migration files and apply them to the intended Supabase project in dependency order. In particular, the moderator tools depend on the trust-and-safety schema and moderator-review authorization being installed before the moderator dashboard migration.

The moderator dashboard uses a private moderator allowlist. Merely signing in does not grant moderator access. A trusted project administrator must provision the correct auth-user UUID in `private.moderators` after reviewing the relevant migration. Do not grant moderator access to untrusted accounts.

For moderation details and setup notes, see [`supabase/TRUST_SAFETY.md`](supabase/TRUST_SAFETY.md).

## Trust and safety notes

- Reports and blocked-account actions should be tested while signed in with separate accounts.
- Moderator RPCs must continue to enforce the private moderator allowlist server-side.
- Do not expose private messages, authentication data, session tokens, or service-role credentials in moderator pages.
- Profile and post visibility, block enforcement, and report handling should be verified before opening the service to a wider audience.
- The Systems tab reports database counters and RPC success; it is not a hosting uptime or incident-monitoring service.
- Account suspension/deletion and appeals require a separate audited server-side workflow.

## Publish with GitHub Pages

1. Open the repository's **Settings** tab.
2. Select **Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**.
4. Select branch `main` and folder `/ (root)`, then save.
5. Wait for the deployment to finish and use the URL shown in Pages settings.

## Before a wider launch

- Verify every Supabase migration has been applied to the correct project.
- Test sign-up, sign-in, sign-out, profile editing, posts, communities, discovery, and messaging with separate accounts.
- Test report submission and blocking, including whether blocked users are filtered consistently.
- Confirm ordinary users cannot call moderator RPCs successfully.
- Add contributor consent, deletion/export procedures, and clear labeling for self-reported versus independently verified claims.
- Only publish pitch decks, financial records, or other sensitive founder materials with explicit permission.

## License

No license has been selected yet.
