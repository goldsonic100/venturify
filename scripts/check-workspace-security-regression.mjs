import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const migrationDir = 'supabase/migrations';
const files = [
  '20261023230000_limit_workspace_message_insert_columns.sql',
  '20261023231000_restrict_workspace_activity_event_writes.sql',
  '20261023222000_limit_workspace_milestone_update_columns.sql',
  '20261023223000_limit_workspace_task_update_columns.sql',
  '20261023224000_limit_workspace_checklist_update_columns.sql',
  '20261023225000_limit_workspace_comment_update_columns.sql',
];

for (const file of files) {
  const sql = readFileSync(`${migrationDir}/${file}`, 'utf8').toLowerCase();
  assert.match(sql, /revoke/, `${file} must revoke broad privileges`);
  assert.match(sql, /authenticated/, `${file} must address authenticated clients`);
}
assert.match(readFileSync(`${migrationDir}/20261023230000_limit_workspace_message_insert_columns.sql`, 'utf8').toLowerCase(), /grant insert\s*\(workspace_id, sender_id, content\)/);
assert.match(readFileSync(`${migrationDir}/20261023231000_restrict_workspace_activity_event_writes.sql`, 'utf8').toLowerCase(), /revoke insert, update, delete/);
console.log('Workspace security migration regression checks passed.');