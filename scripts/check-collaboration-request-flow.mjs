import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const [feed, collaborations, workspace, notifications, migration] = [
  '../feed.html',
  '../collaborations.html',
  '../workspace.html',
  '../notifications.html',
  '../supabase/migrations/20261016010000_create_collaboration_requests.sql',
].map(read);

for (const [page, html] of Object.entries({ feed, collaborations, workspace, notifications })) {
  const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
    .map(([, source]) => source.trim())
    .filter(Boolean);
  for (const [index, source] of scripts.entries()) {
    assert.doesNotThrow(
      () => new Function(source),
      page + ' inline script ' + (index + 1) + ' must parse',
    );
  }
}

assert.match(feed, /data-collaboration-request=/, 'Opportunity cards must offer collaboration requests');
assert.match(feed, /Promise\.all\(\[[\s\S]{0,260}user_blocks[\s\S]{0,300}user_blocks/,
  'The request flow must check blocks in both directions');
assert.ok(
  feed.includes(".eq('requester_id',recipientId).eq('recipient_id',user.id).eq('status','pending')"),
  'The request flow must detect an invitation already sent to the current user',
);
assert.match(feed, /created\.error\.code==='23505'/,
  'Concurrent duplicate requests must be handled without exposing a raw database error');
assert.ok(feed.includes('This founder has already invited you. Open your collaboration inbox to respond.'),
  'Incoming invitations must direct users to their collaboration inbox');
assert.ok(feed.includes('You cannot request collaboration with yourself.'),
  'Self-collaboration must be rejected');

assert.ok(collaborations.includes("href=\"workspace.html?request='+encodeURIComponent(r.id)+'\""),
  'Accepted collaboration requests must link into their workspace');
assert.ok(collaborations.includes("status==='accepted'"),
  'Workspace links must only be rendered for accepted requests');
assert.ok(workspace.includes("params.get('request')") && workspace.includes("params.get('task')"),
  'Workspace deep links must parse collaboration and task identifiers');
assert.ok(workspace.includes(".eq('id',requestId).eq('status','accepted').maybeSingle()"),
  'Workspace access must require an accepted collaboration request');
assert.ok(workspace.includes("![req.requester_id,req.recipient_id].includes(user.id)"),
  'Workspace access must be limited to the two request participants');
assert.ok(workspace.includes("from('workspace_tasks')") && workspace.includes("from('workspace_messages')"),
  'The workspace must load tasks and project chat');
assert.ok(workspace.includes('id="taskMilestone"') && workspace.includes("milestone_id:$('taskMilestone').value||null"),
  'New tasks must be attachable to a selected project milestone');
assert.ok(workspace.includes('function renderTaskMilestoneOptions()') && workspace.includes('renderTaskMilestoneOptions();renderTasks();renderMilestones();'),
  'The task milestone selector must refresh when milestone data loads');
assert.ok(workspace.includes('id="workspace-mobile-polish"') && workspace.includes('@media(max-width:760px)') && workspace.includes('@media(max-width:420px)'),
  'The collaboration workspace must include tablet and narrow-mobile responsive refinements');
assert.ok(workspace.includes('button:focus-visible,a:focus-visible,input:focus-visible') && workspace.includes('prefers-reduced-motion:reduce'),
  'Workspace controls must retain visible keyboard focus and respect reduced-motion preferences');
assert.ok(workspace.includes('id="projectPulse"') && workspace.includes("pulse.querySelector('strong').textContent='Project pulse · '+headline"),
  'The workspace overview must summarize project health from current task data');
assert.ok(['#addTaskSection','#milestonesSection','#projectTasks','#projectActivity','#projectChat'].every(id=>workspace.includes('href="'+id+'"')),
  'The workspace overview must provide shortcuts to core collaboration areas');
assert.ok(['id="addTaskSection"','id="projectTasks"','id="projectActivity"'].every(id=>workspace.includes(id)),
  'Workspace shortcuts must point to real sections');
assert.ok(notifications.includes("'workspace.html?request='+encodeURIComponent(collaborationId)"),
  'Workspace notifications must open the correct collaboration workspace');
assert.ok(notifications.includes("taskId?'&task='+encodeURIComponent(taskId)"),
  'Task notifications must preserve the target task deep link');

assert.match(migration, /collaboration_requests_one_pending_pair_idx/,
  'The database must keep a unique pending-request guard');
assert.match(migration, /enable row level security/i,
  'Collaboration requests must remain protected by RLS');
assert.match(migration, /requester_id <> recipient_id/,
  'The database must prohibit self-directed requests');

console.log('Collaboration request-to-workspace regression checks passed (static checks only; live two-account testing still required).');
