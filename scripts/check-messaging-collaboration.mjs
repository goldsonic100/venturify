import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const messages = readFileSync(new URL('../messages.html', import.meta.url), 'utf8');
const reactionsMigration = readFileSync(
  new URL('../supabase/migrations/20261020020000_add_message_reactions.sql', import.meta.url),
  'utf8',
);

function compileInlineScripts(html, name) {
  const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
    .map(([, source]) => source.trim())
    .filter(Boolean);
  assert.ok(scripts.length, name + ' must contain application scripts');
  scripts.forEach((source, index) => {
    try {
      // Compile only: do not execute browser code or contact live services.
      new Function(source);
    } catch (error) {
      throw new Error(name + ' inline script ' + (index + 1) + ' failed to parse: ' + error.message);
    }
  });
}

compileInlineScripts(messages, 'messages.html');

// Core messaging should remain a real Supabase-backed flow, not a static mock.
for (const table of ['conversations', 'messages', 'conversation_members']) {
  assert.ok(messages.includes("'" + table + "'") || messages.includes('"' + table + '"'),
    'Messaging UI must retain its ' + table + ' data path');
}
assert.match(messages, /auth\.getUser\(\)/, 'Messaging must resolve the signed-in user');
assert.match(messages, /from\(['"]messages['"]\)/, 'Messaging must query/send persisted messages');
assert.match(messages, /onAuthStateChange/, 'Messaging must react to auth changes');
assert.match(messages, /subscribe\(/, 'Messaging must keep realtime updates enabled');
assert.match(messages, /insert\(/, 'Messaging must keep a persisted write path');
assert.match(messages, /aria-live|role=["']status["']|toast/i,
  'Messaging must retain a user-visible status/feedback path');

// Group conversations and collaboration entry points should not regress.
assert.match(messages, /group/i, 'Messaging UI must retain group-conversation support');
assert.match(messages, /collaborat/i, 'Messaging UI must retain collaboration entry points');
assert.match(messages, /data-message-profile|[?&]to=/,
  'Founder-to-founder messaging links must continue to open a target conversation');

// Safety checks: message interactions must preserve auth/member/block checks in the UI
// and must not remove the project's database-level reaction access controls.
assert.match(messages, /blocked|block/i, 'Messaging must retain block/safety handling');
assert.match(reactionsMigration, /enable row level security/i, 'Message reactions must use RLS');
assert.match(reactionsMigration, /private\.is_conversation_member/i,
  'Reaction policies must check conversation membership');
assert.match(reactionsMigration, /private\.is_conversation_blocked/i,
  'Reaction policies must respect conversation blocks');
assert.match(reactionsMigration, /auth\.uid\(\)/i, 'Users must only react as themselves');
assert.match(reactionsMigration, /primary key\s*\(message_id,\s*user_id,\s*reaction\)/i,
  'Duplicate identical reactions must be prevented by the database');
assert.match(reactionsMigration, /supabase_realtime/i,
  'Message reactions must remain available to realtime subscribers');


const collaborations = readFileSync(new URL('../collaborations.html', import.meta.url), 'utf8');
const workspace = readFileSync(new URL('../workspace.html', import.meta.url), 'utf8');
const collaborationMigration = readFileSync(
  new URL('../supabase/migrations/20261016010000_create_collaboration_requests.sql', import.meta.url),
  'utf8',
);
const workspaceMigration = readFileSync(
  new URL('../supabase/migrations/20261016020000_create_collaboration_workspaces_and_tasks.sql', import.meta.url),
  'utf8',
);
const workspaceChatMigration = readFileSync(
  new URL('../supabase/migrations/20261016040000_add_private_workspace_chat.sql', import.meta.url),
  'utf8',
);

compileInlineScripts(collaborations, 'collaborations.html');
compileInlineScripts(workspace, 'workspace.html');

// Collaboration request lifecycle: participant-only request data, safe decisions,
// withdraw controls, search/filter/export, and realtime refresh.
assert.match(collaborations, /from\(['"]collaboration_requests['"]\)/,
  'Collaboration page must load persisted requests');
assert.match(collaborations, /data-decision="accepted"/,
  'Incoming requests must have an accept action');
assert.match(collaborations, /data-decision="declined"/,
  'Incoming requests must have a decline action');
assert.match(collaborations, /data-withdraw=/,
  'Outgoing pending requests must have a withdraw action');
assert.match(collaborations, /requestSearch|statusFilter|requestSort/,
  'Requests must remain searchable and filterable');
assert.match(collaborations, /exportRequests/,
  'Users must retain their collaboration-request export');
assert.match(collaborations, /table:'collaboration_requests'/,
  'Collaboration requests must refresh through realtime updates');
assert.match(collaborationMigration, /enable row level security/i,
  'Collaboration requests must remain protected by RLS');
assert.match(collaborationMigration, /auth\.uid\(\)/i,
  'Request policies must tie actions to the authenticated user');
assert.match(collaborationMigration, /requester_id <> recipient_id/,
  'A user must not be able to collaborate with themselves');
assert.match(collaborationMigration, /status = 'pending'/,
  'New collaboration requests must start pending');
assert.match(collaborationMigration, /length\(message\) <= 500/,
  'Collaboration request messages must keep their length limit');

// Workspaces are only opened from accepted collaborations and keep task/project
// chat, activity, files, and task-comment features connected to persisted data.
assert.match(workspace, /select\('id,requester_id,recipient_id,status'\)\.eq\('id',requestId\)\.eq\('status','accepted'\)/i,
  'Workspace entry must verify an accepted collaboration');
assert.match(workspace, /from\(['"]workspace_tasks['"]\)/,
  'Workspace tasks must persist through Supabase');
assert.match(workspace, /from\(['"]workspace_messages['"]\)/,
  'Workspace chat must persist through Supabase');
assert.match(workspace, /workspace_task_comments/,
  'Task discussions must remain available');
assert.match(workspace, /workspace_files|sharedFiles|fileInput/,
  'Shared workspace files must remain available');
assert.match(workspace, /projectActivity|activityList/,
  'Workspace activity must remain visible');
assert.match(workspaceMigration, /enable row level security/i,
  'Workspace and task tables must use RLS');
assert.match(workspaceMigration, /status='accepted'/,
  'Workspace policies must require an accepted collaboration');
assert.match(workspaceChatMigration, /workspace_messages/,
  'Project chat must have a dedicated persisted table');
assert.match(workspaceChatMigration, /enable row level security/i,
  'Project chat must use RLS');

console.log('Messaging/collaboration/workspace regression checks passed (static checks only; no live services called).');
