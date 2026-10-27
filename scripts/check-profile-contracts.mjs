import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const page = read('profile.html');
const discover = read('discover.html');
const sql = read('supabase/tests/venturify_security_smoke_checks.sql');
for (const contract of ['reputation-breakdown','follow-btn','profile-completion-done','aria-live','data-profile-retry','Retry loading profile','role="alert"']) {
  assert.ok(page.includes(contract), 'Profile page is missing contract: ' + contract);
}
for (const contract of ['hasProfileInfo(p)','founderLevel(p)>=5','(communityCounts.get(p.id)||0)>=1']) {
  assert.ok(discover.includes(contract), 'Discover is missing profile-quality eligibility contract: ' + contract);
}
for (const contract of ['public_discovery_requires_email_verification','private_profile_and_post_policies_respect_visibility']) {
  assert.ok(sql.includes("'" + contract + "'"), 'Security smoke suite is missing: ' + contract);
}
assert.ok(page.includes("const retryProfile=e.target.closest('[data-profile-retry]')"), 'Profile load errors must provide a working retry action.');
assert.ok(page.includes("data-profile-list=\"'+kind+'\""), 'Follower list errors must offer an in-place retry action.');
console.log('Phase 1 profile reputation and visibility contract checks passed.');
