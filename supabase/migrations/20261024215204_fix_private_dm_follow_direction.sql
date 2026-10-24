-- Align private-DM eligibility with the account setting's documented meaning.
-- When public DMs are off, the recipient must follow the sender. Existing
-- direct conversations remain eligible so privacy changes do not strand chats.

CREATE OR REPLACE FUNCTION public.get_messageable_founder_ids()
RETURNS TABLE(founder_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT p.id
  FROM public.profiles p
  WHERE p.id <> (SELECT auth.uid())
    AND (
      COALESCE((SELECT s.public_dms FROM public.account_settings s WHERE s.user_id = p.id), true)
      OR EXISTS (
        SELECT 1
        FROM public.follows f
        WHERE f.follower_id = p.id
          AND f.following_id = (SELECT auth.uid())
      )
      OR EXISTS (
        SELECT 1
        FROM public.conversation_members mine
        JOIN public.conversation_members theirs
          ON theirs.conversation_id = mine.conversation_id
        JOIN public.conversations c ON c.id = mine.conversation_id
        WHERE mine.user_id = (SELECT auth.uid())
          AND theirs.user_id = p.id
          AND c.is_group = false
      )
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_blocks b
      WHERE (b.blocker_id = (SELECT auth.uid()) AND b.blocked_id = p.id)
         OR (b.blocked_id = (SELECT auth.uid()) AND b.blocker_id = p.id)
    );
$function$;

-- Keep the group-chat RPC consistent with the inbox eligibility lookup.
CREATE OR REPLACE FUNCTION public.create_group_conversation(group_title text, participant_ids uuid[])
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  current_user_id uuid := auth.uid();
  member_ids uuid[];
  new_conversation_id uuid;
  member_count integer;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to create a group chat.' USING ERRCODE = '42501';
  END IF;
  IF group_title IS NULL OR pg_catalog.length(pg_catalog.btrim(group_title)) < 2 OR pg_catalog.length(pg_catalog.btrim(group_title)) > 80 THEN
    RAISE EXCEPTION 'Group name must be between 2 and 80 characters.' USING ERRCODE = '22023';
  END IF;

  SELECT pg_catalog.array_agg(x ORDER BY x) INTO member_ids
  FROM (
    SELECT DISTINCT unnest(COALESCE(participant_ids, ARRAY[]::uuid[])) AS x
    UNION SELECT current_user_id
  ) ids;
  member_count := COALESCE(pg_catalog.cardinality(member_ids), 0);
  IF member_count < 3 OR member_count > 20 THEN
    RAISE EXCEPTION 'Group chats must have 3 to 20 members, including you.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.unnest(member_ids) AS candidate(user_id)
    WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = candidate.user_id)
  ) THEN
    RAISE EXCEPTION 'One or more selected founder profiles could not be found.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.user_blocks b
    WHERE b.blocker_id = ANY(member_ids) AND b.blocked_id = ANY(member_ids)
  ) THEN
    RAISE EXCEPTION 'A group chat cannot include members who have blocked one another.' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.unnest(member_ids) AS candidate(user_id)
    WHERE candidate.user_id <> current_user_id
      AND NOT COALESCE(
        (SELECT s.public_dms FROM public.account_settings s WHERE s.user_id = candidate.user_id),
        true
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.follows f
        WHERE f.follower_id = candidate.user_id
          AND f.following_id = current_user_id
      )
  ) THEN
    RAISE EXCEPTION 'One or more founders only accept messages from founders who follow them. They must follow you before you can add them to a group chat.' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.conversations (is_group, title, created_by)
  VALUES (true, pg_catalog.btrim(group_title), current_user_id)
  RETURNING id INTO new_conversation_id;
  INSERT INTO public.conversation_members (conversation_id, user_id)
  SELECT new_conversation_id, member_id
  FROM pg_catalog.unnest(member_ids) AS members(member_id);
  RETURN new_conversation_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_messageable_founder_ids() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_messageable_founder_ids() TO authenticated;
REVOKE ALL ON FUNCTION public.create_group_conversation(text, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_group_conversation(text, uuid[]) TO authenticated, service_role;
