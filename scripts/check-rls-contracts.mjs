import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const migrations = {
  blocks: readFileSync(new URL('../supabase/migrations/20261020153000_enforce_block_restrictions.sql', import.meta.url), 'utf8'),
  reactions: readFileSync(new URL('../supabase/migrations/20261020153110_restrict_message_reaction_grants.sql', import.meta.url), 'utf8'),
  notifications: readFileSync(new URL('../supabase/migrations/20261021170000_restrict_notification_updates.sql', import.meta.url), 'utf8'),
  presence: readFileSync(new URL('../supabase/migrations/20261023110000_private_workspace_presence.sql', import.meta.url), 'utf8'),
  readReceipts: readFileSync(new URL('../supabase/migrations/20261019040000_fix_blocked_read_receipt_insert.sql', import.meta.url), 'utf8'),
};

assert.match(migrations.blocks, /user_blocks/i, 'Block enforcement must keep its block relationship checks');
assert.match(migrations.blocks, /auth\\.uid\\(\\)/i, 'Block enforcement must use the authenticated identity');
assert.match(migrations.reactions, /revoke all on table public\\.message_reactions from anon/i,
  'Anonymous users must not be able to access message reactions');
assert.match(migrations.reactions, /grant select, insert, delete on table public\\.message_reactions to authenticated/i,
  'Authenticated reaction access must remain explicitly scoped');
assert.match(migrations.notifications, /revoke update on table public\\.notifications from anon, authenticated/i,
  'Notifications must not grant broad update access');
assert.match(migrations.notifications, /grant update \\(read_at\\) on table public\\.notifications to authenticated/i,
  'Notification update grants must be restricted to the read marker');

for (const operation of ['select', 'insert']) {
  assert.match(migrations.presence, new RegExp('on realtime\\.messages\\s+for ' + operation + '\\s+to authenticated', 'i'),
    'Workspace presence ' + operation + ' access must be authenticated');
}
assert.match(migrations.presence, /r\\.status = 'accepted'/i, 'Presence must require an accepted collaboration');
assert.match(migrations.presence, /auth\\.uid\\(\\)/i, 'Presence must verify collaborator identity');
assert.match(migrations.presence, /realtime\\.messages\\.extension = 'presence'/i, 'Presence policy must not cover broadcast messages');
assert.match(migrations.readReceipts, /user_blocks/i, 'Read receipts must account for user blocks');
assert.match(migrations.readReceipts, /auth\\.uid\\(\\)/i, 'Read receipt identity must be server-verified');

console.log('RLS security-contract regression checks passed (static checks only).');
