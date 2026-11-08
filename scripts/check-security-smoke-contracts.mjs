import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const path = new URL('../supabase/tests/venturify_security_smoke_checks.sql', import.meta.url);
const sql = readFileSync(path, 'utf8');
const requiredChecks = [
  'all_public_tables_have_rls',
  'sensitive_rpc_not_executable_by_anon',
  'public_security_definer_functions_pin_search_path',
  'all_public_security_definer_functions_use_empty_search_path',
  'security_definer_execute_grants_are_least_privilege',
  'all_moderator_rpcs_enforce_allowlist_and_safe_execution',
  'account_settings_rls_and_owner_policies',
  'public_discovery_requires_email_verification',
  'private_profile_and_post_policies_respect_visibility',
  'messageable_founder_rpc_and_dm_preference_guard',
  'moderator_security_definer_functions_check_moderator_membership',
  'privileged_rpc_authentication_guards',
  'daily_founder_match_limit_guards_enabled',
  'free_community_membership_limit_guard_enabled',
  'block_guards_for_messages',
  'messaging_realtime_tables_published',
  'poll_results_rpc_respects_post_visibility_and_blocks',
  'postmortem_public_rpc_exposes_only_approved_consented_projection',
  'postmortem_private_rpcs_enforce_author_and_moderator_boundaries',
  'postmortem_moderator_pagination_rpc_is_allowlisted_and_bounded',
  'postmortem_revision_rpc_is_author_scoped_and_not_public'
];

for (const check of requiredChecks) {
  assert.ok(sql.includes("'" + check + "'"), 'Security smoke suite is missing required check: ' + check);
}

const declaredChecks = [...sql.matchAll(/SELECT\s+'([a-z0-9_]+)'\s*(?:::text)?\s+AS\s+check_name/gi)]
  .map((match) => match[1]);
assert.ok(declaredChecks.length >= requiredChecks.length,
  'Security smoke suite must declare all critical named checks');
assert.equal(new Set(declaredChecks).size, declaredChecks.length,
  'Security smoke suite must not contain duplicate check names');

assert.match(sql, /SELECT\s+check_name,\s*passed,\s*detail\s+FROM\s+checks/i,
  'Security smoke suite must return named pass/fail rows');

// Strip SQL comments before checking for writes so a commented example cannot
// mask a mutation statement in the executable portion of this read-only audit.
const executableSql = sql
  .replace(/--[^\n]*/g, '')
  .replace(/\/\*[\s\S]*?\*\//g, '');
assert.ok(!/^\s*(?:INSERT|UPDATE|DELETE|ALTER|DROP|CREATE|GRANT|REVOKE|TRUNCATE)\b/im.test(executableSql),
  'Security smoke suite must remain read-only');

console.log('Security smoke-test contract passed (' + requiredChecks.length + ' required checks).');
