import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('workspace.html');
const sql = read('supabase/tests/venturify_security_smoke_checks.sql');
for (const contract of ['id="realtimeStatus"','id="workspacePresence"','id="refreshRealtimeData"','workspace_id','partnerId','collaboration_requests']) {
  assert.ok(page.includes(contract), 'Workspace page is missing contract: ' + contract);
}
for (const contract of ['workspace_chat_has_single_notification_trigger','workspace_created_notification_has_single_source','collaboration_acceptance_workspace_trigger_enabled']) {
  assert.ok(sql.includes("'" + contract + "'"), 'Security smoke suite is missing: ' + contract);
}
console.log('Phase 1 workspace realtime contract checks passed.');
