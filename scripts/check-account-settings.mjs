import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../settings.html', import.meta.url), 'utf8');
const schema = readFileSync(
  new URL('../supabase/migrations/20261022120000_add_account_settings_and_message_privacy.sql', import.meta.url),
  'utf8',
);
const accessMigration = readFileSync(
  new URL('../supabase/migrations/20261030184616_tighten_account_settings_access.sql', import.meta.url),
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
assert.match(page, /class="nav-icon-link settings-gear-link" aria-label="Settings"/, 'Settings navigation must be a clearly labeled gear icon.');
assert.match(page, /data-section="account"/, 'Account must be a dedicated Settings section.');
assert.match(page, /id="section-account"/, 'Account section panel must exist inside Settings.');
assert.match(page, /id="settingsLogout"/, 'Account section must retain the logout control.');
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
  new URL('../supabase/migrations/20261024215204_fix_private_dm_follow_direction.sql', import.meta.url),
  'utf8',
);
assert.match(page, /only founders who follow you can start a new DM with you/i,
  'The private-DM setting must explain that recipients follow senders');
assert.match(privateDmFix, /f\.follower_id = p\.id\s+and f\.following_id = \(select auth\.uid\(\)\)/i,
  'Messageable-founder lookup must require the recipient to follow the current sender');
assert.match(privateDmFix, /f\.follower_id = candidate\.user_id\s+and f\.following_id = current_user_id/i,
  'Group-chat creation must enforce the same recipient-follows-sender direction');
assert.match(privateDmFix, /c\.is_group = false/i,
  'The messageable-founder lookup must preserve access to existing direct conversations');


// Navigation and local appearance must remain available even when the Supabase CDN fails.
const navScriptIndex = page.indexOf('settings-section-navigation');
const supabaseScriptIndex = page.indexOf('supabase-js@2');
assert.ok(navScriptIndex >= 0, 'Settings must keep an independent section-navigation script');
assert.ok(supabaseScriptIndex >= 0 && navScriptIndex < supabaseScriptIndex,
  'Section navigation must be registered before loading the external Supabase client');
assert.match(page, /querySelectorAll\(['"]\[data-section\]['"]\)/,
  'Settings section navigation must bind to all section controls');
assert.match(page, /matchMedia\(['"]\(prefers-color-scheme:\s*dark\)['"]\)/,
  'Settings appearance must support the system color preference');
assert.match(page, /venturify-theme/,
  'Settings appearance must use the shared local theme preference');
assert.match(page, /window\.supabase\?\.createClient|window\.supabase\s*&&\s*window\.supabase\.createClient/,
  'Settings must safely handle a missing Supabase client library');

console.log('Account-settings security regression checks passed (static checks only).');

assert.match(accessMigration, /revoke all privileges on table public\.account_settings from anon/i,
  'Anonymous clients must not reach private account settings');
assert.match(accessMigration, /grant select, insert, update on table public\.account_settings to authenticated/i,
  'Signed-in users need only the read/create/update privileges used by settings');
assert.match(accessMigration, /for select\s+to authenticated\s+using \(\(select auth\.uid\(\)\) = user_id\)/i,
  'Settings reads must be restricted to the current authenticated user');
assert.match(accessMigration, /for insert\s+to authenticated\s+with check \(\(select auth\.uid\(\)\) = user_id\)/i,
  'Settings creation must be restricted to the current authenticated user');
assert.match(accessMigration, /for update\s+to authenticated\s+using \(\(select auth\.uid\(\)\) = user_id\)\s+with check \(\(select auth\.uid\(\)\) = user_id\)/i,
  'Settings updates must preserve row ownership');
assert.match(page, /id="section-features" hidden aria-hidden="true"/,
  'Inactive settings panels must start hidden to prevent content flash');
assert.match(page, /id="section-notifications" hidden aria-hidden="true"/,
  'Inactive notification settings must start hidden');
assert.match(page, /id="section-appearance" hidden aria-hidden="true"/,
  'Inactive appearance settings must start hidden');
assert.match(page, /id="section-security" hidden aria-hidden="true"/,
  'Inactive safety settings must start hidden');
assert.match(page, /event==='SIGNED_IN'\|\|event==='SIGNED_OUT'/,
  'Settings must not reload on token refresh and overwrite unsaved edits');
assert.match(page, /if\(!dirty\)\{setStatus\('Your settings are already saved\.'/,
  'Save action must avoid unnecessary writes when there are no changes');
assert.match(page, /You have unsaved settings\. Log out without saving them\?/,
  'Logging out must confirm before discarding unsaved preferences');
