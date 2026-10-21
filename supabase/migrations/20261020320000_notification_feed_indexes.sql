-- Speed up the notification feed and unread badge without indexing unrelated rows.
create index if not exists notifications_recipient_created_at_idx
  on public.notifications (recipient_id, created_at desc);
create index if not exists notifications_recipient_unread_idx
  on public.notifications (recipient_id)
  where read_at is null;