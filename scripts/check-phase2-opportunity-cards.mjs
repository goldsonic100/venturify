import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');

assert.match(html, /class="opportunity-card"/,
  'Opportunity posts must use the dedicated card layout.');
assert.match(html, /Help or resources requested/,
  'Opportunity cards must label the help/resources request clearly.');
assert.match(html, /The idea/,
  'Idea cards must label the offer or idea.');
assert.match(html, /What I can offer/,
  'Resource cards must label what the author can offer.');
assert.match(html, /Experience shared/,
  'Lesson cards must label the experience shared.');
assert.match(html, /opportunity_stage/,
  'Opportunity cards must preserve the existing project-stage field.');
assert.match(html, /Stage not specified/,
  'Cards must distinguish an unspecified stage from a real stage.');
assert.match(html, /Request collaboration/,
  'Opportunity cards must preserve the existing collaboration request path.');
assert.match(html, /data-opportunity-interest/,
  'Opportunity cards must preserve the existing discussion path.');
assert.match(html, /Manage responses/,
  'Authors must have a clear route to manage collaboration responses.');
assert.match(html, /@media\(max-width:520px\)\{\.opportunity-card/,
  'Opportunity cards must adapt their actions for narrow screens.');
console.log('Phase 2 opportunity card contracts passed.');
