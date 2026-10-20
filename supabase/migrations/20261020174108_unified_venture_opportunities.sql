-- Extend the existing social feed with structured founder ecosystem posts.
-- Existing standard posts and polls remain valid and unchanged.
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS opportunity_offer text,
  ADD COLUMN IF NOT EXISTS opportunity_need text,
  ADD COLUMN IF NOT EXISTS opportunity_stage text;

ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_post_type_check;
ALTER TABLE public.posts
  ADD CONSTRAINT posts_post_type_check
  CHECK (post_type = ANY (ARRAY['standard'::text, 'poll'::text, 'idea'::text, 'resource'::text, 'lesson'::text]));

ALTER TABLE public.posts
  ADD CONSTRAINT posts_opportunity_offer_length
  CHECK (opportunity_offer IS NULL OR char_length(opportunity_offer) <= 800);
ALTER TABLE public.posts
  ADD CONSTRAINT posts_opportunity_need_length
  CHECK (opportunity_need IS NULL OR char_length(opportunity_need) <= 800);
ALTER TABLE public.posts
  ADD CONSTRAINT posts_opportunity_stage_length
  CHECK (opportunity_stage IS NULL OR char_length(opportunity_stage) <= 80);
