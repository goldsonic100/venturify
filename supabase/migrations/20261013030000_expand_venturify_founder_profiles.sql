-- Expanded public founder profiles for Venturify.
-- Existing profiles and policies are preserved; these are additive columns only.
alter table public.profiles
  add column if not exists headline text not null default '',
  add column if not exists company text not null default '',
  add column if not exists location text not null default '',
  add column if not exists skills text not null default '',
  add column if not exists looking_for text not null default '',
  add column if not exists avatar_url text not null default '',
  add column if not exists website_url text not null default '',
  add column if not exists linkedin_url text not null default '';

alter table public.profiles
  drop constraint if exists profiles_headline_length_check,
  drop constraint if exists profiles_company_length_check,
  drop constraint if exists profiles_location_length_check,
  drop constraint if exists profiles_skills_length_check,
  drop constraint if exists profiles_looking_for_length_check,
  drop constraint if exists profiles_avatar_url_length_check,
  drop constraint if exists profiles_website_url_length_check,
  drop constraint if exists profiles_linkedin_url_length_check;

alter table public.profiles
  add constraint profiles_headline_length_check check (char_length(headline) <= 100),
  add constraint profiles_company_length_check check (char_length(company) <= 100),
  add constraint profiles_location_length_check check (char_length(location) <= 100),
  add constraint profiles_skills_length_check check (char_length(skills) <= 240),
  add constraint profiles_looking_for_length_check check (char_length(looking_for) <= 160),
  add constraint profiles_avatar_url_length_check check (char_length(avatar_url) <= 500),
  add constraint profiles_website_url_length_check check (char_length(website_url) <= 300),
  add constraint profiles_linkedin_url_length_check check (char_length(linkedin_url) <= 300);
