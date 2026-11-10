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
assert.match(html, /id="opportunitySort"[\s\S]{0,180}value="best_fit"/,\n  'Opportunity discovery must let members prioritize opportunities that fit their profile.');\nassert.match(html, /profile\\?\.skills[\\s\\S]{0,800}opportunity_need/,\n  'Best-fit sorting must compare member skills with the requested help field.');\nassert.match(html, /opportunityFitNotice/,\n  'Personalized sorting must explain when profile information is missing and how fit is calculated.');\nassert.match(html, /opportunity-discovery-tools/,
  'Discovery controls must have a dedicated responsive layout.');
assert.match(html, /@media\(max-width:520px\)\{\.opportunity-discovery-tools/,
  'Discovery controls must stack on narrow screens.');
console.log('Phase 2 opportunity discovery contracts passed.');
