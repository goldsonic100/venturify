import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('postmortems.html');
const migration = read('supabase/migrations/20261105090000_create_founder_postmortems.sql');
const revisionMigration = read('supabase/migrations/20261106120000_allow_founder_postmortem_revisions.sql');
const indexMigration = read('supabase/migrations/20261106121500_index_founder_postmortem_reviewed_by.sql');
const reviewHistoryMigration = read('supabase/migrations/20261106220000_founder_postmortem_review_history.sql');
const moderator = read('moderator-postmortems.html');
const paginationMigration = read('supabase/migrations/20261107100000_paginate_moderator_postmortem_queue.sql');
const reviewNotificationMigration = read('supabase/migrations/20261106210000_notify_founder_postmortem_review.sql');
const indexPage = read('index.html');
const feedPage = read('feed.html');

for (const [index, match] of [...page.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].entries()) {
  const source = match[1].trim();
  if (source) assert.doesNotThrow(() => new Function(source), 'Post-mortem page inline script ' + (index + 1) + ' must parse');
}
for (const contract of [
  'list_published_founder_postmortems',
  'founder_postmortems',
  'withdraw_my_founder_postmortem',
  'revise_my_founder_postmortem',
  'data-revise',
  'cancelRevision',
  'needs_edits',
  'consent_version',
  'postmortem-consent-v1',
  'author_display_mode',
  'company_visibility',
  'aria-live="polite"',
  'id="storySearch"',
  'id="industryFilter"',
  'id="stageFilter"',
  'id="lessonFilter"',
  'minlength="40"',
  'maxlength="5000"',
  'id="publishConsent"',
]) assert.ok(page.includes(contract), 'Public post-mortem page is missing: ' + contract);

assert.match(page, /author_id:user\.id/, 'Submissions must be associated with the signed-in author');
assert.match(page, /consent_to_publish:\$\('publishConsent'\)\.checked/, 'Submissions must require explicit publication consent');
assert.match(page, /status.*pending|private until an authorized moderator/i, 'Submissions must remain private pending review');
assert.match(page, /replace\(\/\[&<>"'\]\/g/, 'User-supplied content must be HTML-escaped before rendering');

for (const contract of [
  'enable row level security',
  'Authors can view their own post-mortem submissions',
  'Authors can submit consented post-mortems as themselves',
  'list_published_founder_postmortems',
  'moderator_list_founder_postmortems',
  'moderator_review_founder_postmortem',
  'private.moderators',
  'set search_path = \'\'',
  'revoke all on table public.founder_postmortems from public, anon, authenticated',
]) assert.ok(migration.includes(contract), 'Post-mortem migration is missing security control: ' + contract);
assert.match(migration, /where s\.status = 'approved' and s\.consent_to_publish is true/i, 'Public RPC must only return approved, consented stories');
assert.match(migration, /case when s\.company_visibility = 'public' then s\.company_name else '' end/i, 'Public RPC must hide company names when requested');
assert.match(migration, /case when s\.author_display_mode = 'profile'.*?else 'Anonymous founder' end/is, 'Public RPC must respect anonymous attribution');
assert.match(moderator, /moderator_list_founder_postmortems/, 'Moderator review queue must use the protected moderator RPC');
assert.match(moderator, /moderator_review_founder_postmortem/, 'Moderator review decisions must use the protected review RPC');
assert.match(page, /client\.rpc\('revise_my_founder_postmortem'/, 'Authors must be able to resubmit edit-requested stories');
assert.match(page, /publishConsent'\)\.checked=false/, 'Revisions must require the author to confirm publication consent again');
for (const contract of ['auth.uid()', "status = 'needs_edits'", "status = 'pending'", 'consent_at = now()', "revoke all on function public.revise_my_founder_postmortem", 'to authenticated']) assert.ok(revisionMigration.includes(contract), 'Revision RPC is missing author/consent boundary: ' + contract);
assert.match(indexMigration, /create index if not exists founder_postmortems_reviewed_by_idx/i, 'Reviewer foreign key must have a supporting index');
assert.match(revisionMigration, /where id = p_story_id[\s\S]*?author_id = \(select auth\.uid\(\)\)[\s\S]*?status = 'needs_edits'/, 'Revision RPC must update only the caller\'s needs_edits submission');

console.log('Founder post-mortem library checks passed (static checks only; live two-account review still required).');

for (const contract of ['founder_postmortem_id', "'postmortem_review'", 'notifications_founder_postmortem_id_idx', 'moderator_review_founder_postmortem', 'insert into public.notifications', "s.status in ("]) assert.ok(reviewNotificationMigration.includes(contract), 'Review notification migration is missing: ' + contract);
for (const source of [indexPage, feedPage]) {
 assert.match(source, /postmortem_review:'reviewed your founder post-mortem submission'/);
 assert.match(source, /founder_postmortem_id,actor:profiles/);
  assert.ok(source.includes('postmortems.html#mySubmissions'), 'Review notification must link to My submissions');
}

for (const contract of [
  'founder_postmortem_reviews',
  'enable row level security',
  'Authors and moderators can view post-mortem review history',
  'grant select on table public.founder_postmortem_reviews to authenticated',
  'revoke all on table public.founder_postmortem_reviews from public, anon, authenticated',
  'insert into public.founder_postmortem_reviews',
  'private.moderators',
  'set search_path = \'\'',
]) assert.ok(reviewHistoryMigration.includes(contract), 'Review history migration is missing: ' + contract);
assert.match(page, /from\('founder_postmortem_reviews'\)/, 'Authors must load their private review timeline');
assert.match(page, /reviewHistory/, 'Author submissions must render review history');
assert.match(page, /Review history/, 'Review history must be clearly labeled');

for (const contract of [
  'id="queueStatus"',
  'id="queueSearch"',
  "p_status: null, p_limit: 100",
  "from('founder_postmortem_reviews')",
  'Review history',
  "['pending', 'needs_edits'].includes(story.status)",
  "queueStatus').addEventListener('change', renderQueue)",
  "queueSearch').addEventListener('input', renderQueue)",
]) assert.ok(moderator.includes(contract), 'Moderator queue is missing: ' + contract);
assert.match(moderator, /\.filter\(story =>[\s\S]*story\.status === status/, 'Moderator status filters must apply to loaded submissions');
assert.match(moderator, /\.join\(' '\)\.toLowerCase\(\)\.includes\(term\)/, 'Moderator search must filter story and author text');
assert.match(moderator, /reviewHistory\.get\(story\.id\)/, 'Moderator cards must show prior review decisions');

for (const contract of [
  'moderator_list_founder_postmortems_page',
  "p_status: status, p_limit: pageSize, p_offset: pageOffset",
  'Load 100 more submissions',
  'pageOffset += stories.length',
  'hasMore = stories.length === pageSize',
  "queueStatus').addEventListener('change', () => loadQueuePage(true))",
]) assert.ok(moderator.includes(contract), 'Paginated moderator queue is missing: ' + contract);
for (const contract of [
  'private.moderators',
  "set search_path = ''",
  'greatest(1, least(coalesce(p_limit, 50), 100))',
  'greatest(0, least(coalesce(p_offset, 0), 100000))',
  'revoke all on function public.moderator_list_founder_postmortems_page(text, integer, integer) from public, anon',
  'grant execute on function public.moderator_list_founder_postmortems_page(text, integer, integer) to authenticated',
]) assert.ok(paginationMigration.includes(contract), 'Pagination migration is missing safeguard: ' + contract);
