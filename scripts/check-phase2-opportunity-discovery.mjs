import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');

assert.match(html, /id="opportunitySearch"/,
  'Opportunity discovery must offer keyword search.');
assert.match(html, /id="opportunityStageFilter"/,
  'Opportunity discovery must offer a project-stage filter.');
for (const stage of ['Exploring', 'Validating', 'Building', 'Launching', 'Growing', 'Post-mortem', 'unspecified']) {
  assert.ok(html.includes('value="' + stage + '"'),
    'Opportunity stage filter must include ' + stage + '.');
}
assert.match(html, /p\.opportunity_offer/,
  'Keyword matching must search the existing offer field.');
assert.match(html, /p\.opportunity_need/,
  'Keyword matching must search the existing requested-help field.');
assert.match(html, /p\.topic_tags/,
  'Keyword matching must include existing topic tags.');
assert.match(html, /opportunitySearchTimer=setTimeout/,
  'Keyword search must debounce input rather than reload for every keystroke.');
assert.match(html, /data-opportunity-filter/,
  'Existing idea/resource/lesson filters must remain available.');
assert.match(html, /opportunity-discovery-tools/,
  'Discovery controls must have a dedicated responsive layout.');
assert.match(html, /@media\(max-width:520px\)\{\.opportunity-discovery-tools/,
  'Discovery controls must stack on narrow screens.');
console.log('Phase 2 opportunity discovery contracts passed.');
