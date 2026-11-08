import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('communities.html');
const sql = read('supabase/tests/venturify_security_smoke_checks.sql');
for (const contract of ['community-join-btn','communityMemberships','limit','aria-live']) {
  assert.ok(page.includes(contract), 'Communities page is missing contract: ' + contract);
}
for (const contract of ['<details class="community-why">','<summary>Why this community?</summary>','recommendationReasons.set(c.id,reasons)','recommendationReasons.get(c.id).map(reason=>','community-why summary:focus-visible']) {
  assert.ok(page.includes(contract), 'Community recommendation explanation is missing: ' + contract);
}
for (const contract of ['free_community_membership_limit_guard_enabled','all_public_tables_have_rls','account_settings_rls_and_owner_policies']) {
  assert.ok(sql.includes("'" + contract + "'"), 'Security smoke suite is missing: ' + contract);
}
console.log('Phase 1 community membership contract checks passed.');
