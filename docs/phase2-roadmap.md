# Venturify Phase 2 roadmap

**Goal:** Make Venturify a connected founder ecosystem where ideas, practical resources, and lived experience from successful and failed ventures all have equal value. Preserve working Phase 1 features and improve them in small, testable increments.

## Phase 2A — Connect the ecosystem (in progress)

- [x] Add a homepage pathway linking founder stories, Discover, Communities, and Collaborations.
- [x] Keep the pathway visible on the home page only, without leaking it into app subviews.
- [ ] Verify the new pathway at desktop and mobile widths on the deployed site.
- [ ] Check all four links and signed-out browsing behavior.

## Phase 2B — Make resources useful

- [x] Audit the existing case-study and story experience: case studies are local fictional demo records; story submission explicitly says it does not save or transmit submissions. No resource-specific table was established by this audit.
- [x] Define the first resource-hub pathways without introducing an unverified resource schema: founder lessons, peer knowledge, communities, collaborations, founder discovery, and story sharing.
- [x] Add keyword search and goal filters for the six existing resource pathways using explicit page-authored tags; fix multi-tag matching and provide a clear-filters recovery action.
- [ ] Add topic tags and consistent search/filter affordances to future resource listings only after real resource records and supported fields are identified.
- [x] Explain the current demo-data and submission-storage limitations; require explicit permission before sharing sensitive founder material.

## Phase 2C — Connect people to ideas

- [x] Make opportunity cards show the existing offer/need fields, project stage when present, and collaboration actions; do not invent structured skills/resource fields absent from the schema.
- [x] Clarify next steps on existing collaboration request cards (review, waiting, accepted, declined) using only current request status and message fields; structured skill/resource/stage fields are not added because they are not established in this request query.
- [x] Add keyword search across existing offer/help/topic-tag fields and filter opportunities by the existing project-stage field.
- [x] Link opportunities to their associated communities when `posts.community_id` is present; community links validate the requested ID against loaded community records.
- [x] Audit founder-story relationships: the app's `stories` query is for expiring social story tiles, while opportunities use `posts`; the checked starter schema does not establish a founder-story foreign key to an opportunity.
- [ ] Link relevant founder post-mortems from opportunities only after a stable, reviewed founder-story data model and relationship are established.
- [ ] Preserve Discover eligibility rules: verified accounts, Level 5+, at least one community, and no self-recommendation.
- [ ] Preserve free-plan limits and existing privacy/blocked-user enforcement.

## Phase 2D — Product polish

- [x] Improve opportunity-card hierarchy and mobile action layout with responsive, page-scoped styles.
- [x] Add retry recovery for saved-post loading failures and accessible status/alert semantics for feed states.
- [x] Add a retry action and accessible error announcements to the collaboration request page when the initial load fails.
- [x] Add retry recovery and accessible error announcements for failed profile and follower-list loads; improve small-screen interaction targets and reduced-motion handling.
- [ ] Continue improving shared visual hierarchy, card consistency, and loading/error states on remaining pages.
- [ ] Test keyboard focus, accessible status announcements, and light/dark/system themes after each change.
- [ ] Avoid broad rewrites of the single-page app shell; keep each change isolated and run the existing readiness/regression scripts.

## Phase 2E — Release discipline

- [ ] Every feature PR includes its behavior, constraints, and regression checks.
- [ ] Run the relevant GitHub Actions workflows and Supabase smoke suite for changes that affect security/data behavior.
- [ ] Record user-reported manual results separately from automated evidence.
- [ ] Do not claim a feature works solely because a static contract test passes.

## Guardrails

- Do not weaken RLS, account privacy, moderator authorization, blocking, or verification rules for convenience.
- Do not blanket-revoke authenticated execution from reviewed `SECURITY DEFINER` functions; inspect each function's callers and authorization logic first.
- The Supabase Free-plan leaked-password protection limitation remains documented and is not represented as enabled.
