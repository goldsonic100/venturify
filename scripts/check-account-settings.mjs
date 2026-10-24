import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../settings.html', import.meta.url), 'utf8');
const schema = readFileSync(
  new URL('../supabase/migrations/20261022120000_add_account_settings_and_message_privacy.sql', import.meta.url),
  'utf8',
);
const enforcement = readFileSync(
  new URL('../supabase/migrations/20261022140000_enforce_account_feature_preferences.sql', import.meta.url),
  'utf8',
);

const scripts = [...page.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
  .map(([, source]) => source.trim()).filter(Boolean);
assert.ok(scripts.length, 'Settings page must contain application scripts');
scripts.forEach((source, index) => {
  try { new Function(source); }
  catch (error) { throw new Error('settings.html inline script ' + (index + 1) + ' failed to parse: ' + error.message); }
});

for (const setting of [
  'public_profile', 'public_dms', 'allow_collaboration_requests', 'show_in_discover',
  'enable_story_posts', 'enable_polls', 'enable_opportunities', 'notify_messages',
  'notify_reactions', 'notify_group_mentions'
]) assert.ok(page.includes('data-setting="' + setting + '"'), 'Missing account preference control: ' + setting);

assert.match(page, /from\('account_settings'\)/, 'Settings must load/save persisted preferences');
assert.match(page, /id="saveSettings"/, 'Settings must retain an explicit save action');
assert.match(page, /beforeunload/, 'Settings must warn about unsaved changes');
assert.match(page, /aria-live="polite"/, 'Settings status must be accessible');
assert.match(schema, /create table if not exists public\.account_settings/i, 'Account preferences need a dedicated table');
assert.match(schema, /alter table public\.account_settings enable row level security/i, 'Account preferences must use RLS');
for (const op of ['select', 'insert', 'update']) {
  assert.match(schema, new RegExp('for ' + op + ' to authenticated', 'i'),
    'Account preference ' + op + ' policy must target authenticated users');
}
assert.match(schema, /auth\.uid\(\)/i, 'Account preference policies must bind access to the current user');
assert.match(schema, /appearance text not null default 'system' check \(appearance in \('system','light','dark'\)\)/i,
  'Appearance preference must be constrained to supported modes');
assert.match(enforcement, /create or replace function public\.get_discoverable_founder_ids/i,
  'Discover privacy must be enforced in the database');
assert.match(enforcement, /create or replace function public\.get_messageable_founder_ids/i,
  'Direct-message privacy must be enforced in the database');
assert.match(enforcement, /grant execute on function public\.get_messageable_founder_ids\(\) to authenticated/i,
  'Messageable-founder lookup must not be granted to anonymous users');
assert.match(enforcement, /private\.can_receive_collaboration_requests/i,
  'Collaboration request preferences must be enforced server-side');

console.log('Account-settings security regression checks passed (static checks only).');
