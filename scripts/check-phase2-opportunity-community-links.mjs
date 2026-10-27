import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');

// Opportunities already attached to a community should provide a direct route
// into that community's feed. Do not infer or fabricate a community association.
assert.match(html, /data-opportunity-community=/,
  'Opportunity cards should expose a community-feed action when a community exists.');
assert.match(html, /button\.dataset\.opportunityCommunity/,
  'The community action should read the existing community ID from the button.');
assert.match(html, /communities\.some\(c=>c\.id===communityId\)/,
  'The action must validate the requested ID against loaded community records.');
assert.match(html, /currentCommunityId=communityId;updateCommunityContext\(\);await feed\(\)/,
  'The action should switch the existing feed context rather than creating a parallel data path.');

// Keep the existing collaboration request flow and opportunity controls intact.
assert.match(html, /data-collaboration-request=/,
  'Existing collaboration request actions must remain available.');
assert.match(html, /data-opportunity-interest=/,
  'Existing opportunity-interest actions must remain available.');

console.log('Phase 2 opportunity/community link contract passed.');
