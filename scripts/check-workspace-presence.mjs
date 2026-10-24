import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const workspace = readFileSync(new URL('../workspace.html', import.meta.url), 'utf8');
const migration = readFileSync(
  new URL('../supabase/migrations/20261023110000_private_workspace_presence.sql', import.meta.url),
  'utf8',
);

const scripts = [...workspace.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
  .map(([, source]) => source.trim())
  .filter(Boolean);
assert.ok(scripts.length, 'Workspace should contain application scripts');
scripts.forEach((source, index) => {
  try {
    new Function(source);
  } catch (error) {
    throw new Error('workspace.html inline script ' + (index + 1) + ' failed to parse: ' + error.message);
  }
});

for (const [pattern, message] of [
  [/id="workspacePresence"/, 'Workspace must show collaborator presence status'],
  [/id="workspacePresenceText"/, 'Presence must expose a readable status message'],
  [/presenceChannel=null/, 'Presence channel lifecycle state must remain explicit'],
  [/venturify-workspace-presence:/, 'Presence topics must be scoped to the workspace'],
  [/presence:\{key:user\.id\}/, 'Presence identity must use the authenticated user ID'],
  [/channel\.on\('presence'/, 'Workspace must listen for presence sync/join/leave events'],
  [/channel\.track\(/, 'Workspace must publish its own presence'],
  [/presenceRetryDelay/, 'Presence reconnects must use bounded retry state'],
  [/document\.visibilityState/, 'Presence must account for background tabs'],
]) assert.match(workspace, pattern, message);

assert.match(migration, /on realtime\.messages\s+for select\s+to authenticated/i,
  'Only authenticated users should read workspace presence');
assert.match(migration, /on realtime\.messages\s+for insert\s+to authenticated/i,
  'Only authenticated users should publish workspace presence');
assert.match(migration, /realtime\.messages\.extension = 'presence'/i,
  'Policies must be limited to presence messages');
assert.match(migration, /realtime\.topic\(\) like 'venturify-workspace-presence:%'/i,
  'Policies must only cover Venturify workspace-presence topics');
assert.match(migration, /r\.status = 'accepted'/i,
  'Presence access must require an accepted collaboration');
assert.match(migration, /auth\.uid\(\)/i,
  'Presence access must be restricted to one of the accepted collaborators');
assert.match(migration, /split_part\(realtime\.topic\(\), ':', 2\).*?::uuid/s,
  'Workspace ID parsing must validate UUID syntax before casting');
assert.doesNotMatch(migration, /for update|for delete/i,
  'Presence policy must not add update/delete permissions');

console.log('Workspace presence regression checks passed (static checks only; no live session is opened).');
