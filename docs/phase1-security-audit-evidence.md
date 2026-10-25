# Venturify Phase 1 security and release-readiness evidence

**Review date:** 2026-10-25  
**Scope:** Read-only checks against the configured Venturify Supabase project and static source checks against the repository's main branch.

## Verified results

- The Supabase security smoke SQL returned **26 checks passing** after the privileged-RPC authentication regression check was added.
- The RLS check inspected **34 public tables** and found RLS enabled on all of them.
- Checks passed for account-settings owner policies, verified-email discovery visibility, private-profile/post visibility, message block guards, message and reaction realtime publication, notification preferences, free community membership enforcement, daily founder-match limit triggers, collaboration workspace creation, and moderator authorization.
- A read-only source review of the six non-moderator SECURITY DEFINER RPCs confirmed that group creation, direct conversation creation, poll-result access, and workspace deadline synchronization include authentication checks; discovery and messageable-founder RPCs are not executable by the anonymous role and apply their eligibility/access rules.
- Static checks on all 14 Phase 1 pages passed for inline JavaScript syntax, viewport metadata, responsive CSS presence, the shared accessibility stylesheet, and the shared theme controller.
- The release-readiness workflow now checks core page contracts, Discover/settings/messaging/notification/collaboration contracts, and the presence of key security smoke-test assertions.

## Outstanding items — do not mark Phase 1 complete yet

- **Leaked-password protection:** The Supabase security advisor reported this setting as disabled on the review date, despite an earlier report that it had been enabled. Re-open the Auth password-security settings in the Supabase dashboard and verify the persisted setting; rerun the advisor afterward.
- **Live two-account testing:** Complete the manual checklist in [Phase 1 two-account smoke test](phase1-two-account-smoke-test.md). Static checks do not prove real-time message delivery, user privacy behavior, or collaboration workspace access in the deployed app.
- **SECURITY DEFINER advisor notices:** The advisor still reports 13 authenticated-role execution warnings. These are not automatically proof of a vulnerability, but the affected RPCs must remain reviewed and covered by the SQL checks. Reassess if their function bodies, grants, or intended callers change.
- **Visual QA:** Confirm the live site at mobile and desktop sizes and exercise Light, Dark, and System themes after deployment.

## Release rule

Do not describe Phase 1 as fully complete until the leaked-password setting is verified, all manual smoke-test items are recorded as PASS or have explicit accepted follow-ups, and there are no unresolved critical security issues.
