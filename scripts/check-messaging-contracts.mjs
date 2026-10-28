import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const source0 = read('messages.html');
assert.ok(source0.includes("id=\"sendMessage\""), "messages.html is missing contract: id=\"sendMessage\"");
assert.ok(source0.includes("id=\"messagePerson\""), "messages.html is missing contract: id=\"messagePerson\"");
assert.ok(source0.includes("id=\"messageStatus\""), "messages.html is missing contract: id=\"messageStatus\"");
assert.ok(source0.includes("group:"), "messages.html is missing contract: group:");
assert.ok(source0.includes("people.filter(p=>messageableFounderIds.has(p.id))"), "New group chat must only offer messageable founders.");
assert.ok(source0.includes("get_messageable_founder_ids"), "Chat recipient choices must use the server messageability policy.");
assert.ok(source0.includes("const handle=p=>p?.username||(p?.id?"), "Missing usernames should have a stable visible fallback.");
const profileDisplayPages = ['feed.html','discover.html','profile.html','communities.html','notifications.html','index.html','messages.html'];
for (const path of profileDisplayPages) {
  const html = read(path);
  assert.ok(html.includes("p?.username||(p?.id?'user_'+String(p.id).replace(/-/g,'').slice(0,8).toLowerCase():'founder')") || html.includes("p.username||(p.id?'user_'+String(p.id).replace(/-/g,'').slice(0,8).toLowerCase():'founder')"), path + ' should not display the generic @founder handle when a profile username is missing');
}
const source1 = read('supabase/tests/venturify_security_smoke_checks.sql');
assert.ok(source1.includes("block_guards_for_messages"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: block_guards_for_messages");
assert.ok(source1.includes("messageable_founder_rpc_and_dm_preference_guard"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: messageable_founder_rpc_and_dm_preference_guard");
assert.ok(source1.includes("message_notification_preference_enabled"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: message_notification_preference_enabled");
assert.ok(source1.includes("message_recipient_notification_trigger_enabled"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: message_recipient_notification_trigger_enabled");

assert.ok(source0.includes("people.filter(p=>messageableFounderIds.has(p.id)).map(p=>"), "New group chat must only list message-eligible founders");
assert.ok(source0.includes("participant_ids.some(id=>!messageableFounderIds.has(id))"), "Group chat must revalidate selected participants before creating the group");
assert.ok(source0.includes("No eligible founders yet — follow someone or choose a founder who accepts DMs."), "Group chat should explain when no eligible recipients are available");
console.log("Phase 1 messaging-privacy contract checks passed.");
