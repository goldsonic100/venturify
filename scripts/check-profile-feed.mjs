import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const files = {
  profile: readFileSync(new URL('../profile.html', import.meta.url), 'utf8'),
  feed: readFileSync(new URL('../feed.html', import.meta.url), 'utf8'),
  settings: readFileSync(new URL('../settings.html', import.meta.url), 'utf8'),
};

function parseInlineScripts(name, html) {
  const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)]
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
assert.match(profile, /safeProfileUrl\s*=\s*value\s*=>/, 'Profile URLs must use the safe URL helper');
assert.match(profile, /profileClient\.from\(['"]follows['"]\)/, 'Profiles must retain follower/following data');
assert.match(profile, /profileClient\.from\(['"]posts['"]\)/, 'Profiles must retain recent posts');
assert.match(profile, /@media\s*\(max-width:\s*760px\)/, 'Profiles must retain a mobile breakpoint');

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
assert.match(feed, /function\s+loginRequired|const\s+loginRequired\s*=/, 'Feed must retain login gating for interactions');
assert.match(feed, /@media\s*\(max-width:\s*760px\)/, 'Feed must retain a mobile breakpoint');

console.log('Profile/feed regression checks passed (scripts parsed; no live services called).');

assert.ok(profile.includes('id="accountStatus" role="status" aria-live="polite" aria-atomic="true"'), 'Profile save feedback should be announced accessibly');

assert.ok(feed.includes('id="postCharacterCount" role="status" aria-live="polite" aria-atomic="true"'), 'Post composer should announce remaining character count accessibly');
assert.ok(feed.includes("1200-$('postText').value.length") && feed.includes("character-limit-near"), 'Post composer character count should update live and flag the final 120 characters');


// Settings tabs must remain complete, keyboard accessible, and connected to their panels.
const settings = readFileSync(new URL('../settings.html', import.meta.url), 'utf8');
parseInlineScripts('settings', settings);
const settingTabs = [...settings.matchAll(/<button[^>]*data-section="([^"]+)"[^>]*>/g)].map(match => match[1]);
assert.deepEqual(settingTabs, ['privacy', 'features', 'notifications', 'appearance', 'security'], 'Settings navigation tabs/order must remain complete');
for (const section of settingTabs) {
  assert.ok(settings.includes('id="section-' + section + '"'), 'Settings tab "' + section + '" needs a matching section');
  assert.ok(settings.includes('aria-controls="section-' + section + '"'), 'Settings tab "' + section + '" needs an accessible panel association');
}
assert.match(settings, /querySelectorAll\(['"]\[data-section\]['"]\)/, 'Settings tabs must be discovered by the navigation handler');
assert.match(settings, /button\.addEventListener\('click',\(\)=>activate\(button/, 'Settings tabs must activate their panel when clicked');
assert.match(settings, /section\.hidden\s*=\s*!active/, 'Settings navigation must hide inactive sections');
assert.match(settings, /event\.key==='ArrowDown'\|\|event\.key==='ArrowRight'/, 'Settings tabs must support keyboard arrow navigation');
assert.match(settings, /id="saveSettings"/, 'Settings must retain its save control');
assert.match(settings, /id="status"[^>]*aria-live="polite"/, 'Settings must retain an accessible save/error status');


assert.ok(settings.includes("window.addEventListener('beforeunload',event=>{if(!dirty)return;event.preventDefault();event.returnValue=''})"), 'Settings should warn before navigation when changes have not been saved');


assert.ok(settings.includes("try{const payload={user_id:user.id,updated_at:new Date().toISOString()}") && settings.includes("finally{save.disabled=false}"), 'Settings save button must recover even if the network request throws');
assert.ok(settings.includes('Your changes are still on this page; try again.'), 'Settings save failures should preserve the user edits and explain how to recover');


assert.ok(settings.includes("save.dataset.dirty='true';save.textContent='Save changes'"), 'Settings save action should clearly indicate when there are unsaved changes');
assert.ok(settings.includes("save.dataset.dirty='false';save.textContent='Save settings'"), 'Settings save action should return to its normal state after loading or saving preferences');


assert.ok(files.settings.includes('id="discardSettings" disabled') && settingsHtml.includes("discard.addEventListener('click',()=>{if(!dirty)return;apply(savedValues)"), 'Settings should allow restoring the last saved values without writing to the database');
assert.ok(settingsHtml.includes('savedValues=captureSettings()') && settingsHtml.includes('discard.disabled=true'), 'Successful saves should become the new reset baseline and disable discard');
