import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const path = new URL('../supabase/tests/venturify_security_smoke_checks.sql', import.meta.url);
const sql = readFileSync(path, 'utf8');
const requiredChecks = [
  'all_public_tables_have_rls',
  'sensitive_rpc_not_executable_by_anon',
  'public_security_definer_functions_pin_search_path',
  'account_settings_rls_and_owner_policies',
  'public_discovery_requires_email_verification',
  'private_profile_and_post_policies_respect_visibility',
  'messageable_founder_rpc_and_dm_preference_guard',
  'moderator_security_definer_functions_check_moderator_membership',
  'privileged_rpc_authentication_guards',
  'daily_founder_match_limit_guards_enabled',
  'free_community_membership_limit_guard_enabled',
  'block_guards_for_messages',
  'messaging_realtime_tables_published'
];

for (const check of requiredChecks) {
  assert.ok(sql.includes("'" + check + "'"), 'Security smoke suite is missing required check: ' + check);
}

assert.match(sql, /SELECT\s+check_name,\s*passed,\s*detail\s+FROM\s+checks/i,
  'Security smoke suite must return named pass/fail rows');
assert.ok(!/^\s*(?:INSERT|UPDATE|DELETE|ALTER|DROP|CREATE|GRANT|REVOKE|TRUNCATE)\b/im.test(sql),
  'Security smoke suite must remain read-only');

console.log('Security smoke-test contract passed (' + requiredChecks.length + ' required checks).');
