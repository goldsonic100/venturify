# Venturify Phase 1 security and release-readiness evidence

**Review date:** 2026-10-27  
**Scope:** Read-only checks against the configured Venturify Supabase project and source contracts on the repository's main branch.

## Verified results

- The live Supabase security smoke SQL returned **26 of 26 checks passing** on 2026-10-27.
- The RLS check inspected **34 public tables** and found RLS enabled on all of them.
- Passing checks cover account-settings owner policies, verified-email discovery visibility, private-profile/post/story/poll visibility, message block guards, message/reaction/read-receipt realtime publication, notification preferences, free community membership enforcement, daily founder-match limits, collaboration workspace creation, and moderator authorization.
- The four reviewed privileged non-moderator RPCs for group creation, direct conversation creation, poll results, and workspace deadline synchronization retain signed-in-user checks. The two founder-discovery/messageable-founder RPCs are not executable by the anonymous role and apply eligibility/access rules.
- The 13 public `SECURITY DEFINER` functions flagged by the Supabase advisor were inspected by function definition. All pin `search_path`; moderator RPCs check `auth.uid()` against `private.moderators`; group/direct conversation and workspace-sync RPCs have authentication and relevant access checks. The advisor warning is about authenticated-role executability and is not, by itself, proof of a vulnerability. Keep these functions under review if their bodies, grants, or intended callers change.
- Static source checks cover 14 Phase 1 pages for inline JavaScript syntax, viewport metadata, responsive CSS presence, shared accessibility styles, and theme-controller presence.
- The release-readiness workflow contains contract checks for core pages, Discover, settings persistence, messaging privacy, notification history, collaboration/workspaces, profiles, communities, moderator authorization, accessibility/theme consistency, and security smoke-test assertions.
- The user reports that the texting/messaging flow works in their test. This is recorded as user-confirmed, not as an independently automated live-browser test.

## Known free-plan limitation

- **Leaked-password protection:** On 2026-10-27, the Supabase dashboard returned an error when saving “Prevent use of leaked passwords,” stating that HaveIBeenPwned.org-based protection is available on Pro plans and above. The project is intentionally staying on the Free plan, so this feature remains unavailable and the Security Advisor warning is expected. Do not claim it is enabled. This is an explicitly accepted release limitation unless the plan changes; do not upgrade solely to clear this warning.

## Remaining release checks

- Complete and record the manual checklist in [Phase 1 two-account smoke test](phase1-two-account-smoke-test.md), except that the unavailable paid-only leaked-password feature is an accepted limitation. Messaging is user-confirmed working; settings persistence/privacy, notifications, collaboration acceptance/workspace membership, blocking, and moderator authorization still need explicit PASS/FAIL results.
- Complete live mobile and desktop visual QA, including theme switching, keyboard navigation, horizontal overflow, and stuck-loading checks.
- Review any new or changed SECURITY DEFINER functions and grants individually. The current advisor count is 13 authenticated-role execution warnings; these should not be blindly “fixed” by revoking legitimate app access.

## Release decision

Phase 1 may be considered complete when all applicable manual smoke-test items have recorded outcomes, no critical security/privacy failures remain, mobile/desktop QA passes, and the Free-plan leaked-password limitation is explicitly accepted. A static CI pass or a successful SQL smoke suite alone does not prove real browser flows.


## SECURITY DEFINER grant review (2026-10-27)

A live privilege query checked the 13 functions currently listed by the Supabase advisor. For every listed function:

- `anon` cannot execute the function.
- `PUBLIC` does not have effective execute privilege.
- `authenticated` can execute it, as expected for the signed-in application paths.
- Moderator RPC bodies check the caller against `private.moderators`; group/direct conversation and workspace deadline RPCs include authentication and access checks; founder discovery/messageable-founder RPCs apply eligibility/privacy rules; poll results require authentication.

This grant check narrows the finding: the advisor warning is due to signed-in users being able to invoke `SECURITY DEFINER` functions. It does **not** show anonymous execution or a public grant. Revoking authenticated execution wholesale would break intended application features. The next security change should only be made alongside a reviewed alternative API/grant design and regression tests, rather than changing grants blindly.

The live advisor still reports 13 authenticated-role execution warnings after this review. They are reviewed but not cleared.
