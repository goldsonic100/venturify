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
assert.ok(messages.includes("new URLSearchParams(window.location.search).get('conversation')"), 'Conversation deep links must read the conversation query parameter');
assert.ok(messages.includes("new URLSearchParams(window.location.search).get('conversation')"), 'Conversation deep links must read the conversation query parameter');

console.log('Messaging feature smoke checks passed. Note: these static checks do not replace two-account browser testing.');

assert.ok(messages.includes('id="conversationList" class="conversation-list" role="region" aria-label="Conversation inbox" aria-live="polite" aria-busy="false"'), 'Inbox should expose a named accessible live region');
assert.ok(messages.includes("box.setAttribute('aria-busy','true')") && messages.includes("box.setAttribute('aria-busy','false');filteredConversationList()"), 'Inbox loading state should be set and cleared during conversation loading');

assert.ok(messages.includes('id="conversationSearchStatus" class="muted-small" role="status" aria-live="polite" aria-atomic="true"'), 'Conversation search should announce result counts accessibly');
assert.ok(messages.includes("No conversations match your search.") && messages.includes(" of '+buttons.length+' conversations match your search."), 'Conversation search should announce both matches and empty results');


assert.ok(messages.includes("document.addEventListener('visibilitychange'") && messages.includes("document.visibilityState!=='visible'||!user"), 'Inbox must refresh its unread/conversation snapshot when a signed-in user returns to the tab');
assert.ok(messages.includes("window.addEventListener('focus',()=>{if(user)loadConversationList()})"), 'Inbox must refresh conversations when the browser window regains focus');
