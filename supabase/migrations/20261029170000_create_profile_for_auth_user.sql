-- Ensure every new Supabase Auth user (including Google OAuth users) has a public profile.
-- The handle is deterministic, unique in practice, and within the app's 24-character limit.
-- Existing profiles and user-chosen handles are never overwritten.
CREATE OR REPLACE FUNCTION public.create_profile_for_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  generated_username text;
  generated_display_name text;
BEGIN
  generated_username := 'user_' || pg_catalog.left(
    pg_catalog.replace(NEW.id::text, '-', ''),
    19
  );

  generated_display_name := COALESCE(
    NULLIF(pg_catalog.btrim(NEW.raw_user_meta_data ->> 'display_name'), ''),
    NULLIF(pg_catalog.btrim(NEW.raw_user_meta_data ->> 'full_name'), ''),
    NULLIF(pg_catalog.btrim(NEW.raw_user_meta_data ->> 'name'), ''),
    NULLIF(pg_catalog.split_part(COALESCE(NEW.email, ''), '@', 1), ''),
    'Founder'
  );

  INSERT INTO public.profiles (id, username, display_name)
  VALUES (NEW.id, generated_username, generated_display_name)
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS on_auth_user_created_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_profile_for_auth_user();

REVOKE ALL ON FUNCTION public.create_profile_for_auth_user() FROM PUBLIC, anon, authenticated;
