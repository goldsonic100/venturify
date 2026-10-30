-- Keep account preferences private to the authenticated account owner.
-- The existing RLS policies remain the row-level boundary; table grants now
-- ensure anonymous clients cannot reach this private settings table at all.
REVOKE ALL PRIVILEGES ON TABLE public.account_settings FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.account_settings FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.account_settings TO authenticated;

DROP POLICY IF EXISTS "Users can create their own account settings" ON public.account_settings;
DROP POLICY IF EXISTS "Users can read their own account settings" ON public.account_settings;
DROP POLICY IF EXISTS "Users can update their own account settings" ON public.account_settings;

CREATE POLICY "Users can create their own account settings"
ON public.account_settings
FOR INSERT
TO authenticated
WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can read their own account settings"
ON public.account_settings
FOR SELECT
TO authenticated
USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can update their own account settings"
ON public.account_settings
FOR UPDATE
TO authenticated
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);
