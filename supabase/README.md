# Venturify + Supabase

This folder contains the first database schema for the real multi-user community.

## Included
- Auth-linked founder profiles
- Public posts; only authors can edit/delete their own posts
- Comments, likes, and follows
- Private notifications for follows, likes, and comments
- Row Level Security (RLS) policies for all exposed tables

## Setup
1. Create a project at https://supabase.com/ if you have not already.
2. Open Supabase Dashboard -> SQL Editor -> New query.
3. Copy all of schema.sql into the editor and run it.
4. In Authentication -> URL Configuration, set your site URL to the deployed Venturify URL. Add your local development URL to Redirect URLs if needed.
5. In Authentication -> Providers, enable Email and configure email confirmation/password reset.
6. In Project Settings -> API (or Connect), copy the Project URL and publishable/anon key for frontend integration.

## Frontend key safety
The Supabase publishable key (or legacy anon key) is designed for browser use when Row Level Security is configured correctly. Never put a service_role key or any secret key in frontend code or commit it to GitHub. Do not send secret keys in chat.

## Not included yet
Direct messages, image storage, groups, admin moderation, reporting/blocking, and rate limits are future work. Test in a development project with two accounts before inviting real users. A public launch needs moderation and abuse controls, too.
