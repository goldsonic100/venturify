import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('moderator.html');
const sql = read('supabase/tests/venturify_security_smoke_checks.sql');
const diagnostics = read('supabase/migrations/20261108010000_moderator_system_diagnostics.sql');
const policyDiagnostics = read('supabase/migrations/20261110010000_add_moderator_rls_policy_diagnostics.sql');
const definerInventory = read('supabase/migrations/20261111020000_add_security_definer_inventory_diagnostics.sql');
const accountDirectory = read('supabase/migrations/20261111030000_moderator_account_directory_filters.sql');
for (const contract of ['moderator_list_reports','moderator_search_accounts','moderator_update_report','moderator']) {
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
for (const contract of ['pg_catalog.pg_policies','RLS policies: ','policy_count','no policies exist']) {
  assert.ok(policyDiagnostics.includes(contract), 'RLS policy diagnostics are missing: ' + contract);
}
assert.ok(policyDiagnostics.includes('CREATE OR REPLACE FUNCTION public.moderator_system_diagnostics()') || policyDiagnostics.includes('create or replace function public.moderator_system_diagnostics()'), 'Additive policy diagnostics migration must update the existing protected RPC.');
for (const contract of ['SECURITY DEFINER function inventory','unexpected_anon_grants','authenticated_functions_missing_guard','unsafe_public_projection','list_published_founder_postmortems']) {
  assert.ok(definerInventory.includes(contract), 'Security-definer inventory diagnostics are missing: ' + contract);
}
assert.ok(page.includes("rpc('moderator_system_diagnostics')"), 'Moderator Systems tab must call the protected diagnostics RPC.');

for (const contract of ['systemSearch','systemStatusFilter','systemFilterSummary','exportSystems','renderSystemChecks','exportSystemReport','latestSystemReport','JSON.stringify(payload,null,2)']) {
  assert.ok(page.includes(contract), 'Moderator Systems UI is missing: ' + contract);
}
console.log('Moderator authorization and system-diagnostics contract checks passed.');

for (const contract of ['moderator_search_accounts','p_status','p_sort','needs_attention','posting_restricted','most_posts','most_followers','private.account_moderation_state','Moderator access required','revoke all on function']) {
  assert.ok(accountDirectory.includes(contract), 'Account directory migration is missing: ' + contract);
}
for (const contract of ['userStatusFilter','userSort','userPageSummary',"rpc('moderator_search_accounts'","p_status:$('userStatusFilter').value","p_sort:$('userSort').value"]) {
  assert.ok(page.includes(contract), 'Moderator account directory UI is missing: ' + contract);
}

for (const contract of ['appealOffset','appealHasNext','updateAppealPagination','prevAppeals','nextAppeals','appealPageLabel',"p_limit:51,p_offset:appealOffset",'visibleAppeals=rows.slice(0,50)']) {
  assert.ok(page.includes(contract), 'Moderator appeal pagination is missing: ' + contract);
}

for (const contract of ['Inspect reporter account','Inspect reported account','Inspect reported post',"$('userQuery').value=report.reporter_id","$('userQuery').value=report.reported_user_id","$('postQuery').value=report.post_id",'switchTab(\'accounts\')','switchTab(\'content\')']) {
  assert.ok(page.includes(contract), 'Moderator report investigation shortcut is missing: ' + contract);
}

const reportHistory = read('supabase/migrations/20261112010000_moderator_account_report_history.sql');
for (const contract of ['moderator_get_account_report_history','p_target_user_id','private.moderators','Moderator access required','r.reporter_id = p_target_user_id','r.reported_user_id = p_target_user_id','reviewed_by','limit 100','revoke all on function','grant execute on function']) {
  assert.ok(reportHistory.includes(contract), 'Moderator account report history migration is missing: ' + contract);
}
for (const contract of ['View report history','moderator_get_account_report_history','Account report activity history','Filed by this account','Filed against this account','reportHistory.hidden=false','event.details']) {
  assert.ok(page.includes(contract), 'Moderator account report timeline UI is missing: ' + contract);
}

const appealHistory = read('supabase/migrations/20261112020000_moderator_account_appeal_history.sql');
for (const contract of ['moderator_get_account_appeal_history','p_target_user_id','private.moderators','Moderator access required','private.account_moderation_appeals','private.account_moderation_appeal_events','a.user_id = p_target_user_id','limit 100','revoke all on function','grant execute on function']) {
  assert.ok(appealHistory.includes(contract), 'Moderator account appeal history migration is missing: ' + contract);
}
for (const contract of ['View appeal history','moderator_get_account_appeal_history','Account appeal history','Account statement: ','Timeline note: ','event.event_created_at','appealHistory.hidden=false']) {
  assert.ok(page.includes(contract), 'Moderator account appeal timeline UI is missing: ' + contract);
}
