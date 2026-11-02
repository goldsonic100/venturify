-- Manual, narrowly scoped cleanup for duplicate social notifications.
-- Keep the generic create_activity_notification() triggers. They handle
-- comments (including replies), follows, and likes in one place.
-- The legacy venturify_notify_* triggers independently insert the same
-- notification rows, so having both trigger sets causes duplicates.
--
-- Run only after reviewing the live trigger inventory and backing up the
-- current schema. This does not delete notification data or user content.

DROP TRIGGER IF EXISTS venturify_notify_comment ON public.comments;
DROP TRIGGER IF EXISTS venturify_notify_follow ON public.follows;
DROP TRIGGER IF EXISTS venturify_notify_like ON public.likes;

-- The legacy trigger functions are intentionally left in place for now.
-- Remove them in a later cleanup only after confirming no other trigger or
-- application code references them.
