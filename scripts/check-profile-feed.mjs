import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const files = {
  profile: readFileSync(new URL('../profile.html', import.meta.url), 'utf8'),
  feed: readFileSync(new URL('../feed.html', import.meta.url), 'utf8'),
};

function compileInlineScripts(name, html) {
  const scripts = [...html.matchAll(/<script\\b[^>]*>([\\s\\S]*?)<\\/script>/gi)]
    .filter(([, source]) => source.trim());
  assert.ok(scripts.length, `${name}.html should contain inline application scripts`);
  for (const [index, match] of scripts.entries()) {
    try {
      // Parse only: do not execute browser code or connect to Supabase.
      new Function(match[1]);
    } catch (error) {
      throw new Error(`${name}.html inline script ${index + 1} has a syntax error: ${error.message}`);
    }
  }
}

for (const [name, html] of Object.entries(files)) compileInlineScripts(name, html);

const profile = files.profile;
for (const id of [
  'profileHeadline', 'profileCompany', 'profileSkills', 'profileInterests',
  'profileLookingFor', 'profileAvatarUrl', 'profileWebsite', 'profileLinkedin'
]) {
  assert.match(profile, new RegExp('id=["\\']' + id + '["\\']'), `Profile editor must retain #${id}`);
}
assert.match(profile, /safeProfileUrl\s*=\s*value\s*=>/, 'Profile URLs must pass through the safe URL helper');
assert.match(profile, /profileClient\.from\(['"]follows['"]\)/, 'Public profiles should keep follower/following data');
assert.match(profile, /profileClient\.from\(['"]posts['"]\)/, 'Public profiles should keep recent posts');

const feed = files.feed;
for (const control of ['data-like=', 'data-focus=', 'data-bookmark=', 'data-submit-reply=']) {
  assert.ok(feed.includes(control), `Feed must retain the ${control} interaction`);
}
assert.match(feed, /maxlength=["']500["']/i, 'Comment inputs should remain length-limited');
assert.match(feed, /function\s+loginRequired|const\s+loginRequired\s*=/, 'Feed should retain the login gate for interactions');
assert.match(feed, /@media\s*\(max-width:\s*760px\)/, 'Feed should retain a mobile layout breakpoint');
assert.match(profile, /@media\s*\(max-width:\s*760px\)/, 'Profile should retain a mobile layout breakpoint');

console.log('Profile/feed regression checks passed (scripts parsed; no live services called).');
