import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const feed = readFileSync(new URL('../feed.html', import.meta.url), 'utf8');
const collaborations = readFileSync(new URL('../collaborations.html', import.meta.url), 'utf8');
const opportunityMigration = readFileSync(new URL('../supabase/migrations/20261020174108_unified_venture_opportunities.sql', import.meta.url), 'utf8');
const workspaceMigration = readFileSync(new URL('../supabase/migrations/20261020175822_auto_create_workspaces_on_collaboration_acceptance.sql', import.meta.url), 'utf8');
const requestMigration = readFileSync(new URL('../supabase/migrations/20261016010000_create_collaboration_requests.sql', import.meta.url), 'utf8');

for (const [name, html] of [['feed', feed], ['collaborations', collaborations]]) {
  const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
    .map(([, source]) => source.trim()).filter(Boolean);
  assert.ok(scripts.length, name + '.html must contain application scripts');
  scripts.forEach((source, index) => {
    try { new Function(source); }
    catch (error) { throw new Error(name + '.html inline script ' + (index + 1) + ' failed to parse: ' + error.message); }
  });
}

for (const [pattern, message] of [
  [/opportunity_offer/, 'Feed must persist what a founder can offer'],
  [/opportunity_need/, 'Feed must persist what a founder needs'],
  [/opportunity_stage/, 'Feed must persist the venture stage'],
  [/option value="idea"/, 'Feed must allow idea-seeking posts'],
  [/option value="resource"/, 'Feed must allow resource-offer posts'],
  [/option value="lesson"/, 'Feed must allow lessons from experience'],
  [/from\('collaboration_requests'\)/, 'Collaboration requests must be persisted'],
  [/data-decision="accepted"/, 'Incoming requests must have an accept action'],
  [/data-decision="declined"/, 'Incoming requests must have a decline action'],
  [/data-withdraw=/, 'Outgoing pending requests must have a withdraw action'],
  [/workspace\.html\?request=/, 'Accepted collaborations must link into a workspace'],
  [/exportRequests/, 'Founders must be able to export their request history'],
]) assert.match(feed + '\n' + collaborations, pattern, message);

assert.match(opportunityMigration, /opportunity_offer text/i);
assert.match(opportunityMigration, /opportunity_need text/i);
assert.match(opportunityMigration, /posts_opportunity_offer_length/i);
assert.match(opportunityMigration, /posts_opportunity_need_length/i);
assert.match(opportunityMigration, /posts_opportunity_stage_length/i);
assert.match(workspaceMigration, /old\.status = 'pending' and new\.status in \('accepted', 'declined'\)/i,
  'Workspace creation should only react to a pending request decision');
assert.match(workspaceMigration, /on conflict \(collaboration_request_id\) do nothing/i,
  'Accepting a request twice must not create duplicate workspaces');
assert.match(requestMigration, /enable row level security/i, 'Collaboration requests must retain RLS');
assert.match(requestMigration, /requester_id <> recipient_id/i, 'Self-collaboration must remain prohibited');
assert.ok(collaborations.includes(`if(/^[\\\\s]*[=+@-]/.test(text)`), 'CSV exports must neutralize spreadsheet formula injection');

console.log('Venture opportunity/collaboration regression checks passed (static checks only).');
