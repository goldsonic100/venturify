import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const discover = read('discover.html');
const settings = read('settings.html');
const messages = read('messages.html');
const notifications = read('notifications.html');
const collaborations = read('collaborations.html');
const workspace = read('workspace.html');

// Discover must exclude the signed-in user, empty profiles, people outside
// communities, and accounts below reputation Level 5.
assert.match(discover, /rows\.filter\(p=>p\.id!==currentUser\?\.id&&hasProfileInfo\(p\)&&\(communityCounts\.get\(p\.id\)\|\|0\)>=1&&founderLevel\(p\)>=5\)/,
  'Discover must enforce profile completeness, community membership, and Level 5+');
assert.match(discover, /dailyMatchIds\.includes\(p\.id\)/,
  'Signed-in Discover results must respect the daily personalized match list');

// Settings must have real section navigation, accessible switches, and a
// persisted account_settings upsert rather than only local visual state.
assert.ok(settings.includes('settings-section-navigation'), 'Settings section navigation script is missing');
assert.ok(settings.includes('data-section'), 'Settings section controls are missing');
assert.ok(settings.includes('role="switch"'), 'Settings toggles must expose switch semantics');
assert.ok(settings.includes('data-setting='), 'Settings controls must have stable setting keys');
assert.match(settings, /from\(['"]account_settings['"]\)\.upsert\(payload,\{onConflict:['"]user_id['"]\}\)/,
  'Settings must persist changes to account_settings keyed by user_id');
assert.ok(settings.includes('Settings saved.'), 'Settings should confirm a successful save');
assert.ok(settings.includes('role="status" aria-live="polite"'), 'Settings should announce save errors and success');

// Messaging and collaboration surfaces should retain usable status announcements
// and the controls needed for the account-to-account workflows.
assert.ok(messages.includes('id="sendMessage"'), 'Message composer send control is missing');
assert.ok(messages.includes('id="messageStatus" role="status" aria-live="polite"'),
  'Messaging must announce send and privacy status accessibly');
assert.ok(messages.includes('id="messagePerson"'), 'Direct-message recipient selector is missing');
assert.ok(messages.includes('group:'), 'Group conversation handling is missing');
assert.ok(notifications.includes('notificationPageSize'), 'Notification history should remain paginated');
assert.ok(notifications.includes('refreshNotificationHistory'), 'Notification history refresh control is missing');
assert.ok(notifications.includes('markVisibleHistoryRead'), 'Notification history bulk-read control is missing');
assert.ok(collaborations.includes('id="requests"'), 'Collaboration request list is missing');
assert.ok(collaborations.includes('aria-live="polite"'), 'Collaboration requests should announce loading/results');
assert.ok(workspace.includes('id="realtimeStatus"'), 'Workspace should expose realtime connection status');
assert.ok(workspace.includes('aria-live="polite"'), 'Workspace updates should be accessible');

console.log('Phase 1 functional contract checks passed for Discover, Settings, Messaging, Notifications, and Collaboration.');
