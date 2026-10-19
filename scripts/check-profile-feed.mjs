import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const files = {
  profile: readFileSync(new URL('../profile.html', import.meta.url), 'utf8'),
  feed: readFileSync(new URL('../feed.html', import.meta.url), 'utf8'),
};

function parseInlineScripts(name, html) {
  const scripts = [...html.matchAll(/<script\\b[^>]*>([\\s\\S]*?)<\\/script>/gi)]
    .filter(([, source]) => source.trim());
  assert.ok(scripts.length > 0, `${name}.html should contain application scripts`);
  for (const [index, [, source]] of scripts.entries()) {
    try {
      // Compile only; never execute browser code or contact Supabase.
      new Function(source);
    } catch (error) {
      throw new Error(`${name}.html inline script ${index + 1} failed to parse: ${error.message}`);
    }
  }
}

for (const [name, html] of Object.entries(files)) parseInlineScripts(name, html);

const profile = files.profile;
for (const id of [
  'profileHeadline', 'profileCompany', 'profileSkills', 'profileInterests',
  'profileLookingFor', 'profileAvatarUrl', 'profileWebsite', 'profileLinkedin',
]) {
  assert.ok(profile.includes(`id="${id}"`), `Profile editor must retain #${id}`);
}
assert.match(profile, /safeProfileUrl\\s*=\\s*value\\s*=>/, 'Profile URLs must use the safe URL helper');
assert.match(profile, /profileClient\\.from\\(['"]follows['"]\\)/, 'Profiles must retain follower/following data');
assert.match(profile, /profileClient\\.from\\(['"]posts['"]\\)/, 'Profiles must retain recent posts');
assert.match(profile, /@media\\s*\\(max-width:\\s*760px\\)/, 'Profiles must retain a mobile breakpoint');

// Guard the reputation breakdown against the malformed concatenation fixed in PR #25.
for (const fragment of [
  "'+ageDays.toLocaleString()+'",
  "'+followerPoints.toLocaleString()+'",
  "'+postPoints.toLocaleString()+'",
  "'+totalComments.toLocaleString()+'",
  "'+communityPoints.toLocaleString()+'",
  "'+profileCompletenessPoints.toLocaleString()+'",
]) {
  assert.ok(profile.includes(fragment), `Reputation breakdown is missing expected expression: ${fragment}`);
}
assert.ok(!profile.includes("<strong>+'ageDays.toLocaleString()'</strong>"), 'Malformed account-age points markup must not return');

const feed = files.feed;
for (const control of ['data-like=', 'data-focus=', 'data-bookmark=', 'data-submit-reply=']) {
  assert.ok(feed.includes(control), `Feed must retain ${control} interaction`);
}
assert.match(feed, /maxlength=["']500["']/i, 'Comment inputs must remain length-limited');
assert.match(feed, /function\\s+loginRequired|const\\s+loginRequired\\s*=/, 'Feed must retain login gating for interactions');
assert.match(feed, /@media\\s*\\(max-width:\\s*760px\\)/, 'Feed must retain a mobile breakpoint');

console.log('Profile/feed regression checks passed (scripts parsed; no live services called).');
