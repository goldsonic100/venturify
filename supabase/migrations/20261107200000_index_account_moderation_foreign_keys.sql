-- Cover moderator/account foreign keys introduced by the appeals workflow.
-- These indexes improve joins and avoid full-table scans when referenced users are updated/deleted.
CREATE INDEX IF NOT EXISTS account_moderation_appeal_events_actor_id_idx
  ON private.account_moderation_appeal_events (actor_id);

CREATE INDEX IF NOT EXISTS account_moderation_appeals_reviewed_by_idx
  ON private.account_moderation_appeals (reviewed_by);

CREATE INDEX IF NOT EXISTS account_moderation_audit_moderator_id_idx
  ON private.account_moderation_audit (moderator_id);

CREATE INDEX IF NOT EXISTS account_moderation_state_updated_by_idx
  ON private.account_moderation_state (updated_by);
