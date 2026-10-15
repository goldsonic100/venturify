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

assert.ok((html.match(/replace\(\/\^#\+/g) || []).length >= 2,
  'Daily ranking and displayed match scores should normalize hashtag-prefixed tokens consistently');
assert.match(html, /ownSkills=\(mine\?\.skills\|\|''\)\.split\([\s\S]*?replace\(\/\^#\+\/, ''\)/,
  'The viewer’s skills should use the same token normalization as candidate skills');
assert.match(html, /const interestList=p=>\[\.\.\.new Set\([\s\S]*?replace\(\/\^#\+\/, ''\)/,
  'Interest-only filtering should normalize and deduplicate interest tokens');

// Mobile-layout regression checks: these rules are easy to accidentally override
// when new responsive styles are added to the single-page app.
assert.match(html, /<meta name="viewport" content="width=device-width, initial-scale=1">/,
  'Mobile pages must use the device viewport');
assert.match(html, /html,body\{max-width:100%;overflow-x:hidden\}/,
  'The document must prevent accidental page-wide horizontal overflow');
assert.match(html, /@media\(max-width:640px\)\{[\s\S]*?\.topbar\.wrap\{[^}]*flex-wrap:wrap/,
  'The mobile header must be allowed to wrap');
assert.match(html, /\.topbar \.nav\{[^}]*overflow-x:auto/,
  'Mobile navigation must remain horizontally scrollable');
assert.match(html, /\.founder-results\{grid-template-columns:minmax\(0,1fr\)\}/,
  'Founder cards must stack on narrow screens');
assert.match(html, /\.community-layout,\.community-hub\{grid-template-columns:minmax\(0,1fr\)/,
  'Community panels must stack on narrow screens');
assert.match(html, /\.modal\{width:100%;max-height:92dvh/,
  'Mobile modals must fit within the visible viewport');
assert.match(html, /\.feed-tabs\{display:flex;flex-wrap:nowrap;overflow-x:auto/,
  'Feed tabs must scroll instead of forcing the page wider');

assert.match(html, /c\.from\('likes'\)\.select\('post_id'\)\.eq\('user_id',currentUser\.id\)/,
  'Personalized discovery should read the signed-in user’s liked posts when available');
assert.match(html, /followedProfiles=rows\.filter\(p=>following\.has\(p\.id\)\)/,
  'Personalized discovery should learn topics from founders the user follows');
assert.match(html, /wordsFrom\(p\.content\)/,
  'Personalized discovery should learn topics from liked post content');
assert.match(html, /Math\.min\(activityMatches,3\)\*6/,
  'Daily recommendation ranking should reward overlap with activity-derived topics');
assert.match(html, /activityBonus=Math\.min\(activityMatches\.length,3\)\*6/,
  'Displayed match scores should reflect activity-derived topics consistently');
assert.match(html, /Based on your activity/,
  'Match explanations should identify activity-based recommendations');

assert.match(html, /const topicStopWords=new Set/,
  'Activity-based matching should filter common stop words');
assert.match(html, /const topicTokens=v=>\[\.\.\.new Set\([\s\S]*?topicStopWords\.has\(x\)/,
  'Topic matching should normalize, deduplicate, and filter tokens consistently');
assert.match(html, /sharedTopics=words\.filter\(x=>candidateWords\.has\(x\)\)\.length/,
  'Topic matching should use whole-token matches rather than accidental substrings');
assert.match(html, /const wordsFrom=v=>topicTokens\(v\)/,
  'Activity topics should use the same stop-word-filtered tokenizer');


assert.match(html, /c\.from\('founder_match_feedback'\)\.select\('candidate_id,feedback'\)/,
  'Discovery should load the signed-in user’s saved match feedback');
assert.match(html, /data-match-feedback="relevant"/,
  'Founder cards should let users mark a match as relevant');
assert.match(html, /data-match-feedback="not_relevant"/,
  'Founder cards should let users mark a match as not relevant');
assert.match(html, /founder_match_feedback'\)\.upsert\(/,
  'Match feedback should be saved persistently in Supabase');
assert.match(html, /feedbackByCandidate\.get\(p\.id\)!=='not_relevant'/,
  'Future daily picks should exclude founders marked not relevant');
assert.match(html, /feedbackByCandidate\.get\(p\.id\)==='relevant'\?10:0/,
  'Positive feedback should boost a founder in future recommendation ranking');
assert.match(html, /Feedback saved — future recommendations will learn from this\./,
  'The UI should confirm when saved feedback is active');


assert.match(html, /learnedTopicWeights=new Map\(\)/,
  'Discovery should keep a learned topic-weight map for feedback-driven personalization');
assert.match(html, /const ratedProfiles=await c\.from\('profiles'\)\.select\('id,interests,skills,headline,company,bio,looking_for'\)\.in\('id',ratedIds\)/,
  'Discovery should read the topics on profiles that received feedback');
assert.match(html, /feedbackByCandidate\.get\(profile\.id\)==='relevant'\?4:-5/,
  'Relevant feedback should reinforce profile topics and not-relevant feedback should discourage them');
assert.match(html, /feedbackBonus=Math\.max\(-15,Math\.min\(15,feedbackSignal\)\)/,
  'Learned topic influence should be capped so feedback cannot dominate every other match signal');
assert.match(html, /reasons\.push\('Matches feedback you liked'\)/,
  'Match explanations should identify when feedback preferences influenced a recommendation');
assert.match(html, /learnedTopicWeights\.get\(word\)\|\|0/,
  'Both daily ranking and displayed scores should use learned topic preferences');

console.log('Passed: ' + scripts.length + ' inline scripts parse; founder-discovery regression checks passed.');
