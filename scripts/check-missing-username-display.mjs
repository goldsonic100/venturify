import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

for (const path of ['index.html', 'discover.html', 'profile.html', 'messages.html']) {
  const html = readFileSync(new URL('../' + path, import.meta.url), 'utf8');
  assert.match(
    html,
    /user_'\+String\(p\??\.id\|\|'?'?'\)\.replace\(/,
    path + ' must derive a stable visible handle from the profile ID when username is missing.'
  );
  assert.doesNotMatch(
    html,
    /p\??\.username\|\|'founder'/,
    path + ' must not display the generic @founder placeholder for a profile with a missing username.'
  );
}
console.log('Missing-username display fallback contracts passed.');
