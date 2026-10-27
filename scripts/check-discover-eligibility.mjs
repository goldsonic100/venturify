import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const source0 = read('discover.html');
assert.ok(source0.includes("p.id!==currentUser?.id"), "discover.html is missing contract: p.id!==currentUser?.id");
assert.ok(source0.includes("hasProfileInfo(p)"), "discover.html is missing contract: hasProfileInfo(p)");
assert.ok(source0.includes("(communityCounts.get(p.id)||0)>=1"), "discover.html is missing contract: (communityCounts.get(p.id)||0)>=1");
assert.ok(source0.includes("founderLevel(p)>=5"), "discover.html is missing contract: founderLevel(p)>=5");
assert.ok(source0.includes("dailyMatchIds.includes(p.id)"), "discover.html is missing contract: dailyMatchIds.includes(p.id)");
const source1 = read('supabase/tests/venturify_security_smoke_checks.sql');
assert.ok(source1.includes("daily_founder_match_limit_guards_enabled"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: daily_founder_match_limit_guards_enabled");
assert.ok(source1.includes("public_discovery_requires_email_verification"), "supabase/tests/venturify_security_smoke_checks.sql is missing contract: public_discovery_requires_email_verification");

console.log("Phase 1 discover-eligibility contract checks passed.");
