import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const migrationPath = 'supabase/migrations/20261017000000_enforce_user_blocks.sql';
const sql = readFileSync(migrationPath, 'utf8');
const schema = readFileSync('supabase/schema.sql', 'utf8');
const checks = [
  ['restrictive profile SELECT policy', /create policy "Blocked accounts cannot view each other's profiles"\s+on public\.profiles\s+as restrictive\s+for select\s+to authenticated/i],
  ['restrictive post SELECT policy', /create policy "Blocked accounts cannot view each other's posts"\s+on public\.posts\s+as restrictive\s+for select\s+to authenticated/i],
  ['restrictive comment SELECT policy', /create policy "Blocked accounts cannot view each other's comments"\s+on public\.comments\s+as restrictive\s+for select\s+to authenticated/i],
  ['comment INSERT WITH CHECK', /create policy "Blocked accounts cannot comment on each other's posts"[\s\S]*?as restrictive\s+for insert\s+to authenticated\s+with check\s*\(/i],
  ['message SELECT policy', /create policy "Blocked accounts cannot read conversation messages"\s+on public\.messages\s+as restrictive\s+for select\s+to authenticated/i],
  ['message INSERT WITH CHECK', /create policy "Blocked accounts cannot send conversation messages"[\s\S]*?as restrictive\s+for insert\s+to authenticated\s+with check\s*\(/i],
  ['message sender identity validation', /sender_id\s*=\s*\(select auth\.uid\(\)\)/i],
  ['both directions of a block relationship', /b\.blocker_id\s*=\s*\(select auth\.uid\(\)\)\s+and b\.blocked_id\s*=\s*[\w.]+[\s\S]*?or\s*\(b\.blocked_id\s*=\s*\(select auth\.uid\(\)\)\s+and b\.blocker_id\s*=\s*[\w.]+/i],
  ['conversation membership checked for messages', /from public\.conversation_members cm[\s\S]*?where cm\.conversation_id\s*=\s*messages\.conversation_id/i],
  ['posts use author_id', /posts\.author_id/i],
  ['comments use author_id', /comments\.author_id/i],
  ['comment policy uses secure post-author predicate', /not private\.is_post_author_blocked\(comments\.post_id\)/i],
  ['predicate is security definer with locked search path', /create or replace function private\.is_post_author_blocked[\s\S]*?security definer[\s\S]*?set search_path = ''/i],
  ['predicate execution not granted to anon/public', /revoke all on function private\.is_post_author_blocked\(uuid\) from public, anon/i],
];
for (const [label, pattern] of checks) {
  assert.match(sql, pattern, `Missing or malformed requirement: ${label}`);
}
assert.match(schema, /create table if not exists public\.posts[\s\S]*?author_id uuid not null/i, 'Repository schema must define posts.author_id');
assert.match(schema, /create table if not exists public\.comments[\s\S]*?author_id uuid not null/i, 'Repository schema must define comments.author_id');
assert.ok(sql.includes('as $block$'