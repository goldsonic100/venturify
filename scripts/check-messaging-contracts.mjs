import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const source0 = read('messages.html');
assert.ok(source0.includes("id=\"sendMessage\""), "messages.html is missing contract: id=\"sendMessage\"");
assert.ok(source0.includes("id=\"messagePerson\""), "messages.html is missing contract: id=\"messagePerson\"");
assert.ok(source0.includes("id=\"messageStatus\""), "messages.html is missing contract: id=\"messageStatus\"");
assert.ok(source0.includes("group:"), "messages.html is missing contract: group:");
const source1 = read('supabase/tests/venturify_security_smoke_checks.sql');
assert.ok(source1.includes("block_guards_for_messages"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: block_guards_for_messages");
assert.ok(source1.includes("messageable_founder_rpc_and_dm_preference_guard"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: messageable_founder_rpc_and_dm_preference_guard");
assert.ok(source1.includes("message_notification_preference_enabled"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: message_notification_preference_enabled");
assert.ok(source1.includes("message_recipient_notification_trigger_enabled"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: message_recipient_notification_trigger_enabled");

console.log("Phase 1 messaging-privacy contract checks passed.");
