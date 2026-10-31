import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const utility=readFileSync(new URL('../directory-sort.js',import.meta.url),'utf8');
const communities=readFileSync(new URL('../communities.html',import.meta.url),'utf8');
const discover=readFileSync(new URL('../discover.html',import.meta.url),'utf8');
assert.match(utility,/VenturifyDirectorySort/,'Shared directory sorting utility must be exposed.');
assert.match(utility,/localStorage/,'Sort preferences must persist between visits.');
assert.match(communities,/id="communitySort"[^>]*>[\s\S]*?value="relevant"/,'Communities must default to relevance.');
for(const value of ['members','active','trending','discussed','newest','oldest','az','za'])assert.ok(communities.includes('value="'+value+'"'),'Community sort missing '+value);
assert.match(communities,/VenturifyDirectorySort\.sort\(matches,sort,sortRules\)/,'Community list must use shared sorter.');
assert.match(discover,/id="founderSort"[^>]*>[\s\S]*?value="relevant"/,'Founder discovery must default to relevance.');
for(const value of ['level_desc','level_asc','followers','communities','newest','oldest','az','za'])assert.ok(discover.includes('value="'+value+'"'),'Founder sort missing '+value);
assert.match(discover,/VenturifyDirectorySort\.sort\(list,founderSort,founderSortRules\)/,'Founder list must use shared sorter.');
assert.match(discover,/communityCounts\.get\(p\.id\)\|\|0\)>=1&&founderLevel\(p\)>=5/,'Sorting must preserve Level 5 and community membership eligibility.');
for(const [name,source] of [['communities.html',communities],['discover.html',discover]]){const scripts=[...source.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1].trim()).filter(Boolean);scripts.forEach((script,index)=>{try{new Function(script)}catch(error){throw new Error(name+' inline script '+(index+1)+' failed to parse: '+error.message)}})}
new Function(utility);
console.log('Directory sorting regression checks passed.');
