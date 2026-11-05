import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const pages = [
  'case-studies.html',
  'communities.html',
  'community.html',
  'collaborations.html',
  'discover.html',
  'feed.html',
  'index.html',
  'messages.html',
  'notifications.html',
  'principles.html',
  'profile.html',
  'resources.html',
  'settings.html',
  'share-story.html',
  'workspace.html',
];

const requiredLinks = [
  ['principles.html', 'Our Principles'],
  ['feed.html', 'Feed'],
  ['discover.html', 'Discover'],
  ['discover.html#founderDiscovery', 'Founders'],
  ['communities.html', 'Communities'],
  ['collaborations.html', 'Collaborations'],
  ['profile.html', 'Profile'],
  ['messages.html', '💬'],
  ['settings.html', '⚙'],
];

for (const path of pages) {
  const html = readFileSync(new URL('../' + path, import.meta.url), 'utf8');
  const navMatches = [...html.matchAll(/<nav\\b[^>]*class=["'][^"']*\\bnav\\b[^"']*["'][^>]*>([\\s\\S]*?)<\\/nav>/gi)];
  assert.equal(navMatches.length, 1, path + ' must contain exactly one primary navigation.');

  const nav = navMatches[0][1];
  for (const [href, label] of requiredLinks) {
    const escaped = href.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\$&');
    const link = new RegExp('<a\\b(?=[^>]*href=["\\']' + escaped + '["\\'])[^>]*>([\\s\\S]*?)<\\/a>', 'i');
    assert.match(nav, link, path + ' must include the ' + label + ' destination.');
  }

  const navItems = [...nav.matchAll(/<a\\b[^>]*class=["'][^"']*\\bnav-item\\b[^"']*["'][^>]*>/gi)];
  assert.ok(navItems.length >= 9, path + ' must expose the complete, consistently styled navigation.');
  for (const [index, match] of navItems.entries()) {
    assert.match(match[0], /data-nav-key=/, path + ' navigation item ' + (index + 1) + ' must have a stable navigation key.');
  }

  const account = [...html.matchAll(/<a\\b[^>]*id=["']navAccount["'][^>]*>/gi)];
  assert.equal(account.length, 1, path + ' must have exactly one login/account control.');
  assert.match(account[0][0], /data-guest-only/, path + ' login control must be guest-only.');

  const gears = [...html.matchAll(/<a\\b[^>]*class=["'][^"']*\\bsettings-gear-link\\b[^"']*["'][^>]*>/gi)];
  assert.equal(gears.length, 1, path + ' must have exactly one Settings gear link.');
  assert.match(gears[0][0], /data-auth-only/, path + ' Settings gear must only appear to signed-in users.');

  assert.match(html, /body\\.authenticated[^\\n]*data-guest-only[^\\n]*display:none!important|body\\.authenticated[\\s\\S]{0,500}\\[data-guest-only\\]/,
    path + ' must hide guest-only navigation for authenticated users.');
}

const css = readFileSync(new URL('../assets/venturify-design-system.css', import.meta.url), 'utf8');
assert.match(css, /\\.nav\\.venturify-primary-nav[\\s\\S]*?min-height:40px/,
  'Primary navigation items must share a consistent minimum height.');
assert.match(css, /overflow-x:auto/,
  'Mobile navigation must allow access to every tab through horizontal scrolling.');
assert.match(css, /aria-current="page"[\\s\\S]*?background:linear-gradient/,
  'The active navigation destination must have a distinct visible state.');
assert.match(css, /prefers-reduced-motion:reduce/,
  'Navigation must respect reduced-motion preferences.');

console.log('Consistent global navigation checks passed for ' + pages.length + ' pages.');
