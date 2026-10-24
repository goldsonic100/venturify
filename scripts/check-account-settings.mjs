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
assert.ok(schema.includes('get_discoverable_founder_ids'), 'Discover privacy must be enforced in the database');
assert.ok(schema.includes('get_messageable_founder_ids'), 'Direct-message privacy must be enforced in the database');
assert.match(schema, /grant execute on function public\.get_messageable_founder_ids\(\) to authenticated/i,
  'Messageable-founder lookup must not be granted to anonymous users');
assert.match(enforcement, /private\.can_receive_collaboration_requests/i,
  'Collaboration request preferences must be enforced server-side');

// Private-DM preference semantics: the recipient must follow the sender when
// public DMs are disabled. Test both the inbox RPC and group-chat RPC so they
// cannot drift in opposite directions.
const privateDmFix = readFileSync(
  new URL('../supabase/migrations/20261024230000_fix_private_dm_follow_direction.sql', import.meta.url),
  'utf8',
);
assert.match(page, /only founders who follow you can start a new DM with you/i,
  'The private-DM setting must explain that recipients follow senders');
assert.match(privateDmFix, /f\.follower_id = p\.id\s+and f\.following_id = \(select auth\.uid\(\)\)/i,
  'Messageable-founder lookup must require the recipient to follow the current sender');
assert.match(privateDmFix, /f\.follower_id = candidate\.user_id\s+and f\.following_id = current_user_id/i,
  'Group-chat creation must enforce the same recipient-follows-sender direction');
assert.match(privateDmFix, /c\\.is_group = false/i,
  'The messageable-founder lookup must preserve access to existing direct conversations');

console.log('Account-settings security regression checks passed (static checks only).');
