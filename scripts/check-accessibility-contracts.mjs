import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const pages = [
  'index.html','feed.html','discover.html','communities.html','messages.html',
  'notifications.html','profile.html','settings.html','moderator.html',
  'case-studies.html','collaborations.html','principles.html','share-story.html','workspace.html'
];
for (const path of pages) {
  const html = read(path);
  assert.ok(html.includes('id="venturify-global-theme"'), path + ' must load the shared theme controller');
  assert.ok(html.includes('href="venturify-a11y.css"'), path + ' must load shared accessibility styles');
  assert.ok(html.includes('class="skip-link"'), path + ' must provide a keyboard skip link');
  assert.ok(html.includes('id="main-content"'), path + ' must provide the skip-link target');
  assert.ok(html.includes('width=device-width'), path + ' must provide mobile viewport metadata');
}
const css = read('venturify-a11y.css');
for (const contract of ['.skip-link:focus-visible', ':focus-visible', 'prefers-reduced-motion:reduce', 'prefers-contrast:more', 'forced-colors:active']) {
  assert.ok(css.includes(contract), 'Shared accessibility stylesheet is missing: ' + contract);
}
console.log('Phase 1 accessibility/theme contracts passed for ' + pages.length + ' pages.');
