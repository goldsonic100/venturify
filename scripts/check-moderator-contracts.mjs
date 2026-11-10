import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('moderator.html');
const sql = read('supabase/tests/venturify_security_smoke_checks.sql');
const diagnostics = read('supabase/migrations/20261108010000_moderator_system_diagnostics.sql');
for (const contract of ['moderator_list_reports','moderator_list_users','moderator_update_report','moderator']) {
  assert.ok(page.includes(contract), 'Moderator page is missing contract: ' + contract);
}
for (const contract of ['moderator_security_definer_functions_check_moderator_membership','sensitive_rpc_not_executable_by_anon','public_security_definer_functions_pin_search_path']) {
  assert.ok(sql.includes("'" + contract + "'"), 'Security smoke suite is missing: ' + contract);
}
for (const contract of [
  "('private','moderators',true)",
  "('System diagnostics endpoint','public.moderator_system_diagnostics()')",
  "has_table_privilege('anon',c.oid,'SELECT')",
  "has_function_privilege('anon',p.oid,'EXECUTE')",
  "not p.prosecdef",
  'search_path=""'
]) {
  assert.ok(diagnostics.includes(contract), 'Moderator diagnostics are missing contract: ' + contract);
}
assert.ok(page.includes("rpc('moderator_system_diagnostics')"), 'Moderator Systems tab must call the protected diagnostics RPC.');
console.log('Moderator authorization and system-diagnostics contract checks passed.');
