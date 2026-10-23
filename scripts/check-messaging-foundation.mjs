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


assert.ok(messages.includes('globalMessageRetryDelay=1500') && messages.includes('Math.min(Math.round(globalMessageRetryDelay*1.7),30000)'), 'Inbox realtime recovery must use bounded retry backoff');
assert.ok(messages.includes('scheduleGlobalMessageReconnect(uid)') && messages.includes('Inbox live updates interrupted; reconnecting automatically'), 'Inbox realtime errors must trigger automatic recovery feedback');
assert.ok(messages.includes("status==='CLOSED'") && messages.includes("status==='SUBSCRIBED'"), 'Inbox realtime recovery must handle closed and successfully restored channels');


assert.ok(messages.includes("document.addEventListener('visibilitychange'") && (messages.includes("document.visibilityState!=='visible'||!user") || messages.includes("document.visibilityState==='visible')refreshMessagingView()")), 'Inbox must refresh its unread/conversation snapshot when a signed-in user returns to the tab');
assert.ok(messages.includes("window.addEventListener('focus',()=>{if(user)loadConversationList()})") || messages.includes("window.addEventListener('focus',refreshMessagingView)"), 'Inbox must refresh conversations when the browser window regains focus');


assert.ok(messages.includes('class="conversation-unread" aria-label="\'+item.unread+\' unread messages"'), 'Unread badges must expose an accessible unread-message count');


assert.ok(messages.includes("box.setAttribute('aria-busy','true');if(!box.querySelector('.conversation-item'))box.innerHTML='<div class=\"muted-small\">Loading conversations…</div>';"), 'Inbox refresh should preserve existing conversation rows instead of flashing a loading placeholder');


assert.ok(messages.includes('function refreshMessagingView(){if(!user)return;loadConversationList();if(!globalMessageChannel)startGlobalMessageRealtime(user.id);if(currentConversation&&activeConversationOtherId){showMessages(activeConversationOtherId);loadTypingStatus()}}'), 'Returning to the messages page should refresh the open transcript and typing state as well as inbox counts');
assert.ok(messages.includes("document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')refreshMessagingView()})") && messages.includes("window.addEventListener('focus',refreshMessagingView)"), 'Inbox and active chat should refresh on both tab visibility and window focus');


assert.ok(messages.includes('id="messageUnreadStatus" class="muted-small" role="status" aria-live="polite" aria-atomic="true"'), 'Inbox unread-count fallback should be announced accessibly');
assert.ok(messages.includes("unreadStatus.textContent='Unread counts are temporarily unavailable. Your conversations are still accessible.'") && messages.includes("else if(unreadStatus)unreadStatus.textContent=''"), 'Inbox must distinguish unread-count RPC failures from a genuinely empty unread count and clear the warning after recovery');


assert.ok(messages.includes('id="messageReadStatus" class="muted-small" role="status" aria-live="polite" aria-atomic="true"'), 'Conversation read-receipt feedback should be announced accessibly');
assert.ok(messages.includes("readStatus.textContent=readReceiptError?'Could not update read status. Reopen this conversation to retry.':''"), 'Conversation should expose read-receipt failures and clear the status after a successful retry');


assert.ok(messages.includes('id="messageCharacterCount" class="muted-small" role="status" aria-live="polite" aria-atomic="true"'), 'Message composer should expose an accessible character counter');
assert.ok(messages.includes("messageCharacterCount.textContent=$('messageText').value.length+' / 1200'"), 'Message character count should track the current draft length');
assert.ok(messages.includes("$('messageText').value='';updateMessageCharacterCount()"), 'Character counter should reset when a message is successfully sent');


assert.ok(messages.includes("table:'messages'},()=>loadConversationList())"), 'Inbox should refresh when the signed-in user sends a message from another device or tab');
assert.ok(messages.includes("table:'message_reads'},()=>loadConversationList())"), 'Inbox should refresh when another participant reads a message and creates a receipt');
assert.ok(!messages.includes("table:'messages',filter:'sender_id=neq.'+uid") && !messages.includes("table:'message_reads',filter:'user_id=eq.'+uid"), 'Inbox realtime subscriptions must not filter out the current user’s cross-device messages or other users’ read receipts');
