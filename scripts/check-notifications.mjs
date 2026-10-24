import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../notifications.html', import.meta.url), 'utf8');
const updatePolicy = readFileSync(
  new URL('../supabase/migrations/20261021170000_restrict_notification_updates.sql', import.meta.url),
  'utf8',
);

const scripts = [...page.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
  .map(([, source]) => source.trim())
  .filter(Boolean);
assert.ok(scripts.length, 'Notifications page must contain application scripts');
scripts.forEach((source, index) => {
  try { new Function(source); }
  catch (error) { throw new Error('notifications.html inline script ' + (index + 1) + ' failed to parse: ' + error.message); }
});

for (const [pattern, message] of [
  [/notificationClient\.from\('notifications'\)/, 'Notification feed must use persisted notifications'],
  [/\.eq\('recipient_id',notificationUser\.id\)/, 'Notification queries must be scoped to the signed-in recipient'],
  [/id="markAllNotifications"/, 'Users must be able to mark notifications as read'],
  [/id="notificationHistoryList"/, 'The full notification history must remain available'],
  [/id="loadOlderNotifications"/, 'The history must retain its older-notification pagination control'],
  [/data-notification-type=/, 'Notification items must preserve typed actions'],
  [/data-notification-task=/, 'Task-linked notifications must retain task context'],
  [/task_completed/, 'Task-completion notifications must remain supported'],
  [/checklist_completed/, 'Checklist-completion notifications must remain supported'],
  [/workspace\.html\?request=/, 'Collaboration/task notifications must deep-link to their workspace'],
  [/aria-live="polite"/, 'Notification updates must remain accessible to assistive technology'],
]) assert.match(page, pattern, message);

assert.match(updatePolicy, /revoke update on table public\.notifications from anon, authenticated/i,
  'Clients must not receive broad notification update privileges');
assert.match(updatePolicy, /grant update \(read_at\) on table public\.notifications to authenticated/i,
  'Authenticated clients should only update the read marker directly');

console.log('Notification-center regression checks passed (static checks only; no live account is accessed).');
