import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const pages = [
  'case-studies.html', 'communities.html', 'community.html',
  'collaborations.html', 'discover.html', 'feed.html', 'index.html',
  'messages.html', 'notifications.html', 'principles.html', 'profile.html',
  'resources.html', 'settings.html', 'share-story.html', 'workspace.html',
];

const requiredDestinations = [
  ['principles.html', 'Our Principles'],
  ['feed.html', 'Feed'],
  ['discover.html', 'Discover'],
  ['communities.html', 'Communities'],
  ['collaborations.html', 'Collaborations'],
  ['profile.html', 'Profile'],
  ['messages.html', 'Messages'],
  ['settings.html', 'Settings'],
];

function openingTagContaining(source, marker) {
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) return '';
  const start = source.lastIndexOf('<a ', markerIndex);
  const end = source.indexOf('>', markerIndex);
  return start >= 0 && end >= 0 ? source.slice(start, end + 1) : '';
}

for (const path of pages) {
  const html = readFileSync(new URL('../' + path, import.meta.url), 'utf8');
  const navStart = html.indexOf('<nav class="nav venturify-primary-nav"');
  const navEnd = html.indexOf('</nav>', navStart);
  assert.ok(navStart >= 0 && navEnd > navStart, path + ' must contain the shared primary navigation.');
  const nav = html.slice(navStart, navEnd + 6);

  for (const [href, label] of requiredDestinations) {
    assert.ok(nav.includes('href="' + href + '"'), path + ' must include the ' + label + ' destination.');
  }
  assert.ok(nav.includes('href="discover.html#founderDiscovery"'),
    path + ' must include the Founders directory destination.');
  const founderLink = openingTagContaining(nav, 'data-app-view="people"');
  assert.ok(founderLink.includes('class="nav-item"'), path + ' Founders must use the shared tab class.');
  assert.ok(founderLink.includes('data-nav-key="founders"'), path + ' Founders must expose a stable navigation key.');
  assert.ok(nav.includes('>Founders</a>'), path + ' must use the same Founders label on every page.');

  const navItemClasses = nav.match(/class="[^"]*nav-item[^"]*"/g) || [];
  assert.ok(navItemClasses.length >= 8, path + ' must expose the full set of consistently styled text tabs.');
  for (const key of ['principles', 'feed', 'discover', 'communities', 'collaborations', 'profile']) {
    assert.ok(nav.includes('data-nav-key="' + key + '"'), path + ' must expose a stable key for ' + key + '.');
  }

  const accountTag = openingTagContaining(html, 'id="navAccount"');
  assert.ok(accountTag, path + ' must have exactly one login/account control.');
  assert.ok(accountTag.includes('data-guest-only'), path + ' login control must be guest-only.');
  assert.equal((html.match(/id="navAccount"/g) || []).length, 1, path + ' must not duplicate the login/account control.');

  const gearTag = openingTagContaining(nav, 'settings-gear-link');
  assert.ok(gearTag, path + ' must have exactly one Settings gear link.');
  assert.ok(gearTag.includes('class="nav-icon-link settings-gear-link"'), path + ' Settings must use the shared icon-link class.');
  assert.ok(gearTag.includes('data-auth-only'), path + ' Settings gear must only appear to signed-in users.');
  assert.equal((nav.match(/settings-gear-link/g) || []).length, 1, path + ' must not duplicate the Settings gear.');

  assert.ok(nav.includes('data-auth-only') && nav.includes('data-guest-only'),
    path + ' must mark authenticated and guest navigation controls explicitly.');
  const signupTag = openingTagContaining(nav, 'id="navSignup"');
  assert.ok(signupTag && signupTag.includes('data-guest-only'), path + ' Sign up must be guest-only.');
  assert.equal((html.match(/id="navSignup"/g) || []).length, 1, path + ' must not duplicate Sign up.');
  assert.ok(html.includes('assets/global-navigation.css'), path + ' must load the global navigation override.');
  assert.ok(html.includes('assets/global-auth-navigation.js'), path + ' must load the session-aware auth navigation.');
  assert.ok(html.includes('@supabase/supabase-js'), path + ' must load Supabase before the shared auth navigation.');

  assert.ok(nav.includes('aria-label="Announcements and notifications"'),
    path + ' must expose the Announcements and notifications control.');
}

const activeNavigation = readFileSync(new URL('../assets/active-navigation.js', import.meta.url), 'utf8');
assert.match(activeNavigation,/aria-current/,'The current navigation destination must be announced accessibly.');
assert.match(activeNavigation,/founderDiscovery/,'The People directory deep link must receive its own active state.');
assert.match(activeNavigation,/workspace\.html/,'Workspace should highlight the Collaborations destination.');
assert.match(activeNavigation, /addEventListener\('hashchange', updateActiveNavigation\)/,
  'The active navigation state must update when an in-page view changes its URL hash.');
assert.match(activeNavigation, /addEventListener\('popstate', updateActiveNavigation\)/,
  'The active navigation state must stay correct when users navigate browser history.');
