import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

for (const path of ['index.html', 'discover.html', 'profile.html', 'messages.html']) {
  const html = readFileSync(new URL('../' + path, import.meta.url), 'utf8');
  assert.ok(
    html.includes("p.username||('user_'+String(p.id||'').replace(/-/g,'').slice(0,8).toLowerCase())") ||
    html.includes("p?.username||('user_'+String(p?.id||'').replace(/-/g,'').slice(0,8).toLowerCase())"),
    path + ' must derive a stable visible handle from the profile ID when username is missing.'
  );
  assert.ok(
    !html.includes("p.username||'founder'") && !html.includes("p?.username||'founder'"),
    path + ' must not display the generic @founder placeholder for a profile with a missing username.'
  );
}
console.log('Missing-username display fallback contracts passed.');
