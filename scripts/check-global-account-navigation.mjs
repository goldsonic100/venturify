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
  assert.ok(nav.includes('href="discover.html#founderDiscovery"') || nav.includes('href="#founderDiscovery"'),
    path + ' must include the People directory destination.');

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
  assert.ok(nav.includes('aria-label="Announcements and notifications"'),
    path + ' must expose the Announcements and notifications control.');
}

const activeNavigation = readFileSync(new URL('../assets/active-navigation.js', import.meta.url), 'utf8');
assert.match(activeNavigation,/aria-current/,'The current navigation destination must be announced accessibly.');
assert.match(activeNavigation,/founderDiscovery/,'The People directory deep link must receive its own active state.');
assert.match(activeNavigation,/workspace\.html/,'Workspace should highlight the Collaborations destination.');
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

const navigationPolish = readFileSync(new URL('../venturify-ui.css', import.meta.url), 'utf8');
assert.match(navigationPolish, /\.topbar \.nav>a\[data-auth-only\]\[hidden\]\{display:inline-flex!important/,
  'Auth-gated destination links must stay visible even when page scripts mark them hidden for guests.');
assert.match(navigationPolish, /\.topbar \.nav>\.notification-wrap\[data-auth-only\]\[hidden\]\{display:flex!important/,
  'The Announcements control must stay visible for guests as well as signed-in users.');


const publicHandlePages = ['index.html','feed.html','discover.html','profile.html','communities.html','messages.html','notifications.html'];
for (const path of publicHandlePages) {
  const html = readFileSync(new URL('../' + path, import.meta.url), 'utf8');
  assert.ok(!html.includes("username||'founder'") && !html.includes("username||'founder'"),
    path + ' must not display the generic @founder handle when a profile has a stable user ID.');
  assert.ok(html.includes("replace(/-/g,'').slice(0,8).toLowerCase()"),
    path + ' must derive a deterministic public fallback handle from the profile ID.');
}

console.log('Consistent global navigation and public handle checks passed for ' + pages.length + ' pages.');
