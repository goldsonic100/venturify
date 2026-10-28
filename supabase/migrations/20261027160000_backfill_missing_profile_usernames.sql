-- Give existing profiles with blank usernames a stable, public handle.
-- This avoids the UI falling back to the same generic "@founder" label.
-- 19 hexadecimal characters plus "user_" stays within the 24-character handle limit.
UPDATE public.profiles
SET username = 'user_' || left(replace(id::text, '-', ''), 19)
WHERE username IS NULL OR btrim(username) = '';

