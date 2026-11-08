import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';

const migrationsDir = new URL('../supabase/migrations/', import.meta.url);
const files = readdirSync(migrationsDir, { withFileTypes: true })
  .filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
  .map((entry) => entry.name)
  .sort();

assert.ok(files.length > 0, 'Supabase migration directory must contain SQL migrations');

const functionStart = /\bcreate\s+(?:or\s+replace\s+)?function\b/gi;
const dollarBody = /\bas\s+(\$[a-zA-Z_0-9]*\$)/i;
const findings = [];

for (const file of files) {
  const sql = readFileSync(new URL(file, migrationsDir), 'utf8');
  const starts = [...sql.matchAll(functionStart)].map((match) => match.index);

  for (let index = 0; index < starts.length; index += 1) {
    const start = starts[index];
    const end = starts[index + 1] ?? sql.length;
    const definition = sql.slice(start, end);
    const bodyStart = definition.search(dollarBody);
    if (bodyStart < 0) continue;

    const header = definition.slice(0, bodyStart);
    if (!/\bsecurity\s+definer\b/i.test(header)) continue;

    if (!/\bset\s+search_path\s*(?:=|to)\s*/i.test(header)) {
      findings.push(file);
    }
  }
}

assert.deepEqual(
  findings,
  [],
  'Every SECURITY DEFINER function in migrations must explicitly pin search_path. Missing in: ' + findings.join(', ')
);

console.log('SECURITY DEFINER migration checks passed across ' + files.length + ' SQL migrations.');
