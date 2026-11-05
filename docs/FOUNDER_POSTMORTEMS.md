# Founder post-mortem submissions

## What the feature does

- `submit-postmortem.html` requires a signed-in user and explicit consent. Contributors choose anonymous or profile attribution and whether the company name may be shown. Financial context is optional and limited to broad-range guidance.
- `founder_postmortems` submissions are private by default. Authors can read their own submissions; there is no public table read or direct browser update/delete policy.
- `moderator-postmortems.html` uses guarded RPCs and the existing `private.moderators` allowlist to review pending submissions. Moderators can request edits, approve, or reject, with private notes.
- Only approved, consented stories are returned by `list_published_founder_postmortems`. The public projection omits author IDs and hides company names unless the contributor opted into company attribution.
- Contributors can withdraw their own story through `withdraw_my_founder_postmortem`; a withdrawn story is excluded from the public projection.

## Apply the migration

Apply `supabase/migrations/20261105090000_create_founder_postmortems.sql` in the intended Supabase project after the existing moderator allowlist migration (`20261018150000_add_moderator_review_workflow.sql`). The migration assumes `public.profiles` and `private.moderators` already exist. Review it first, test in a development project with two user accounts, and verify ordinary authenticated accounts cannot call moderator RPCs successfully.

Do not put a service-role key in the browser. The public Supabase key is used only with RLS and narrowly scoped RPC grants. Database migrations must be applied to Supabase separately; committing the SQL file does not apply it to a live project.

## Review guidance

Before approving, verify consent, check the selected identity/company visibility, remove sensitive third-party details, and ensure the post-mortem offers lessons rather than blame. Treat submissions as private until approval. Record requested edits in the private moderator notes. Approval is not an independent verification of every claim; do not label stories independently verified unless that has actually occurred.

## Limitations

The first version has no author-facing edit screen or notification when a moderator requests edits. Contributors may contact a moderator to withdraw submissions; the withdrawal RPC is available for a future account submissions screen. Only pending items appear in the initial review page; `needs_edits` items can be queried through the guarded RPC but are not yet shown by that page.