for (const path of pages) {
  const html = readFileSync(new URL('../' + path, import.meta.url), 'utf8');
  assert.match(html,/assets\/active-navigation\.js/,'The shared active navigation script must load on ' + path + '.');
}
const css = readFileSync(new URL('../assets/venturify-design-system.css', import.meta.url), 'utf8');
assert.ok(css.includes('.nav.venturify-primary-nav'), 'Shared navigation styles must exist.');
assert.ok(css.includes('min-height:40px'), 'All navigation tabs must share a consistent minimum height.');
assert.ok(css.includes('overflow-x:auto'), 'Mobile navigation must allow access to every tab through horizontal scrolling.');
assert.ok(css.includes('aria-current="page"'), 'The active navigation destination must have a distinct visible state.');
assert.ok(css.includes('prefers-reduced-motion:reduce'), 'Navigation must respect reduced-motion preferences.');
const globalNavigation = readFileSync(new URL('../assets/global-navigation.css', import.meta.url), 'utf8');
const globalAuthNavigation = readFileSync(new URL('../assets/global-auth-navigation.js', import.meta.url), 'utf8');
assert.match(globalAuthNavigation, /auth\.getSession\(\)/, 'The shared navigation must read the persisted Supabase session.');
assert.match(globalAuthNavigation, /auth\.onAuthStateChange/, 'The shared navigation must react to authentication changes.');
assert.match(globalAuthNavigation, /authenticated \? 'Account' : 'Log in'/, 'The account control must show Account only for signed-in members.');
assert.match(globalAuthNavigation, /signup\.hidden = authenticated/, 'The Sign up control must be hidden for signed-in members.');

assert.match(globalNavigation, /flex-flow:row nowrap!important/, 'The shared navigation must stay on one row on desktop.');
assert.match(globalNavigation, /flex:0 0 104px!important;width:104px!important/, 'Every desktop text tab must have the same fixed width.');
assert.match(globalNavigation, /border-radius:20px!important/, 'Every primary tab must use the same pill shape.');
assert.match(globalNavigation, /background:#536174!important;color:#f2f6fc!important/, 'Inactive tabs must share the same slate treatment.');
assert.match(globalNavigation, /background:#e5efff!important;border-color:#9dbdf2!important;color:#315d9d!important/, 'The active tab must use the same selected treatment.');
assert.match(globalNavigation, /body\.authenticated[\s\S]*#navSignup\\[hidden\\]\{display:none!important/, 'Sign up must disappear while signed in.');
assert.match(globalNavigation, /body\.authenticated[\s\S]*#navAccount\{display:inline-flex!important/, 'The signed-in account destination must remain available.');


const navigationPolish = readFileSync(new URL('../venturify-ui.css', import.meta.url), 'utf8');
assert.match(navigationPolish, /\.topbar \.nav>a\[data-auth-only\]\[hidden\]\{display:inline-flex!important/,
  'Auth-gated destination links must stay visible even when page scripts mark them hidden for guests.');
assert.match(navigationPolish, /\.topbar \.nav>\.notification-wrap\[data-auth-only\]\[hidden\]\{display:flex!important/,
  'The Announcements control must stay visible for guests as well as signed-in users.');
assert.ok(navigationPolish.includes('.topbar .nav>a.nav-item[data-nav-key]{flex:0 0 104px!important;width:104px!important;min-width:104px!important;'),
  'Primary destination tabs must use the same desktop width.');
assert.ok(navigationPolish.includes('@media(max-width:760px){.topbar .nav>a.nav-item[data-nav-key]{flex:0 0 96px!important;width:96px!important;min-width:96px!important;'),
  'Primary destination tabs must keep a consistent touch target on mobile.');


const publicHandlePages = ['index.html','feed.html','discover.html','profile.html','communities.html','messages.html','notifications.html'];
for (const path of publicHandlePages) {
  const html = readFileSync(new URL('../' + path, import.meta.url), 'utf8');
  assert.ok(!html.includes("username||'founder'") && !html.includes("username||'founder'"),
    path + ' must not display the generic @founder handle when a profile has a stable user ID.');
  assert.ok(html.includes("replace(/-/g,'').slice(0,8).toLowerCase()"),
    path + ' must derive a deterministic public fallback handle from the profile ID.');
}

console.log('Consistent global navigation and public handle checks passed for ' + pages.length + ' pages.');

assert.ok(css.includes('flex:0 0 104px!important'), 'Every primary text tab must use one shared fixed width.');
assert.ok(css.includes('height:38px!important') && css.includes('min-height:38px!important'), 'Every primary text tab must use one shared height.');
assert.ok(css.includes('border-radius:20px!important'), 'Every primary text tab must use the same pill shape.');
assert.ok(css.includes('background:#536174!important') && css.includes('color:#f2f6fc!important'), 'Inactive primary tabs must share the same slate palette and readable text contrast.');
assert.ok(css.includes('background:#e5efff!important') && css.includes('color:#315d9d!important'), 'The active tab must use one consistent pale-blue selected state.');
assert.ok(css.includes('max-width:104px!important'), 'Primary tab widths must not expand differently based on label length.');
assert.ok(css.includes('flex-wrap:nowrap!important') && css.includes('overflow-x:auto!important'), 'Narrow screens must preserve equal tabs and allow horizontal scrolling.');
