import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const pages=['case-studies.html','communities.html','discover.html','feed.html','index.html','messages.html','notifications.html','principles.html','profile.html','share-story.html'];
for(const path of pages){
 const html=readFileSync(new URL('../'+path,import.meta.url),'utf8');
 const account=(html.match(/<a\b[^>]*id="navAccount"[^>]*>/g)||[]);
 assert.equal(account.length,1,path+' must have exactly one login/account auth control.');
 assert.match(account[0],/data-guest-only/,path+' login/account control must be guest-only so signed-in users do not see a duplicate Account link.');
 const gears=(html.match(/<a\b[^>]*class="nav-icon-link settings-gear-link"[^>]*>/g)||[]);
 assert.equal(gears.length,1,path+' must have exactly one Settings gear link.');
 assert.match(gears[0],/data-auth-only/,path+' Settings gear must only appear to signed-in users.');
 assert.match(html,/body\.authenticated[^\n]*data-guest-only[^\n]*display:none!important|body\.authenticated[\s\S]{0,500}\[data-guest-only\]/,path+' must hide guest-only navigation for authenticated users.');
}
console.log('Global Settings and Account navigation checks passed.');
