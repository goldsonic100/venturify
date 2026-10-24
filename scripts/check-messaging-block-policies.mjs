import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const sql = readFileSync(new URL('../supabase/migrations/20261023200000_messaging_restrictive_block_policies.sql', import.meta.url), 'utf8');
for (const table of ['conversations','conversation_members','messages','message_reads']) {
  assert.match(sql, new RegExp('on public\\.' + table + ' as restrictive', 'i'), 'Missing restrictive RLS for ' + table);
}
assert.match(sql, /for select to authenticated[\s\S]*?using \(not private\.is_conversation_blocked\(id\)\)/i);
assert.match(sql, /for insert to authenticated[\s\S]*?with check \(not private\.is_conversation_blocked\(conversation_id\)\)/i);
assert.match(sql, /private\.is_message_in_blocked_conversation\(message_id\)/i);
console.log('Messaging restrictive block-policy regression checks passed.');
