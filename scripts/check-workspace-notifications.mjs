import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const read = (path) => readFile(new URL(path, import.meta.url), "utf8");
const [workspace, notifications, taskMigration, messageMigration, indexes] = await Promise.all([
  read("../workspace.html"),
  read("../notifications.html"),
  read("../supabase/migrations/20261021012647_consolidate_workspace_notifications.sql"),
  read("../supabase/migrations/20261021160000_remove_duplicate_workspace_message_notification_trigger.sql"),
  read("../supabase/migrations/20261020320000_notification_feed_indexes.sql"),
]);

const checks = [
  ["workspace deep links accept the collaboration request and task ID", () => {
    assert.match(workspace, /params\.get\('request'\)/);
    assert.match(workspace, /params\.get\('task'\)/);
    assert.match(workspace, /\.eq\('status','accepted'\)/);
    assert.match(workspace, /req\.requester_id,\s*req\.recipient_id\]\s*\.includes\(user\.id\)/);
  }],
  ["workspace task links preserve request and task identifiers", () => {
    assert.match(notifications, /'workspace\.html\?request='\s*\+\s*encodeURIComponent\(collaborationId\)/);
    assert.match(notifications, /'&task='\s*\+\s*encodeURIComponent\(taskId\)/);
  }],
  ["notification read updates are scoped to the signed-in recipient", () => {
    assert.match(notifications, /\.update\(\{read_at:new Date\(\)\.toISOString\(\)\}\)\.eq\('id',id\)\.eq\('recipient_id',notificationUser\.id\)/);
    assert.match(notifications, /\.eq\('recipient_id',notificationUser\.id\)\.is\('read_at',null\)/);
  }],
  ["task notification migration retains completion types and one canonical trigger", () => {
    assert.match(taskMigration, /'task_completed','checklist_completed'/);
    assert.match(taskMigration, /drop trigger if exists notify_workspace_task_activity/i);
    assert.match(taskMigration, /drop trigger if exists workspace_task_notifications/i);
    assert.match(taskMigration, /create trigger workspace_task_change_notifications/i);
    assert.match(taskMigration, /revoke all on function public\.notify_workspace_task_changes\(\) from public, anon, authenticated/i);
  }],
  ["workspace chat notification migration removes only the redundant legacy trigger", () => {
    assert.match(messageMigration, /drop trigger if exists workspace_message_notifications/i);
    assert.match(messageMigration, /on public\.workspace_messages/i);
    assert.doesNotMatch(messageMigration, /drop trigger if exists notify_project_chat_message/i);
  }],
  ["notification feed has chronological and unread indexes", () => {
    assert.match(indexes, /notifications_recipient_created_at_idx/i);
    assert.match(indexes, /notifications_recipient_unread_idx/i);
    assert.match(indexes, /where read_at is null/i);
  }],
];

let failed = 0;
for (const [name, check] of checks) {
  try {
    check();
    console.log(`PASS ${name}`);
  } catch (error) {
    failed += 1;
    console.error(`FAIL ${name}\n  ${error.message}`);
  }
}
console.log(`Workspace notification regression checks: ${checks.length - failed}/${checks.length} passed.`);
if (failed) process.exitCode = 1;
