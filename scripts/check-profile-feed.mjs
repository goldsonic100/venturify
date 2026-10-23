import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const files = {
  profile: readFileSync(new URL('../profile.html', import.meta.url), 'utf8'),
  feed: readFileSync(new URL('../feed.html', import.meta.url), 'utf8'),
  settings: readFileSync(new URL('../settings.html', import.meta.url), 'utf8'),
};

function parseInlineScripts(name, html) {
  const scripts = [...html.matchAll(/<script\\b[^>]*>([\\s\\S]*?)<\\/script>/gi)]
    .filter(([, source]) => source.trim());
  assert.ok(scripts.length > 0, name + '.html should contain application scripts');
  for (const [index, [, source]] of scripts.entries()) {
    try {
      // Compile only; never execute browser code or contact Supabase.
      new Function(source);
    } catch (error) {
      throw new Error(name + '.html inline script ' + (index + 1) + ' failed to parse: ' + error.message);
    }
  }
}

for (const [name, html] of Object.entries(files)) parseInlineScripts(name, html);

const profile = files.profile;
for (const id of [
  'profileHeadline', 'profileCompany', 'profileSkills', 'profileInterests',
  'profileLookingFor', 'profileAvatarUrl', 'profileWebsite', 'profileLinkedin',
]) {
  assert.ok(profile.includes('id="' + id + '"'), 'Profile editor must retain #' + id);
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
  assert.ok(profile.includes(fragment), 'Reputation breakdown is missing expected expression: ' + fragment);
}
assert.ok(!profile.includes("<strong>+'ageDays.toLocaleString()'</strong>"), 'Malformed account-age points markup must not return');

const feed = files.feed;
for (const control of ['data-like=', 'data-focus=', 'data-bookmark=', 'data-submit-reply=']) {
  assert.ok(feed.includes(control), 'Feed must retain ' + control + ' interaction');
}
assert.match(feed, /maxlength=["']500["']/i, 'Comment inputs must remain length-limited');
assert.match(feed, /function\\s+loginRequired|const\\s+loginRequired\\s*=/, 'Feed must retain login gating for interactions');
assert.match(feed, /@media\\s*\\(max-width:\\s*760px\\)/, 'Feed must retain a mobile breakpoint');

// Settings regression guards: every visible navigation tab must target a real section,
// and all account controls must remain wired to a save/status path.
const settings = files.settings;
const settingTabs = [...settings.matchAll(/<button[^>]*data-section="([^"]+)"[^>]*>/g)].map(match => match[1]);
assert.deepEqual(settingTabs, ['privacy', 'features', 'notifications', 'appearance', 'security'],
  'Settings navigation tabs/order must remain complete');
for (const section of settingTabs) {
  assert.ok(settings.includes('id="section-' + section + '"'), 'Settings tab "' + section + '" needs a matching section');
}
assert.match(settings, /querySelectorAll\\(['"]\\[data-section\\]['"]\\)/,
  'Settings tabs must have click handlers');
assert.match(settings, /section\\.hidden\\s*=\\s*!active/,
  'Settings navigation must hide inactive sections');
assert.match(settings, /id="saveSettings"/, 'Settings must retain its save control');
assert.match(settings, /id="status"[^>]*aria-live="polite"/,
  'Settings must announce save/error status accessibly');
for (const key of [
  'public_profile', 'public_dms', 'allow_collaboration_requests', 'show_in_discover',
  'enable_story_posts', 'enable_polls', 'enable_opportunities', 'notify_messages',
  'notify_reactions', 'notify_group_mentions',
]) {
  assert.ok(settings.includes('data-setting="' + key + '"'), 'Settings control is missing: ' + key);
}
assert.match(settings, /if\\(!client\\).*?save\\.disabled=true/s,
  'Settings save must fail safely when the Supabase browser client is unavailable');
assert.match(settings, /beforeunload/,
  'Settings must warn users about unsaved changes');

console.log('Profile/feed/settings regression checks passed (scripts parsed; no live services called).');
