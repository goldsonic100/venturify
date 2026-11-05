import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { Script } from 'node:vm';

const migration = readFileSync('supabase/migrations/20261105090000_create_founder_postmortems.sql', 'utf8');
const submissionPage = readFileSync('submit-postmortem.html', 'utf8');
const reviewPage = readFileSync('moderator-postmortems.html', 'utf8');
const libraryPage = readFileSync('case-studies.html', 'utf8');

for (const required of [
  'create table if not exists public.founder_postmortems',
  'enable row level security',
  'Authors can view their own post-mortem submissions',
  'Authors can submit consented post-mortems as themselves',
  "status = 'pending'",
  "consent_to_publish is true",
  'function public.withdraw_my_founder_postmortem',
  'function public.list_published_founder_postmortems',
  "s.status = 'approved' and s.consent_to_publish is true",
  "s.company_visibility = 'public'",
  "s.author_display_mode = 'profile'",
  'function public.moderator_list_founder_postmortems',
  'function public.moderator_review_founder_postmortem',
  'private.moderators m where m.user_id = (select auth.uid())',
  'revoke all on table public.founder_postmortems from public, anon, authenticated',
  'revoke all on function public.moderator_review_founder_postmortem(uuid, text, text) from public, anon'
]) assert.ok(migration.includes(required), `Missing migration safeguard: ${required}`);

for (const required of ['consent_to_publish', 'postmortem-consent-v1', 'author_display_mode', 'company_visibility', 'founder_postmortems', 'form.reportValidity()']) {
  assert.ok(submissionPage.includes(required), `Submission form missing ${required}`);
}
for (const required of ['moderator_list_founder_postmortems', 'moderator_review_founder_postmortem', 'private moderator notes', 'needs_edits', 'approved']) {
  assert.ok(reviewPage.includes(required), `Moderator page missing ${required}`);
}
assert.ok(!libraryPage.includes('BrightCart') && !libraryPage.includes('Northline Commerce'), 'The public library must not contain fabricated founder stories');
for (const [file, html] of [['submit-postmortem.html', submissionPage], ['moderator-postmortems.html', reviewPage]]) {
  for (const match of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script\s*>/gi)) {
    const source = match[1].trim();
    if (source) new Script(source, { filename: file });
  }
}
console.log('Founder post-mortem contract checks passed.');
