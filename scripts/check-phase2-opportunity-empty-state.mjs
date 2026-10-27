import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');

assert.match(html, /mode==='opportunities'\?'No opportunities match these filters/,
  'An empty filtered opportunity list must explain that filters caused the empty result.');
assert.match(html, /Try another keyword, project stage, or opportunity type/,
  'The empty state must suggest useful ways to recover results.');
assert.match(html, /mode==='saved'\?'No saved posts yet/,
  'The existing saved-post empty state must remain intact.');
assert.match(html, /No posts from people you follow yet/,
  'The existing following-feed empty state must remain intact.');
console.log('Phase 2 opportunity empty-state contracts passed.');
