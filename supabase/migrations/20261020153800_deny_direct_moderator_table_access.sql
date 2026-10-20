-- Keep the moderator roster private even if direct table grants are added later.
-- SECURITY DEFINER moderation RPCs perform explicit auth.uid() and moderator checks.
CREATE POLICY moderators_no_direct_access
  ON private.moderators
  FOR ALL
  TO anon, authenticated
  USING (false)
  WITH CHECK (false);
