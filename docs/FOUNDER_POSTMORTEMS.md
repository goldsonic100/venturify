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


## Supabase security-advisor note

Supabase may report `list_published_founder_postmortems(integer)` as an anonymously executable SECURITY DEFINER function. That warning is expected for this feature: the public post-mortem library must load for visitors who are not signed in. Do **not** revoke its `anon` EXECUTE grant unless the product intentionally changes to a sign-in-only library.

This is a narrow public projection, not public table access. The function:
- returns only stories with `status = 'approved'` and explicit `consent_to_publish = true`;
- reveals a company name only when `company_visibility = 'public'`;
- shows profile attribution only when `author_display_mode = 'profile'`, otherwise it uses “Anonymous founder”;
- does not return author IDs or private moderator notes;
- pins an empty `search_path` and caps the requested result count at 100.

The security smoke check `postmortem_public_rpc_exposes_only_approved_consented_projection` verifies the public grant and the projection's privacy boundaries. Treat the advisor entry as a reviewed, intentional exception—not as a reason to expose the underlying table or remove the consent/approval filters.
