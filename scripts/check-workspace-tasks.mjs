import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const workspace = readFileSync(new URL('../workspace.html', import.meta.url), 'utf8');
const checklists = readFileSync(new URL('../supabase/migrations/20261020290000_workspace_task_checklists.sql', import.meta.url), 'utf8');
const checklistIntegrity = readFileSync(new URL('../supabase/migrations/20261020300000_checklist_item_integrity.sql', import.meta.url), 'utf8');
const comments = readFileSync(new URL('../supabase/migrations/20261020250000_workspace_task_comments.sql', import.meta.url), 'utf8');
const activity = readFileSync(new URL('../supabase/migrations/20261020230000_add_workspace_activity_timeline.sql', import.meta.url), 'utf8');

const scripts = [...workspace.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
  .map(([, source]) => source.trim()).filter(Boolean);
assert.ok(scripts.length, 'Workspace must contain application scripts');
scripts.forEach((source, index) => {
  try { new Function(source); }
  catch (error) { throw new Error('workspace.html inline script ' + (index + 1) + ' failed to parse: ' + error.message); }
});

for (const [pattern, message] of [
  [/from\('workspace_tasks'\)/, 'Tasks must persist in the database'],
  [/from\('workspace_task_checklist_items'\)/, 'Shared task checklists must persist'],
  [/from\('workspace_task_comments'\)/, 'Task comments must persist'],
  [/id="activityList"/, 'Workspace must show the activity timeline'],
  [/id="taskChecklistFilter"/, 'Task checklist-progress filtering must remain available'],
  [/taskChecklistItemsCache/, 'Checklist progress must be represented in task state'],
  [/loadTaskComments\(\)/, 'Task comments must be reloadable after updates'],
  [/table:'workspace_task_comments'/, 'Task comments must receive realtime updates'],
]) assert.match(workspace, pattern, message);

assert.match(checklists, /create table if not exists public\.workspace_task_checklist_items/i);
assert.match(checklists, /title text not null check \(char_length\(btrim\(title\)\) between 1 and 240\)/i,
  'Checklist titles must remain non-empty and length-limited');
assert.match(checklists, /workspace_task_checklist_task_workspace_fk/i,
  'Checklist rows must keep task and workspace scope consistent');
assert.match(checklists, /enable row level security/i, 'Checklist items must remain protected by RLS');
assert.match(checklistIntegrity, /new\.workspace_id := old\.workspace_id/i,
  'Checklist updates must not move an item to another workspace');
assert.match(checklistIntegrity, /new\.task_id := old\.task_id/i,
  'Checklist updates must not move an item to another task');
assert.match(checklistIntegrity, /new\.created_by := old\.created_by/i,
  'Checklist updates must not reassign item ownership');
assert.match(comments, /enable row level security/i, 'Task comments must remain protected by RLS');
assert.match(comments, /char_length\(btrim\(content\)\) between 1 and 2000/i,
  'Task comments must remain non-empty and length-limited');
assert.match(activity, /enable row level security/i, 'Workspace activity must remain protected by RLS');
assert.match(activity, /r\.status='accepted'/i, 'Activity access must require accepted collaborators');

console.log('Workspace task/checklist/comment regression checks passed (static checks only).');
