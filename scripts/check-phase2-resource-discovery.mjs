import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../resources.html', import.meta.url), 'utf8');
assert.match(html, /id="resourceSearch"/, 'Resource hub must include keyword search.');
assert.match(html, /id="resourceCategory"/, 'Resource hub must include a goal/category filter.');
assert.match(html, /data-resource-tags="learn"/, 'Learning pathways must be categorized.');
assert.match(html, /data-resource-tags="people"/, 'People pathways must be categorized.');
assert.match(html, /data-resource-tags="build people"/, 'Collaboration pathways must support multiple categories.');
assert.match(html, /data-resource-tags="share learn"/, 'Story-sharing must connect to learning.');
assert.match(html, /aria-live="polite"/, 'Result count must be announced accessibly.');
assert.match(html, /No pathways match that search/, 'Empty search results must offer recovery guidance.');
assert.match(html, /@media\(max-width:650px\)\{\.resource-tools\{grid-template-columns:1fr\}/, 'Search controls must stack on mobile.');
assert.match(html, /cards\.forEach\(card=>/, 'Filter must update existing resource cards.');
assert.match(html, /Venturify|fictional examples/, 'Resource hub must preserve trust context.');
console.log('Phase 2 resource discovery contracts passed.');
