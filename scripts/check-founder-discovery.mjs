import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');

// Compile each inline script without executing browser code or touching Supabase.
const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)];
assert.ok(scripts.length > 0, 'index.html should contain inline scripts');
for (const [index, match] of scripts.entries()) {
  try {
    new Function(match[1]);
  } catch (error) {
    throw new Error('Inline script ' + (index + 1) + ' has a syntax error: ' + error.message);
  }
}

// Regression checks for the founder-discovery requirements.
assert.match(html, /communityCounts\.get\(p\.id\)\|\|0\)>=1&&founderLevel\(p\)>=5/,
  'Discovery must require at least one community and Level 5+');
assert.match(html, /Math\.min\(sharedInterestCount,3\)\*12/,
  'Daily ranking should prioritize shared interests');
assert.match(html, /Math\.min\(sharedInterests\.length,3\)\*12/,
  'Displayed match scores should prioritize shared interests');
assert.match(html, /reasons\.push\('Shared: '\+sharedInterests\.slice\(0,2\)\.join\(', '\)\)/,
  'Match explanations should show actual shared interests');
assert.match(html, /Match score '\+fit\.score\+'\/100/,
  'Cards should display match scores out of 100');
assert.match(html, /Math\.max\(0,6-dailyMatchIds\.length\)/,
  'Daily recommendations should retain the six-match limit');
assert.match(html, /data-discovery-follow=/,
  'Founder cards must retain the follow control');
assert.match(html, /data-profile=/,
  'Founder cards must retain the profile link');

console.log('Passed: ' + scripts.length + ' inline scripts parse; founder-discovery regression checks passed.');
