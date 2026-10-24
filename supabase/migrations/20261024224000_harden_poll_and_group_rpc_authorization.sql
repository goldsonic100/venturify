-- Harden callable SECURITY DEFINER RPCs without changing their intended signed-in use.
-- Poll results require a real authenticated user and bound request size.
CREATE OR REPLACE FUNCTION public.get_poll_results(requested_poll_ids uuid[])
RETURNS TABLE(poll_id uuid, option_id uuid, vote_count bigint, is_my_vote boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF coalesce(pg_catalog.cardinality(requested_poll_ids), 0) > 100 THEN
    RAISE EXCEPTION 'Request no more than 100 polls at a time' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
    SELECT o.poll_id, o.id AS option_id, count(v.id) AS vote_count,
           coalesce(bool_or(v.user_id = (SELECT auth.uid())), false) AS is_my_vote
    FROM public.post_poll_options o
    LEFT JOIN public.post_poll_votes v ON v.option_id = o.id AND v.poll_id = o.poll_id
    WHERE o.poll_id = ANY(requested_poll_ids)
    GROUP BY o.poll_id, o.id;
END;
$function$;

-- Group-chat participants must not bypass another founder's closed-DM setting.
CREATE OR REPLACE FUNCTION public.create_group_conversation(group_title text, participant_ids uuid[])
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  current_user_id uuid := auth.uid();
  member_ids uuid[];
  new_conversation_id uuid;
  member_count integer;
BEGIN
  IF current_user_id IS NULL THEN RAISE EXCEPTION 'You must be signed in to create a group chat.' USING ERRCODE = '42501'; END IF;
  IF group_title IS NULL OR pg_catalog.length(pg_catalog.btrim(group_title)) < 2 OR pg_catalog.length(pg_catalog.btrim(group_title)) > 80 THEN
    RAISE EXCEPTION 'Group name must be between 2 and 80 characters.' USING ERRCODE = '22023';
  END IF;
  SELECT pg_catalog.array_agg(x ORDER BY x) INTO member_ids
  FROM (SELECT DISTINCT unnest(coalesce(participant_ids, array[]::uuid[])) AS x UNION SELECT current_user_id) ids;
  member_count := coalesce(pg_catalog.cardinality(member_ids),0);
  IF member_count < 3 OR member_count > 20 THEN RAISE EXCEPTION 'Group chats must have 3 to 20 members, including you.' USING ERRCODE = '22023'; END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.unnest(member_ids) AS candidate(user_id) WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=candidate.user_id)) THEN
    RAISE EXCEPTION 'One or more selected founder profiles could not be found.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM public.user_blocks b WHERE b.blocker_id=ANY(member_ids) AND b.blocked_id=ANY(member_ids)) THEN
    RAISE EXCEPTION 'A group chat cannot include members who have blocked one another.' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.unnest(member_ids) AS candidate(user_id)
    WHERE candidate.user_id <> current_user_id
      AND NOT coalesce((SELECT s.public_dms FROM public.account_settings s WHERE s.user_id=candidate.user_id), true)
      AND NOT EXISTS (SELECT 1 FROM public.follows f WHERE f.follower_id=current_user_id AND f.following_id=candidate.user_id)
  ) THEN
    RAISE EXCEPTION 'One or more founders only accept messages from people they follow. Follow them before adding them to a group chat.' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.conversations (is_group,title,created_by) VALUES (true,pg_catalog.btrim(group_title),current_user_id) RETURNING id INTO new_conversation_id;
  INSERT INTO public.conversation_members (conversation_id,user_id) SELECT new_conversation_id,member_id FROM pg_catalog.unnest(member_ids) AS members(member_id);
  RETURN new_conversation_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_poll_results(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_poll_results(uuid[]) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.create_group_conversation(text, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_group_conversation(text, uuid[]) TO authenticated, service_role;
