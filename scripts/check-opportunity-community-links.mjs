import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const feed = read('index.html');
const communities = read('communities.html');

assert.ok(feed.includes('communities.html?q=\'+encodeURIComponent(communityQuery)'), 'Opportunity cards without a community must link to a related community search.');
assert.ok(feed.includes("const communityQuery=(p.topic_tags||[]).slice(0,3).join(' ')"), 'Community search should use opportunity topic tags when available.');
assert.ok(communities.includes("new URLSearchParams(window.location.search).get('q')"), 'Community discovery must read the prefilled query parameter.');
assert.ok(communities.includes("$('communitySearch').value=requestedCommunityQuery"), 'Community discovery must populate the search input from the incoming query.');
assert.ok(communities.includes("$('communitySearch').addEventListener('input',renderCommunityLists)"), 'Prefilled community search must use the existing community filtering logic.');
console.log('Opportunity-to-community discovery link contracts passed.');
