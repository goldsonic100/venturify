import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../messages.html', import.meta.url), 'utf8');
assert.match(html, /\.limit\(1000\)/, 'Contact picker must load enough profiles that eligible people are not hidden by a 40-profile cap.');
assert.match(html, /client\.rpc\('get_messageable_founder_ids'\)/, 'Recipient eligibility must be sourced from the server-side eligibility RPC.');
assert.match(html, /access\.error\?\(fr\.data\|\|\[\]\)\.map\(x=>x\.following_id\)/, 'If eligibility lookup fails, recipient selection must fail closed to accounts the current user follows.');
assert.match(html, /const visiblePeople=people\.filter\(p=>messageableFounderIds\.has\(p\.id\)\)/, 'New direct-chat options must be limited to eligible recipients.');
assert.match(html, /people\.filter\(p=>messageableFounderIds\.has\(p\.id\)\)/, 'Group participants must be limited to eligible recipients.');
assert.match(html, /if\(participant_ids\.some\(id=>!messageableFounderIds\.has\(id\)\)\)/, 'Group creation must recheck eligibility before submitting selected participants.');
assert.match(html, /No eligible contacts yet — follow a founder or ask them to enable public DMs/, 'Empty contact picker must explain how to become eligible.');
console.log('Eligible message recipient picker contracts passed.');
