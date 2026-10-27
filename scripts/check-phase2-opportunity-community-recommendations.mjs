import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../communities.html', import.meta.url), 'utf8');

// Recommendations use only existing opportunity records and public descriptive fields.
assert.match(html, /from\('posts'\)\.select\('id,post_type,topic_tags,content,opportunity_offer,opportunity_need,created_at'\)/,
  'Recommendations should query only fields already used to describe existing opportunities.');
assert.match(html, /\.in\('post_type',\['idea','resource','lesson'\]\)/,
  'Only existing opportunity-style post types should be recommended.');
assert.match(html, /communityTokens\.filter\(t=>opportunityTokens\.includes\(t\)\)/,
  'Community relevance should be based on overlapping topic tokens.');
assert.match(html, /\.filter\(x=>x\.score>0\)/,
  'Do not show recommendations when no topic tokens match.');
assert.match(html, /\.slice\(0,2\)\.map\(x=>x\.post\)/,
  'Keep community opportunity previews limited to two existing records.');
assert.match(html, /Related opportunities/,
  'Community tiles should clearly label the opportunity recommendations.');
assert.match(html, /esc\(short\|\|/,
  'Opportunity text must be escaped before rendering.');
assert.match(html, /data-community-view=/,
  'Existing community-feed navigation must remain available.');
assert.match(html, /data-community-join=/,
  'Existing join controls must remain available.');

console.log('Phase 2 opportunity/community recommendation contract passed.');
