# Venturify Pro — private development draft

**Status:** Not released. This draft lives on the `draft/pro-plan-and-free-limits` branch and is not loaded by the live website.

## Free plan

- Unlimited community creation.
- Unlimited founder follows and co-founder connections.
- Unlimited posts.
- Basic founder profile and community participation.

## Venturify Pro — proposed features

- **Advanced founder discovery:** filter by skills, location, startup/company, and people open to co-founding or collaborating.
- **Special profile styling:** Pro badge and enhanced profile customization.
- **Community management:** advanced moderation and management tools.
- **Self-serve ads:** Pro members can draft an ad with a title, description, optional image, and destination link.
- **Sponsored placements:** approved ads may occasionally appear in the feed, clearly labeled **Sponsored**. Clicks should be tracked separately from normal links.

## Safety, trust, and launch requirements

1. Ads must be reviewed before they can run. A new ad starts in `draft` and should move through `pending_review` to `approved`.
2. Clearly label ads as sponsored and show who paid for them.
3. Validate destinations and use HTTPS links; provide report/block tools and a moderation process.
4. Add frequency caps so the feed is not overwhelmed by ads.
5. Track impressions and clicks with server-side checks to reduce accidental or repeated click inflation.
6. Pro status must be verified by trusted server-side subscription data. Do not let a browser-only profile field grant paid features.
7. Before launch, create database tables/RLS policies for subscriptions, ads, review status, impressions, and clicks; add payment-provider webhooks; test with two accounts.
8. Choose pricing and cancellation/refund rules before enabling payments.

## Current implementation in this branch

`drafts/pro-plan.js` contains a draft entitlement model, free-plan unlimited defaults, advanced founder filtering, a Pro badge renderer, ad-draft validation, and a renderer for approved sponsored cards.

It is deliberately not imported into `index.html`. This is not yet a complete subscription, payment, moderation, or analytics system.
