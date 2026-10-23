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

console.log('Messaging/collaboration regression checks passed (static checks only; no live services called).');
