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
  [/data-notification-filter="comment"/, 'The notification history must offer a dedicated comments-and-replies filter'],
  [/comment:'commented on your post or replied in its discussion'/, 'Comment notifications must clearly cover both top-level comments and replies'],
  [/feed\.html\?view=feed#post-.*encodeURIComponent\(postId\)/, 'Post-linked notifications must open the exact discussion instead of only scrolling to the feed section'],
  [/task_completed/, 'Task-completion notifications must remain supported'],
  [/checklist_completed/, 'Checklist-completion notifications must remain supported'],
  [/workspace\.html\?request=/, 'Collaboration/task notifications must deep-link to their workspace'],
  [/collaboration_message:'sent you a message about a collaboration proposal'/, 'Proposal discussion notifications must have clear wording'],
  [/type==='collaboration_message'&&collaborationId/, 'Proposal discussion notifications must open the correct negotiation thread'],
  [/collaborations\.html\?request=/, 'Proposal discussion notifications must deep-link to the matching discussion'],
  [/aria-live="polite"/, 'Notification updates must remain accessible to assistive technology'],
]) assert.match(page, pattern, message);

assert.match(updatePolicy, /revoke update on table public\.notifications from anon, authenticated/i,
  'Clients must not receive broad notification update privileges');
assert.match(updatePolicy, /grant update \(read_at\) on table public\.notifications to authenticated/i,
  'Authenticated clients should only update the read marker directly');

const loaderStart=page.indexOf('async function loadNotifications(options={})');
const loaderEnd=page.indexOf('function stopNotificationRealtime()',loaderStart);
const loader=page.slice(loaderStart,loaderEnd);
assert.ok(loader.includes('try{') && loader.includes('finally{') && loader.includes('loading=false;') && loader.includes("historyList.setAttribute('aria-busy','false')"), 'Notification loading must always release its busy state after thrown network failures');
assert.match(page, /Notification refresh threw; keeping the last loaded notifications visible/, 'A thrown background refresh must preserve the previously loaded notification list');
assert.match(page, /function showNotificationError\(targetId,message\)/, 'Notification action errors must be announced without replacing existing items');
assert.ok(page.includes("finally{markAllHistory.disabled=false}"), 'Mark-all-read controls must recover after thrown network errors');
assert.match(page, /try\{const r=await notificationClient\.from\('notifications'\)\.update\(\{read_at:new Date\(\)\.toISOString\(\)\}\)\.eq\('id',id\)/, 'Opening a notification must still navigate when marking it read throws');

console.log('Notification-center regression checks passed (static checks only; no live account is accessed).');
