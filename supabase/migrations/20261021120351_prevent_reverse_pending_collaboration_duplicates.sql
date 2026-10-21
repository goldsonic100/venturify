-- Prevent two founders from opening duplicate pending requests in opposite directions.
-- Keep the existing directional index; this symmetric index closes the reverse-direction race.
CREATE UNIQUE INDEX IF NOT EXISTS collaboration_requests_one_pending_pair_symmetric_idx
  ON public.collaboration_requests (
    LEAST(requester_id, recipient_id),
    GREATEST(requester_id, recipient_id)
  )
  WHERE status = 'pending';

COMMENT ON INDEX public.collaboration_requests_one_pending_pair_symmetric_idx IS
  'Allows at most one pending collaboration request per pair of founders, regardless of direction.';
