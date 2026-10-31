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
console.log('Dedicated community page regression checks passed (static checks only).');
