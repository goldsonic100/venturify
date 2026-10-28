import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
assert.match(html, /if\(currentUser&&!q\.length\)list=list\.filter\(p=>dailyMatchIds\.includes\(p\.id\)\)/,
  'Daily personalized recommendations should be limited to six per day only when no explicit search is entered.');
assert.match(html, /const hay=\[p\.id,p\.display_name,p\.username/,
  'Profile search must include the account ID so exact UUID searches can match.');
assert.match(html, /communityCounts\.get\(p\.id\)\|\|0\)>=1&&founderLevel\(p\)>=5/,
  'Search results must preserve community membership and Level 5 eligibility.');
assert.match(html, /No founders match those filters yet\. Try another search or update your profile\./,
  'Empty search results must retain recovery guidance.');
console.log('Discover exact-ID search contracts passed.');
