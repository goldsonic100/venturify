-- Support reviewer-profile deletes and joins on the review-history table.
create index if not exists founder_postmortem_reviews_reviewer_id_idx
  on public.founder_postmortem_reviews (reviewer_id)
  where reviewer_id is not null;
