import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('moderator.html');
const sql = read('supabase/tests/venturify_security_smoke_checks.sql');
for (const contract of ['moderator_list_reports','moderator_list_users','moderator_update_report','moderator']) {
  assert.ok(page.includes(contract), 'Moderator page is missing contract: ' + contract);
}
for (const contract of ['moderator_security_definer_functions_check_moderator_membership','sensitive_rpc_not_executable_by_anon','public_security_definer_functions_pin_search_path']) {
  assert.ok(sql.includes("'" + contract + "'"), 'Security smoke suite is missing: ' + contract);
}
console.log('Phase 1 moderator authorization contract checks passed.');
