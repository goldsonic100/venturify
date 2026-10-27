import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('collaborations.html');
const sql = read('supabase/tests/venturify_security_smoke_checks.sql');
for (const contract of ['id="requests"','data-filter=','accept','decline','exportRequests','id="retryRequests"','aria-live="polite"']) {
  assert.ok(page.includes(contract), 'Collaboration page is missing contract: ' + contract);
}
for (const contract of ['collaboration_acceptance_workspace_trigger_enabled','no_duplicate_pending_collaboration_pairs','symmetric_pending_collaboration_index']) {
  assert.ok(sql.includes("'" + contract + "'"), 'Security smoke suite is missing: ' + contract);
}
for (const contract of [
  'request-next',
  'Review this request',
  'Waiting for a response',
  'Collaboration accepted',
  'Request declined',
  'No message was included with this request.',
  'data-decision="accepted"',
  'data-withdraw='
]) {
  assert.ok(page.includes(contract), 'Collaboration cards are missing next-step contract: ' + contract);
}

assert.ok(page.includes("$('retryRequests').addEventListener('click'"), 'Initial request loading errors must offer a retry action.');
assert.ok(page.includes("$('requests').setAttribute('aria-busy','false')"), 'Failed loads must clear the busy state.');

console.log('Collaboration request contract checks passed.');
