import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const messages = readFileSync(new URL('../messages.html', import.meta.url), 'utf8');
const migration = readFileSync(new URL('../supabase/migrations/20261022190000_message_delivery_notifications.sql', import.meta.url), 'utf8');
const notifications = readFileSync(new URL('../notifications.html', import.meta.url), 'utf8');

for (const [name, pattern] of [
  ['conversation membership lookup', /from\('conversation_members'\)/],
  ['persistent message insert', /from\('messages'\)\.insert\(/],
  ['paged conversation history', /\.range\(historyOffset,historyOffset\+499\)/],
  ['scrollable transcript', /chat-message-list[\s\S]{0,220}overflow-y:auto/],
  ['persistent message reactions', /from\('message_reactions'\)/],
  ['group conversation creation', /create_group_conversation/],
  ['live message updates', /postgres_changes[\s\S]{0,180}table:'messages'/],
  ['read receipts', /from\('message_reads'\)/],
  ['mobile inbox back control', /id="mobileInboxBack"/]
]) assert.match(messages, pattern, `Missing messaging feature: ${name}`);

assert.match(migration, /notify_conversation_message_after_insert/);
assert.match(migration, /coalesce\(settings\.notify_messages, true\)/);
assert.match(migration, /private\.is_conversation_blocked/);
assert.match(migration, /add column if not exists conversation_id/);
assert.match(notifications, /type==='message'/);
assert.match(notifications, /data-notification-conversation/);
assert.match(notifications, /'messages\.html'\+\(conversationId\?/);
assert.match(messages, /searchParams\.get\('conversation'\)/);
assert.match(messages, /openGroupConversation\(conversationId\)/);

console.log('Messaging feature smoke checks passed. Note: these static checks do not replace two-account browser testing.');
