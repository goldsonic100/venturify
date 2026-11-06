import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('postmortems.html');
const migration = read('supabase/migrations/20261105090000_create_founder_postmortems.sql');
const revisionMigration = read('supabase/migrations/20261106120000_allow_founder_postmortem_revisions.sql');
const indexMigration = read('supabase/migrations/20261106121500_index_founder_postmortem_reviewed_by.sql');
const moderator = read('moderator-postmortems.html');

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
