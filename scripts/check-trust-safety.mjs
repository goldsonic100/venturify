import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';

const foundation = readFileSync('supabase/migrations/20261016000000_add_trust_safety_foundation.sql', 'utf8');
const blockMigration = readFileSync('supabase/migrations/20261017000000_enforce_user_blocks.sql', 'utf8');
const moderatorMigration = readFileSync('supabase/migrations/20261018150000_add_moderator_review_workflow.sql', 'utf8');
const dashboardMigration = readFileSync('supabase/migrations/20261018160000_add_moderator_dashboard.sql', 'utf8');
const reportPaginationMigration = readFileSync('supabase/migrations/20261018170000_paginate_moderator_reports.sql', 'utf8');
const moderatorPage = readFileSync('moderator.html', 'utf8');
const safetyScript = readFileSync('scripts/trust-safety.js', 'utf8');

// Base safety schema and row-level security controls must not silently disappear.
for (const table of ['user_blocks', 'content_reports']) {
  assert.ok(
    foundation.toLowerCase().includes(`create table if not exists public.${table}`),
    `Missing ${table} table`
  );
}
for (const policy of [
  'Users can view blocks involving them',
  'Users can block accounts as themselves',
  'Users can unblock accounts as themselves',
  'Users can submit reports as themselves',
  'Users can view their own reports'
]) {
  assert.ok(foundation.includes(policy), `Missing RLS policy: ${policy}`);
}
for (const control of ['ventSafetyLauncher', 'ventSafetyPanel', 'ventSafetyReport', 'ventSafetyBlock']) {
  assert.ok(safetyScript.includes(control), `Missing safety UI control: ${control}`);
}
assert.ok(safetyScript.toLowerCase().includes('maxlength="1000"'), 'Report details should remain length-limited');
assert.ok(safetyScript.includes('auth.getUser('), 'Safety actions must check signed-in user context');
assert.ok(safetyScript.includes("type === 'user' && id === user.id"), 'The UI should prevent self-report attempts');
assert.ok(safetyScript.includes('ventSafetyModerator'), 'The moderator review control should exist');
assert.ok(safetyScript.includes('ventSafetyDashboard'), 'The moderator dashboard entry point should exist');
assert.ok(safetyScript.includes("window.location.href = 'moderator.html'"), 'The safety panel should link to the dashboard');
assert.ok(moderatorPage.includes('data-tab="accounts"') && moderatorPage.includes('data-tab="content"') && moderatorPage.includes('data-tab="systems"'), 'Dashboard should expose account, content, and systems tabs');
assert.ok(moderatorPage.includes("client.rpc('moderator_dashboard_overview'") || moderatorPage.includes("rpc('moderator_dashboard_overview'"), 'Dashboard should load guarded overview data');
assert.ok(moderatorPage.includes('function updateUserPagination()'), 'Account pagination controls should have a shared state updater');
assert.ok(moderatorPage.includes("p_limit:51,p_offset:userOffset"), 'Account query should fetch one extra row to detect whether another page exists');
assert.ok(moderatorPage.includes('userHasNext=data.length>50'), 'Next page should only be enabled when an extra account proves another page exists');
assert.ok(moderatorPage.includes('data.slice(0,50).forEach'), 'Account directory should display at most 50 accounts per page');
assert.ok(moderatorPage.includes('if(!userHasNext)return'), 'Account pagination must prevent advancing past the last page');
assert.ok(!moderatorPage.includes('service_role') && !moderatorPage.includes('sb_secret_'), 'Dashboard must not ship service-role or secret keys');
for (const fn of ['moderator_dashboard_overview', 'moderator_list_users', 'moderator_list_recent_posts']) {
  assert.ok(dashboardMigration.includes(`function public.${fn}(`), `Missing dashboard RPC ${fn}`);
  assert.ok(dashboardMigration.includes(`grant execute on function public.${fn}`), `Missing authenticated execute grant for ${fn}`);
}
assert.ok(dashboardMigration.includes("using errcode = '42501'"), 'Dashboard RPCs must reject non-moderators');
assert.ok(dashboardMigration.includes("set search_path = ''"), 'Dashboard RPCs must pin an empty search_path');
assert.ok(dashboardMigration.includes('left(trim(coalesce(p_query, \'\')), 120)'), 'Search terms must be length-limited');
assert.ok(safetyScript.includes("client.rpc('moderator_list_reports'"), 'The moderator panel should use the protected report-list RPC');
assert.ok(safetyScript.includes("client.rpc('moderator_update_report'"), 'The moderator panel should use the protected report-update RPC');
assert.ok(moderatorPage.includes("rpc('moderator_list_reports_page'") && moderatorPage.includes('p_limit:51,p_offset:reportOffset'), 'Report queue should use a paginated protected RPC with a lookahead row');
assert.ok(moderatorPage.includes('reportHasNext=data.length>50') && moderatorPage.includes('visibleReports=data.slice(0,50)'), 'Report queue should display at most 50 rows and detect a next page');
assert.ok(moderatorPage.includes("$('reportFilter').addEventListener('change',()=>{reportOffset=0;loadReports()})"), 'Changing report status should reset report pagination');
assert.ok(reportPaginationMigration.includes('function public.moderator_list_reports_page('), 'Missing paginated moderator report RPC');
assert.ok(reportPaginationMigration.includes('security definer') && reportPaginationMigration.includes("set search_path = ''"), 'Paginated report RPC must be hardened');
assert.ok(reportPaginationMigration.includes("using errcode = '42501'"), 'Paginated report RPC must reject non-moderators');
assert.ok(reportPaginationMigration.includes('offset greatest(0, least(coalesce(p_offset, 0), 1000000))'), 'Report offset must be bounded');
assert.ok(reportPaginationMigration.includes('revoke all on function public.moderator_list_reports_page(text, integer, integer) from public, anon'), 'Paginated RPC must revoke public and anonymous execution');
assert.ok(reportPaginationMigration.includes('grant execute on function public.moderator_list_reports_page(text, integer, integer) to authenticated'), 'Paginated RPC should be callable by authenticated clients, with moderator checks inside');
assert.ok(moderatorMigration.includes('create table if not exists private.moderators'), 'Missing private moderator allowlist');
assert.ok(moderatorMigration.includes('revoke all on table private.moderators from public, anon, authenticated'), 'Moderator allowlist must not be client-readable');
assert.ok(moderatorMigration.includes('grant execute on function public.moderator_list_reports(text, integer) to authenticated'), 'Authenticated clients need only the guarded report-list RPC');
assert.ok(moderatorMigration.includes('grant execute on function public.moderator_update_report(uuid, text, text) to authenticated'), 'Authenticated clients need only the guarded report-update RPC');
for (const fn of ['moderator_list_reports', 'moderator_update_report']) {
  assert.ok(moderatorMigration.includes(`function public.${fn}(`) && moderatorMigration.includes('security definer') && moderatorMigration.includes("set search_path = ''"), `Missing hardened moderator RPC: ${fn}`);
}
assert.ok(moderatorMigration.includes("using errcode = '42501'"), 'Moderator RPCs must reject non-moderators');
assert.ok(safetyScript.includes('Their profile, posts, and interactions are filtered while you are signed in'), 'Block confirmation should describe active database filtering');

