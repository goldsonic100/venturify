-- Expose only a trusted verification flag to public profile reads so guest
-- discovery can respect the verified-founder rule without exposing an anon-
-- callable SECURITY DEFINER discovery RPC.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email_verified boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION private.enforce_profile_email_verification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  NEW.email_verified := EXISTS (
    SELECT 1
    FROM auth.users au
    WHERE au.id = NEW.id
      AND au.email_confirmed_at IS NOT NULL
  );
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.enforce_profile_email_verification() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS enforce_profile_email_verification ON public.profiles;
CREATE TRIGGER enforce_profile_email_verification
  BEFORE INSERT OR UPDATE OF id, email_verified ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION private.enforce_profile_email_verification();

CREATE OR REPLACE FUNCTION private.sync_profile_email_verification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  UPDATE public.profiles
  SET email_verified = (NEW.email_confirmed_at IS NOT NULL)
  WHERE id = NEW.id;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.sync_profile_email_verification() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS sync_profile_email_verification ON auth.users;
CREATE TRIGGER sync_profile_email_verification
  AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION private.sync_profile_email_verification();

-- Backfill existing accounts from the source of truth in auth.users.
UPDATE public.profiles p
SET email_verified = (au.email_confirmed_at IS NOT NULL)
FROM auth.users au
WHERE au.id = p.id;
