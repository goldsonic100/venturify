import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const source0 = read('notifications.html');
assert.ok(source0.includes("notificationPageSize"), "notifications.html is missing contract: notificationPageSize");
assert.ok(source0.includes("refreshNotificationHistory"), "notifications.html is missing contract: refreshNotificationHistory");
assert.ok(source0.includes("markVisibleHistoryRead"), "notifications.html is missing contract: markVisibleHistoryRead");
assert.ok(source0.includes("loadOlderNotifications"), "notifications.html is missing contract: loadOlderNotifications");
assert.ok(source0.includes("notificationHistoryList"), "notifications.html is missing contract: notificationHistoryList");
assert.ok(source0.includes("aria-busy"), "notifications.html is missing contract: aria-busy");
const source1 = read('supabase/tests/venturify_security_smoke_checks.sql');
assert.ok(source1.includes("reaction_and_group_mention_notification_preferences_enabled"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: reaction_and_group_mention_notification_preferences_enabled");
assert.ok(source1.includes("message_notification_preference_enabled"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: message_notification_preference_enabled");

console.log("Phase 1 notification-history contract checks passed.");