// The database-level block migration must retain every restrictive policy.
for (const policy of [
  "Blocked accounts cannot view each other's profiles",
  "Blocked accounts cannot view each other's posts",
  "Blocked accounts cannot view each other's comments",
  "Blocked accounts cannot comment on each other's posts",
  'Blocked accounts cannot read conversation messages',
  'Blocked accounts cannot send conversation messages',
  "Blocked accounts cannot like each other's posts",
  "Blocked accounts cannot follow each other",
  "Blocked accounts cannot view each other's likes",
  "Blocked accounts cannot view each other's follows"
]) {
  assert.ok(blockMigration.includes(policy), `Missing block enforcement policy: ${policy}`);
}
for (const fn of ['is_post_author_blocked', 'is_conversation_blocked']) {
  assert.ok(blockMigration.includes(`function private.${fn}(`), `Missing private helper ${fn}`);
}
assert.ok(
  blockMigration.toLowerCase().includes('security definer') &&
  blockMigration.includes("set search_path = ''"),
  'Privileged block-check helpers must pin an empty search_path'
);
assert.ok(
  blockMigration.includes('revoke all on function private.is_post_author_blocked(uuid) from public, anon'),
  'Post helper must not be executable by PUBLIC or anon'
);
assert.ok(
  blockMigration.includes('revoke all on function private.is_conversation_blocked(uuid) from public, anon'),
  'Conversation helper must not be executable by PUBLIC or anon'
);

const syntax = spawnSync(process.execPath, ['--check', 'scripts/trust-safety.js'], { encoding: 'utf8' });
assert.equal(syntax.status, 0, syntax.stderr || 'Safety script syntax check failed');
console.log('Trust & safety regression checks passed.');
