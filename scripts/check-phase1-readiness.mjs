import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const pages = [
  'index.html',
  'feed.html',
  'discover.html',
  'communities.html',
  'messages.html',
  'notifications.html',
  'profile.html',
  'settings.html',
  'moderator.html'
];

const sources = new Map(pages.map(path => {
  try {
    return [path, readFileSync(new URL('../' + path, import.meta.url), 'utf8')];
  } catch (error) {
    throw new Error('Required Phase 1 page is missing: ' + path + ' (' + error.message + ')');
  }
}));

// Every core page should remain mobile-aware and avoid leaking server secrets.
for (const [path, html] of sources) {
  assert.ok(/<meta\s+name=["']viewport["']\s+content=["'][^"']*width=device-width/i.test(html),
    path + ' must declare a responsive viewport');
  assert.ok(!/service_role|sb_secret_[a-z0-9_]+/i.test(html),
    path + ' must not contain Supabase server credentials');
}

// Inline JavaScript is syntax-checked only. This deliberately does not execute
// browser code, authenticate, or make requests to the live Supabase project.
for (const [path, html] of sources) {
  const scripts = [...html.matchAll(/<script\b(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)];
  for (const [index, match] of scripts.entries()) {
    try {
      new Function(match[1]);
    } catch (error) {
      throw new Error(path + ' inline script ' + (index + 1) + ' has a syntax error: ' + error.message);
    }
  }
}

// Core app navigation must identify the current view accessibly.
const home = sources.get('index.html');
assert.ok(home.includes('data-app-view'), 'Home should use the shared app navigation');
for (const view of ['feed', 'discover', 'communities', 'messages', 'notifications', 'profile']) {
  assert.ok(home.includes('"' + view + '"'), 'Home navigation should know the ' + view + ' view');
}

// Keep high-risk surfaces discoverable and protected by their existing controls.
assert.ok(sources.get('messages.html').includes('aria-live'),
  'Messaging should expose live updates to assistive technology');
assert.ok(sources.get('settings.html').includes('aria-live'),
  'Settings should announce save/error status accessibly');
assert.ok(sources.get('communities.html').includes('aria-live'),
  'Community actions should provide accessible status announcements');
assert.ok(sources.get('moderator.html').includes('moderator'),
  'The moderator page should retain moderator-specific access workflow');

console.log('Phase 1 release-readiness checks passed for ' + sources.size + ' core pages.');
