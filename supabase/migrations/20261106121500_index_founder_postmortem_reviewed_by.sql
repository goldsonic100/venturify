-- Cover the reviewer foreign key for efficient moderator/account deletion checks.
create index if not exists founder_postmortems_reviewed_by_idx on public.founder_postmortems (reviewed_by);
