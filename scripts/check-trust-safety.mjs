import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';

const migrationPath = 'supabase/migrations/20261016000000_add_trust_safety_foundation.sql';
const migration = readFileSync(migrationPath, 'utf8');
const safetyScript = readFileSync('scripts/trust-safety.js', 'utf8');

for (const table of ['user_blocks', 'content_reports']) {
  assert.match(migration, new RegExp('create table if not exists public\\.' + table, 'i'), `Missing ${table} table`);
}
for (const policy of [
  'Users can read blocks involving them',
  'Users can block accounts',
  'Users can unblock accounts',
  'Users can submit reports',
  'Users can read their own reports'
]) {
  assert.ok(migration.includes(policy), `Missing RLS policy: ${policy}`);
}
for (const control of ['ventSafetyLauncher', 'ventSafetyPanel', 'ventSafetyReport', 'ventSafetyBlock']) {
  assert.ok(safetyScript.includes(control), `Missing safety UI control: ${control}`);
}
assert.match(safetyScript, /maxlength="1000"/i, 'Report details should remain length-limited');
assert.match(safetyScript, /auth\\.getUser\\(/, 'Safety actions must check signed-in user context');

const syntax = spawnSync(process.execPath, ['--check', 'scripts/trust-safety.js'], { encoding: 'utf8' });
assert.equal(syntax.status, 0, syntax.stderr || 'Safety script syntax check failed');

console.log('Trust & safety regression checks passed.');
