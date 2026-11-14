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
assert.ok(profile.includes('id="shareFounderProfile"'), 'Founder profiles must expose a share action');
assert.ok(profile.includes('id="profileShareStatus"') && profile.includes('aria-live="polite"'), 'Profile sharing feedback must be announced accessibly');
assert.match(profile, /new URL\(window\.location\.href\)/, 'Profile sharing must use the current profile URL');
assert.match(profile, /navigator\.share\(payload\)/, 'Profile sharing should use the native share sheet when available');
assert.match(profile, /navigator\.clipboard\.writeText\(url\.href\)/, 'Profile sharing must provide a clipboard fallback');
assert.match(profile, /document\.execCommand\('copy'\)/, 'Profile sharing must retain a legacy copy fallback');


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
assert.match(feed, /const feedFetchWindow\s*=\s*\(\)\s*=>\s*Math\.max\(999,Math\.max\(40,Number\(window\.venturifyFeedVisibleLimit\)\|\|40\)\+249\)/, 'Feed server fetch window must grow with the member-facing Show more limit');
assert.match(feed, /feedRequestVersion=0/, 'Feed should track the newest in-flight request');
assert.match(feed, /const requestVersion=\+\+feedRequestVersion,isStale=\(\)=>requestVersion!==feedRequestVersion/, 'Each feed load should identify whether a newer request superseded it');
assert.ok(feed.includes('if(isStale())return;'), 'Superseded feed requests must not render stale results or errors');
assert.ok((feed.match(/\.range\(0,feedFetchWindow\(\)\)/g)||[]).length >= 6, 'All time-ordered feed modes, including community and repost views, must use the expanding server window');
assert.match(feed, /if\(l\.disabled\)return;l\.disabled=true;l\.setAttribute\('aria-busy','true'\)/, 'Like actions must lock immediately to prevent duplicate in-flight requests');
assert.match(feed, /finally\{if\(l\.isConnected\)\{l\.disabled=false;l\.removeAttribute\('aria-busy'\)\}\}/, 'Like action controls must recover after failed requests without touching replaced DOM');
assert.match(feed, /function\s+loginRequired|const\s+loginRequired\s*=/, 'Feed must retain login gating for interactions');
assert.match(feed, /@media\s*\(max-width:\s*760px\)/, 'Feed must retain a mobile breakpoint');
for (const id of ['gettingStarted','gettingStartedProgress','gettingStartedTrack','gettingStartedBar','gettingStartedList','gettingStartedNote']) {
  assert.ok(feed.includes('id="' + id + '"'), 'Member onboarding checklist must include #' + id);
}
assert.match(feed, /async function updateGettingStarted\s*\(/, 'Member onboarding checklist must load real account progress');
assert.match(feed, /client\.from\(['"]follows['"]\)\.select\(['"]following_id['"]\)/, 'Onboarding must use the signed-in member follow state');
assert.match(feed, /client\.from\(['"]posts['"]\)\.select\(['"]id['"]\)\.eq\(['"]user_id['"],user\.id\)/, 'Onboarding must use the signed-in member post state');
assert.match(feed, /communityMemberships\.size>0/, 'Onboarding must reflect actual community membership');
assert.match(feed, /data-onboarding-focus/, 'Onboarding actions must focus the relevant existing workflow');
assert.match(feed, /await updateGettingStarted\(\)/, 'Onboarding progress must refresh after member actions');


assert.ok(files.feed.includes('comment-author profile-open') && files.feed.includes("data-profile=\"'+esc(r.user_id)+'\""), 'Reply authors should have clickable profile controls');
assert.ok(files.feed.includes("usernameBase+'_'+user.id.replace(/-/g,'').slice(0,8)") && files.profile.includes("usernameBase+'_'+user.id.replace(/-/g,'').slice(0,8)"), 'Missing profile usernames should be repaired and persisted instead of displaying the @founder fallback');
console.log('Profile/feed regression checks passed (scripts parsed; no live services called).');

assert.ok(profile.includes('id="accountStatus" role="status" aria-live="polite" aria-atomic="true"'), 'Profile save feedback should be announced accessibly');

assert.ok(feed.includes('id="postCharacterCount" role="status" aria-live="polite" aria-atomic="true"'), 'Post composer should announce remaining character count accessibly');
assert.ok(feed.includes("1200-$('postText').value.length") && feed.includes("character-limit-near"), 'Post composer character count should update live and flag the final 120 characters');


// Settings tabs must remain complete, keyboard accessible, and connected to their panels.
const settings = readFileSync(new URL('../settings.html', import.meta.url), 'utf8');
parseInlineScripts('settings', settings);
const settingTabs = [...settings.matchAll(/<button[^>]*data-section="([^"]+)"[^>]*>/g)].map(match => match[1]);
assert.deepEqual(settingTabs, ['privacy', 'features', 'notifications', 'appearance', 'account', 'security'], 'Settings navigation tabs/order must remain complete');
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


assert.ok(files.feed.includes('commentUserIds=[...new Set((cr.data||[]).map(x=>x.user_id))]'), 'Feed should fetch profiles for comment authors too');
assert.ok(files.feed.includes('data-retry-feed') && files.feed.includes("feedRetryRoot.addEventListener('click'"), 'Feed and opportunity query failures should expose a retry action');
for (const failure of ['Could not load reposted posts:', 'Could not load trending posts:']) {
  const at = files.feed.indexOf(failure);
  assert.ok(at >= 0, 'Feed must retain the ' + failure + ' error state.');
  const state = files.feed.slice(at - 50, at + 260);
  assert.match(state, /role="alert"/, failure + ' must be announced as an error.');
  assert.match(state, /data-retry-feed/, failure + ' must offer the existing retry action.');
}
const communityFeedError = files.feed.indexOf("Could not load posts: '+esc(r.error.message)");
assert.ok(communityFeedError >= 0, 'Community and public feed query failures must remain identifiable.');
assert.match(files.feed.slice(communityFeedError - 60, communityFeedError + 260), /role="alert"[\s\S]*data-retry-feed/,
  'Community and public feed failures must provide an accessible retry action.');
assert.match(files.feed, /const relationshipError=\(mode==='following'\?fr\.error:mode==='communities'\?mr\.error:\(fr\.error\|\|mr\.error\)\)/,
  'Personalized feed modes must detect failed relationship lookups instead of treating them as empty results.');
assert.match(files.feed, /Could not load '\+relationshipLabel\+': '\+esc\(relationshipError\.message\|\|'Please try again\.'\)/,
  'Relationship lookup failures must show an escaped, understandable error message.');
assert.match(files.feed, /relationshipError[\s\S]{0,400}data-retry-feed/,
  'Relationship lookup failures must provide the existing feed retry action.');
for (const id of ['feedSearchForm','feedSearchInput','feedSort','clearFeedSearch','feedSearchSummary']) {
  assert.ok(files.feed.includes('id="' + id + '"'), 'Feed discovery controls must include #' + id);
}
assert.match(files.feed, /window\.venturifyFeedSearch/, 'Feed search must preserve its query while changing feed views');
assert.ok(files.feed.includes('id="savedPostTypeFilter"'), 'Saved posts must expose a dedicated post-type filter');
assert.match(files.feed, /mode==='saved'&&savedPostTypeFilter&&savedPostTypeFilter\.value!=='all'/, 'Saved post-type filtering must apply only in the Saved view');
assert.match(files.feed, /savedPostTypeFilter.*addEventListener\('change'/, 'Saved post-type changes must reload the filtered list');
assert.ok(files.feed.includes('id="savedCommunityFilter"'), 'Saved posts must expose a dedicated community filter');
assert.ok(files.feed.includes('id="savedLibraryHeader"'), 'Saved view must have a dedicated library heading');
assert.ok(files.feed.includes('id="savedLibraryCount"'), 'Saved library must show the member’s bookmark count');
assert.ok(files.feed.includes('id="resetSavedFilters"'), 'Saved library must provide a one-click filter reset');
assert.match(files.feed, /resetSavedFilters\.hidden=mode!=='saved'/, 'Saved filter reset must only appear in the Saved view');
assert.match(files.feed, /resetSavedFilters'\)\.addEventListener\('click',[\s\S]{0,500}savedCommunityFilter'\)\.value='all'/, 'Saved filter reset must clear search, sorting, type, and community filters');
assert.match(files.feed, /savedLibraryHeader\.hidden=mode!=='saved'/, 'Saved library heading must appear only in Saved view');
assert.match(files.feed, /savedLibraryCount\.textContent=savedIds\.length/, 'Saved library count must reflect the signed-in member’s bookmarks');
assert.match(files.feed, /\.in\('id',savedIds\)\.order\('created_at',\{ascending:false\}\);/, 'Saved library must not silently truncate the member’s saved discussions to an arbitrary 100-post limit');
assert.match(files.feed, /savedCommunityFilter\.innerHTML[\s\S]{0,600}All saved communities/, 'Saved community options must be populated from communities represented in bookmarks');
assert.match(files.feed, /selectedCommunity==='__none__'\?\!p\.community_id:p\.community_id===selectedCommunity/, 'Saved community filtering must include a not-in-a-community option');
assert.match(files.feed, /savedCommunityFilter.*addEventListener\('change'/, 'Saved community changes must reload the filtered list');
assert.match(files.feed, /p\.opportunity_offer,p\.opportunity_need/, 'Feed search must include collaboration offers and needs');
assert.match(files.feed, /sortMode==='oldest'/, 'Feed sorting must support oldest-first ordering');
assert.match(files.feed, /clearFeedSearch.*addEventListener/s, 'Feed search must provide a working clear action');
assert.match(files.feed, /Search covers the latest posts loaded for the selected feed/, 'Feed search scope must be explained to members');
assert.match(files.feed, /window\.venturifyFeedVisibleLimit=40/, 'Feed should start with a manageable first page');
assert.match(files.feed, /data-feed-load-more/, 'Feed should offer progressive browsing beyond the first page');
assert.match(files.feed, /const sharedPostId=window\.location\.hash\.startsWith\('#post-'\)/, 'Shared post URLs must resolve their target even when it is outside the normal feed candidate set');
assert.match(files.feed, /if\(sharedPostId\)\{const sharedIndex=posts\.findIndex\(p=>p\.id===sharedPostId\)/, 'A directly linked post must be moved into the visible first position before feed pagination');
assert.match(files.feed, /Show more posts/, 'Feed pagination should have a clear member-facing action');
assert.ok((files.feed.match(/\.range\(0,feedFetchWindow\(\)\)/g)||[]).length >= 6, 'Feed views should fetch a growing ordered candidate window before client-side ranking and filtering');
assert.match(files.feed, /Search covers the latest posts loaded for the selected feed/, 'Feed search scope must remain explicit when candidates are bounded');
assert.match(files.feed, /if\(mode==='for-you'&&[\s\S]{0,1800}relationship=followedIds\.has\(p\.user_id\)\?9:0/, 'For-you feed should rank with member relationships');
assert.match(files.feed, /engagement=\(likeCounts\.get\(p\.id\)\|\|0\)\*1\.5/, 'For-you feed should incorporate real engagement signals');
assert.ok(files.feed.includes("if(mode==='for-you'&&($('feedSort')?.value||'newest')!=='oldest'&&sortMode!=='discussed')"), 'Explicit oldest-first and most-discussed sorting should take precedence over personalized ranking');
assert.match(files.feed, /community=p\.community_id/, 'For-you ranking should account for joined communities');
assert.match(files.feed, /if\(mode==='trending'&&sortMode!=='discussed'\)[\s\S]{0,1000}posts\.sort/, 'Trending should rank posts by engagement unless the member explicitly chooses most-discussed sorting');


assert.ok(files.feed.includes('Retry feed</button>') && files.feed.includes('Retry feed</button></p></div>'), 'Retry controls should be present in feed query error states');


assert.ok(files.settings.includes('id="discardSettings" disabled') && files.settings.includes("discard.addEventListener('click',()=>{if(!dirty)return;apply(savedValues)"), 'Settings should allow restoring the last saved values without writing to the database');
assert.ok(files.settings.includes('savedValues=captureSettings()') && files.settings.includes('discard.disabled=true'), 'Successful saves should become the new reset baseline and disable discard');


const tabNames = [...profile.matchAll(/data-profile-tab="([^"]+)"/g)].map(match => match[1]);
assert.deepEqual(tabNames, ['posts', 'replies', 'stories', 'about'], 'Profile tabs must retain their four supported views in order');
assert.match(profile, /id="profileStories"[^>]*\bhidden\b/, 'Stories must start hidden until the Stories tab is selected');
assert.match(profile, /const allowed=new Set\(\['posts','replies','stories','about'\]\)/, 'Profile tab handler must reject unknown view names');
assert.match(profile, /setTab\('posts'\)/, 'Profile tabs must initialize to the Posts panel on first load');
assert.match(profile, /profile-about-chip-section/, 'Founder skills and interests should render as distinct profile sections');
assert.match(profile, /profile-about-chip/, 'Founder skills and interests should render as readable chips');
assert.match(profile, /addChips\('Skills',p\.skills\)/, 'Founder skills should be surfaced as chips in About');
assert.match(profile, /addChips\('Interests',p\.interests\)/, 'Founder interests should be surfaced as chips in About');
assert.match(profile, /const linkedin=safeUrl\(p\.linkedin_url\)/, 'LinkedIn profile links must pass through the safe URL validator');
assert.match(profile, /link\.rel='noopener noreferrer'/, 'External LinkedIn links must use safe new-tab relationship attributes');

for (const [name, panel] of [['about','profileAbout'],['stories','profileStories']]) {
  assert.ok(profile.includes("if(" + panel + ")") || profile.includes("const " + (name === 'about' ? 'about' : 'stories') + "=document.getElementById('" + panel + "')"), 'Profile tab handler must manage #' + panel);
}
