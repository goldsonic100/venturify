import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const directory=readFileSync(new URL('../communities.html',import.meta.url),'utf8');
const page=readFileSync(new URL('../community.html',import.meta.url),'utf8');
assert.match(directory,/href="community\.html\?id=/,'Community cards must navigate to a dedicated community page.');
for(const id of ['communityName','communityTopic','communityDescription','memberCount','joinButton','postCount','postForm','postContent','postFeed','timeFilter'])assert.ok(page.includes('id="'+id+'"'),'Dedicated community page is missing #'+id);
for(const mode of ['recommended','new','top','discussed'])assert.ok(page.includes('data-sort="'+mode+'"'),'Community feed is missing '+mode+' sorting.');
assert.match(page,/from\('communities'\)/,'Community details must load from the communities table.');
assert.match(page,/from\('community_members'\)/,'Membership must use the community_members table.');
assert.match(page,/from\('posts'\)/,'Community discussions must load from posts.');
assert.match(page,/from\('likes'\)/,'Community voting must use the existing likes table.');
assert.match(page,/from\('comments'\)/,'Community replies must use the existing comments table.');

for(const id of ['memberList','memberToggle','memberPreview'])assert.ok(page.includes('id="'+id+'"'),'Community member directory is missing #'+id);
assert.match(page,/from\('community_members'\)\.select\('user_id'\)/,'Member directory must derive membership from the community_members table.');
assert.match(page,/from\('profiles'\)\.select\('id,username,display_name,avatar_url'\)/,'Member directory must load only public profile display fields.');
assert.match(page,/function renderMembers\(\)/,'Community member directory must render a member list.');
assert.match(page,/profile\.html\?id=/,'Community members must link to their profiles.');
assert.match(page,/View all /,'Member directory must provide an expand/collapse control for larger communities.');

assert.match(page,/Join this community before posting/,'Posting must require community membership.');
assert.match(page,/maxlength="5000"/,'Community posts must retain the 5,000-character limit.');
assert.match(page,/maxlength="500"/,'Community comments must retain the 500-character limit.');

for(const href of ['principles.html','feed.html','discover.html','communities.html','collaborations.html','profile.html','messages.html','notifications.html','settings.html'])assert.ok(page.includes('href="'+href+'"'),'Community navigation is missing '+href);
assert.match(page,/data-auth-only/,'Authenticated navigation destinations must be marked for signed-in users.');
assert.match(page,/data-guest-only/,'Guest login and signup destinations must remain available.');
assert.match(page,/overflow-x:auto/,'Mobile community navigation must remain horizontally accessible instead of hiding destinations.');
assert.match(page,/function syncNavigation\(\)/,'Community navigation must respond to authentication state.');

const scripts=[...page.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1].trim()).filter(Boolean);
assert.ok(scripts.length,'Community page must have an application script.');
scripts.forEach((source,index)=>{try{new Function(source)}catch(error){throw new Error('community.html inline script '+(index+1)+' failed to parse: '+error.message)}});

assert.match(directory,/personal_score:\(topicInterest\.get\(c\.topic\)\|\|0\)\+\(directInterest\.get\(c\.id\)\|\|0\)/,'Community recommendations must be grounded in the viewer’s existing community activity.');
assert.match(directory,/community-recommendation-reason/,'Personalized community cards must explain why they were recommended.');
assert.match(directory,/Recommended because you have activity in /,'Recommendation explanations must identify the topic behind the match.');
assert.match(directory,/featured\.map\(c=>renderCommunityTile\(c,true,\(c\.personal_score\|\|0\)>0\?'Picked for you':'Popular community'\)\)/,'Popular fallback cards must not be mislabeled as personalized recommendations.');


assert.match(directory,/from\('follows'\)\.select\('following_id'\)\.eq\('follower_id',user\.id\)/,'Community recommendations must use only the signed-in user’s followed founders.');
assert.match(directory,/from\('post_bookmarks'\)\.select\('post_id'\)\.eq\('user_id',user\.id\)/,'Community recommendations must read only the signed-in user’s saved posts.');
assert.match(directory,/followedPostResult\.data/,'Followed-founder posts must contribute topic signals.');
assert.match(directory,/savedResourceResult\.data/,'Saved resource posts must contribute topic signals.');
assert.match(directory,/Topics shared by founders you follow/,'Recommendations must explain followed-founder topic matches.');
assert.match(directory,/Related to resources you saved/,'Recommendations must explain saved-resource topic matches.');
assert.match(directory,/savedResourceResult\.data\|\|\[\]\)\.forEach\(p=>\{if\(p\.community_id/,'Saved resource community activity must be mapped to existing communities.');

console.log('Dedicated community page regression checks passed (static checks only).');

const sortGroup = page.match(/<div class="sorts"[^>]*>/);
assert.ok(sortGroup && sortGroup[0].includes('aria-controls="postFeed"'), 'Community sort controls must be associated with the discussion feed');
for (const mode of ['recommended', 'new', 'top', 'discussed']) {
  const button = page.match(new RegExp('<button[^>]*data-sort="' + mode + '"[^>]*>'));
  assert.ok(button && button[0].includes('aria-pressed='), 'Community sort "' + mode + '" must expose its selected state');
}
assert.match(page, /x\.setAttribute\('aria-pressed',String\(active\)\)/, 'Community sort changes must update the accessible selected state');
