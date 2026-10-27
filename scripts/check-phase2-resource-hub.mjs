import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../resources.html', import.meta.url), 'utf8');
const readme = readFileSync(new URL('../docs/phase2-roadmap.md', import.meta.url), 'utf8');

assert.match(html, /<meta name="viewport" content="width=device-width, initial-scale=1">/,
  'Resource hub must remain responsive.');
assert.match(html, /<a class="skip-link" href="#main-content">Skip to main content<\/a>/,
  'Resource hub must provide a keyboard skip link.');
assert.match(html, /<main id="main-content"/,
  'Resource hub must provide the skip-link target.');
for (const destination of [
  'case-studies.html', 'feed.html', 'communities.html',
  'collaborations.html', 'discover.html', 'share-story.html', 'principles.html'
]) {
  assert.ok(html.includes('href="' + destination + '"'),
    'Resource hub must link to the existing ' + destination + ' destination.');
}
assert.match(html, /fictional examples/i,
  'Resource hub must not present demo case studies as verified stories.');
assert.match(html, /do not submit confidential documents/i,
  'Resource hub must communicate current submission limitations.');
assert.match(readme, /Audit the existing case-study and story experience/,
  'Phase 2 roadmap must record the resource data audit.');
console.log('Phase 2 resource hub contracts passed.');
