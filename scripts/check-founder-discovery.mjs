import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const profileHtml = readFileSync(new URL('../profile.html', import.meta.url), 'utf8');

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
assert.match(html, /reasons\.push\('Shared interests: '\+sharedInterests\.slice\(0,2\)\.join\(', '\)\)/,
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
assert.match(html, /Matches your activity:/,
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
assert.match(html, /reasons\.push\('Fits feedback you liked:/,
  'Match explanations should identify when feedback preferences influenced a recommendation');
assert.match(html, /learnedTopicWeights\.get\(word\)\|\|0/,
  'Both daily ranking and displayed scores should use learned topic preferences');


assert.match(html, /Shared interests: '\+sharedInterests\.slice\(0,2\)\.join\(', '\)/,
  'Why this founder should name the exact shared interests');
assert.match(html, /Shared skills: '\+shared\.slice\(0,2\)\.join\(', '\)/,
  'Why this founder should name exact overlapping skills');
assert.match(html, /Skills you need: '\+needSkills\.slice\(0,2\)\.join\(', '\)/,
  'Why this founder should name candidate skills that match the viewer’s needs');
assert.match(html, /They need: '\+helpSkills\.slice\(0,2\)\.join\(', '\)/,
  'Why this founder should identify skills the candidate is looking for');
assert.match(html, /Matches your activity: '\+activityMatches\.slice\(0,2\)\.join\(', '\)/,
  'Why this founder should name topics connected to user activity');
assert.match(html, /positiveLearned=\[\.\.\.candidateWords\]\.filter\(word=>\(learnedTopicWeights\.get\(word\)\|\|0\)>=4\)/,
  'Why this founder should identify topics learned from positive feedback');
assert.match(html, /return \{score,reasons:reasons\.slice\(0,3\)\}/,
  'Founder cards should show up to three specific explanation details');


assert.match(html, /id="founderCompareTray"/,
  'Discovery should include a founder comparison selection tray');
assert.match(html, /data-compare-founder=/,
  'Founder cards should allow selecting profiles for comparison');
assert.match(html, /selectedFounderIds\.size!==2/,
  'Comparison should require exactly two selected founders');
assert.match(html, /Skills|compareList\(p\.skills\)/,
  'Comparison should show founder skills');
assert.match(html, /compareList\(p\.interests\)/,
  'Comparison should show founder interests');
assert.match(html, /compareText\(p\.looking_for\)/,
  'Comparison should show each founder’s collaboration goals');
assert.match(html, /founderCompareBackdrop/,
  'Comparison should open in an accessible modal');
assert.match(html, /data-message-profile=/,
  'Comparison should provide a direct way to message each founder');
assert.match(html, /aHelp=\[\.\.\.askA\]\.filter\(x=>skillsB\.has\(x\)\),bHelp=\[\.\.\.askB\]\.filter\(x=>skillsA\.has\(x\)\)/,
  'Complementary skill comparison should check both directions');

// Founder shortlist regression checks (Discover page + Supabase-backed privacy).
const discoverHtml = readFileSync(new URL('../discover.html', import.meta.url), 'utf8');
assert.match(discoverHtml, /data-match-feedback="relevant"/,
  'Founder cards should let users mark a match relevant');
assert.match(discoverHtml, /data-match-feedback="not_relevant"/,
  'Founder cards should let users mark a match not relevant');
assert.match(discoverHtml, /founder_match_feedback.*upsert|upsert\(\{viewer_id:currentUser.id,candidate_id:id,feedback:value/,
  'Recommendation feedback should persist to Supabase');
assert.match(discoverHtml, /matchFeedback\.get\(p\.id\)!=='not_relevant'/,
  'Future daily recommendations should exclude founders marked not relevant');
assert.match(discoverHtml, /matchFeedback\.get\(p\.id\)==='relevant'\?15:0/,
  'Relevant feedback should boost future match ranking');
assert.match(discoverHtml, /Math\.max\(0,6-dailyMatchIds\.length\)/,
  'Personalized daily recommendations should remain capped at six');

assert.match(discoverHtml, /id="founderDashboardTitle"/,
  'Discover should include a founder match dashboard');
assert.match(discoverHtml, /id="founderMatchHistory"/,
  'Dashboard should show recent match history');
assert.match(discoverHtml, /id="founderFeedbackTrends"/,
  'Dashboard should show feedback trends');
assert.match(discoverHtml, /founder_match_impressions.*limit\(100\)/,
  'Dashboard should load recent impressions for the signed-in user');
assert.match(discoverHtml, /Recent recommendations tracked/,
  'Dashboard should summarize tracked recommendations');
assert.match(discoverHtml, /Last 7 days/,
  'Dashboard should compare recent feedback trends');
assert.match(discoverHtml, /id="matchDashboardRefresh"/,
  'Dashboard should allow refreshing its stats');
assert.match(discoverHtml, /founder-match-insights/,
  'Founder cards should show a dedicated match-insights panel');
assert.match(discoverHtml, /Shared interests:/,
  'Match insights should explain shared interests');
assert.match(discoverHtml, /c\.from\('communities'\)\.select\('id,name'\)/,
  'Discovery should load community names for shared-community explanations');
assert.match(discoverHtml, /Math\.min\(sharedCommunities\.length,2\)\*8/,
  'Displayed match scores should reward up to two shared communities');
assert.match(discoverHtml, /sharedCommunityCount=.*Math\.min\(sharedCommunityCount,2\)\*8/,
  'Daily recommendations should also reward shared communities');
assert.match(discoverHtml, /Communities you both joined:/,
  'Match insights should name the communities shared by both founders');
assert.match(discoverHtml, /Skills that fit your goals:/,
  'Match insights should explain complementary skills');
assert.match(discoverHtml, /Collaboration goals:/,
  'Match insights should explain collaboration goals');
assert.match(discoverHtml, /Founder Shortlist/,
  'Discover should show a dedicated founder shortlist');
assert.match(discoverHtml, /hasProfileInfo=p=>\[p\.headline,p\.bio,p\.company,p\.skills,p\.interests,p\.looking_for\]\.some\(v=>typeof v==='string'&&v\.trim\(\)\.length>0\)/,
  'Discovery should hide low-information profiles while allowing founders with meaningful profile details');
assert.match(discoverHtml, /communityCounts\.get\(p\.id\)\|\|0\)>=1&&founderLevel\(p\)>=5/,
  'Discovery must still require at least one community and Level 5+');

assert.match(discoverHtml, /data-shortlist-save=/,
  'Founder cards should provide a save/unsave shortlist control');
assert.match(discoverHtml, /from\('founder_shortlists'\)\.select\('founder_id,status,created_at'\)/,
  'Discover should load saved founders and their next-step status from Supabase');
assert.match(discoverHtml, /data-shortlist-status=/,
  'Shortlist entries should allow updating next-step status');
assert.match(discoverHtml, /data-shortlist-remove=/,
  'Shortlist entries should allow removing saved founders');
assert.match(discoverHtml, /id="founderShortlistSearch"/,
  'Shortlist should provide a search field');
assert.match(discoverHtml, /id="founderShortlistStatusFilter"/,
  'Shortlist should provide a status filter');
assert.match(discoverHtml, /return query\.every\(term=>hay\.includes\(term\)\)/,
  'Shortlist search should match all search terms');
assert.match(discoverHtml, /statusFilter!=='all'/,
  'Shortlist status filter should filter the saved list');
assert.match(discoverHtml, /data-message-profile=/,
  'Shortlist entries should offer direct messaging');
assert.match(discoverHtml, /Users view their own founder shortlist|founder_shortlists/,
  'Shortlist markup and data flow should be present');

console.log('Passed: ' + scripts.length + ' inline scripts parse; founder-discovery and shortlist regression checks passed.');

assert.match(profileHtml, /\.reputation-breakdown\s*\{/,
  'Profile reputation breakdown should have a valid CSS selector');
