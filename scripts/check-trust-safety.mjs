import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';

const foundation = readFileSync('supabase/migrations/20261016000000_add_trust_safety_foundation.sql', 'utf8');
const blockMigration = readFileSync('supabase/migrations/20261017000000_enforce_user_blocks.sql', 'utf8');
const safetyScript = readFileSync('scripts/trust-safety.js', 'utf8');

// Base safety schema and row-level security controls must not silently disappear.
for (const table of ['user_blocks', 'content_reports']) {
  assert.ok(
    foundation.toLowerCase().includes(`create table if not exists public.${table}`),
    `Missing ${table} table`
  );
}
for (const policy of [
  'Users can view blocks involving them',
  'Users can block accounts as themselves',
  'Users can unblock accounts as themselves',
  'Users can submit reports as themselves',
  'Users can view their own reports'
]) {
  assert.ok(foundation.includes(policy), `Missing RLS policy: ${policy}`);
}
for (const control of ['ventSafetyLauncher', 'ventSafetyPanel', 'ventSafetyReport', 'ventSafetyBlock']) {
  assert.ok(safetyScript.includes(control), `Missing safety UI control: ${control}`);
}
assert.ok(safetyScript.toLowerCase().includes('maxlength="1000"'), 'Report details should remain length-limited');
assert.ok(safetyScript.includes('auth.getUser('), 'Safety actions must check signed-in user context');
assert.ok(safetyScript.includes("type === 'user' && id === user.id"), 'The UI should prevent self-report attempts');
assert.ok(safetyScript.includes('Their profile, posts, and interactions are filtered while you are signed in'), 'Block confirmation should describe active database filtering');

// The database-level block migration must retain every restrictive policy.
for (const policy of [
  "Blocked accounts cannot view each other's profiles",
  "Blocked accounts cannot view each other's posts",
  "Blocked accounts cannot view each other's comments",
  "Blocked accounts cannot comment on each other's posts",
  'Blocked accounts cannot read conversation messages',
  'Blocked accounts cannot send conversation messages',
  "Blocked accounts cannot like each other's posts",
  "Blocked accounts cannot follow each other",
  "Blocked accounts cannot view each other's likes",
  "Blocked accounts cannot view each other's follows"
]) {
  assert.ok(blockMigration.includes(policy), `Missing block enforcement policy: ${policy}`);
}
for (const fn of ['is_post_author_blocked', 'is_conversation_blocked']) {
  assert.ok(blockMigration.includes(`function private.${fn}(`), `Missing private helper ${fn}`);
}
assert.ok(
  blockMigration.toLowerCase().includes('security definer') &&
  blockMigration.includes("set search_path = ''"),
  'Privileged block-check helpers must pin an empty search_path'
);
assert.ok(
  blockMigration.includes('revoke all on function private.is_post_author_blocked(uuid) from public, anon'),
  'Post helper must not be executable by PUBLIC or anon'
);
assert.ok(
  blockMigration.includes('revoke all on function private.is_conversation_blocked(uuid) from public, anon'),
  'Conversation helper must not be executable by PUBLIC or anon'
);

const syntax = spawnSync(process.execPath, ['--check', 'scripts/trust-safety.js'], { encoding: 'utf8' });
assert.equal(syntax.status, 0, syntax.stderr || 'Safety script syntax check failed');
console.log('Trust & safety regression checks passed.');
