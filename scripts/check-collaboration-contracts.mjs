import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('collaborations.html');
const sql = read('supabase/tests/venturify_security_smoke_checks.sql');
for (const contract of ['id="requests"','data-filter=','accept','decline','exportRequests']) {
  assert.ok(page.includes(contract), 'Collaboration page is missing contract: ' + contract);
}
for (const contract of ['collaboration_acceptance_workspace_trigger_enabled','no_duplicate_pending_collaboration_pairs','symmetric_pending_collaboration_index']) {
  assert.ok(sql.includes("'" + contract + "'"), 'Security smoke suite is missing: ' + contract);
}
console.log('Phase 1 collaboration request contract checks passed.');
