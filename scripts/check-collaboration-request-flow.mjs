import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const feed = readFileSync(new URL('../feed.html', import.meta.url), 'utf8');
const migration = readFileSync(
  new URL('../supabase/migrations/20261016010000_create_collaboration_requests.sql', import.meta.url),
  'utf8',
);

const scripts = [...feed.matchAll(/<script\\b[^>]*>([\\s\\S]*?)<\\/script>/gi)]
  .map(([, source]) => source.trim())
  .filter(Boolean);
for (const [index, source] of scripts.entries()) {
  assert.doesNotThrow(() => new Function(source), `feed.html inline script ${index + 1} must parse`);
}

assert.match(feed, /data-collaboration-request=/, 'Opportunity cards must offer collaboration requests');
assert.match(feed, /Promise\\.all\\(\\[[\\s\\S]{0,260}user_blocks[\\s\\S]{0,300}user_blocks/,
  'The request flow must check blocks in both directions');
assert.match(feed, /requester_id',recipientId\\)\\.eq\\('recipient_id',user\\.id\\)\\.eq\\('status','pending'/,
  'The request flow must detect an invitation already sent to the current user');
assert.match(feed, /created\\.error\\.code==='23505'/,
  'Concurrent duplicate requests must be handled without exposing a raw database error');
assert.match(feed, /This founder has already invited you\\. Open your collaboration inbox to respond\\./,
  'Incoming invitations must direct users to their collaboration inbox');
assert.match(feed, /You cannot request collaboration with yourself\\./,
  'Self-collaboration must be rejected');
assert.match(migration, /collaboration_requests_one_pending_pair_idx/,
  'The database must keep a unique pending-request guard');
assert.match(migration, /enable row level security/i,
  'Collaboration requests must remain protected by RLS');
assert.match(migration, /requester_id <> recipient_id/,
  'The database must prohibit self-directed requests');

console.log('Collaboration request flow checks passed (static checks only; live account testing still required).');
