import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const migrationPath = new URL('../supabase/migrations/20261029170000_create_profile_for_auth_user.sql', import.meta.url);
const sql = readFileSync(migrationPath, 'utf8');

assert.match(sql, /CREATE OR REPLACE FUNCTION public\.create_profile_for_auth_user\(\)/i);
assert.match(sql, /AFTER INSERT ON auth\.users/i);
assert.match(sql, /INSERT INTO public\.profiles\s*\(id, username, display_name\)/i);
assert.match(sql, /'user_'\s*\|\|\s*pg_catalog\.left/i);
assert.match(sql, /ON CONFLICT \(id\) DO NOTHING/i, 'Existing profile handles must not be overwritten.');
assert.match(sql, /SECURITY DEFINER/i);
assert.match(sql, /SET search_path = ''/i);
assert.match(sql, /REVOKE ALL ON FUNCTION public\.create_profile_for_auth_user\(\) FROM PUBLIC, anon, authenticated/i);

for (const path of ['index.html', 'discover.html', 'profile.html', 'messages.html']) {
  const html = readFileSync(new URL('../' + path, import.meta.url), 'utf8');
  assert.ok(
    html.includes("p.username||('user_'+String(p.id||'').replace(/-/g,'').slice(0,8).toLowerCase())") ||
    html.includes("p?.username||('user_'+String(p?.id||'').replace(/-/g,'').slice(0,8).toLowerCase())") ||
    html.includes("p?.username||(p?.id?'user_'+String(p.id).replace(/-/g,'').slice(0,8).toLowerCase():'founder')"),
    path + ' must have a stable visible handle fallback.'
  );
}
console.log('Google/OAuth profile provisioning contracts passed.');
