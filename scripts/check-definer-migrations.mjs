import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';

const migrationsDir = new URL('../supabase/migrations/', import.meta.url);
const files = readdirSync(migrationsDir, { withFileTypes: true })
  .filter((entry) => entry.isFile() && entry.name.endsWith('.sql'))
  .map((entry) => entry.name)
  .sort();

function findUnpinnedSecurityDefiners(sql, fileName = '<fixture>') {
  const functionStart = /\bcreate\s+(?:or\s+replace\s+)?function\b/gi;
  // PostgreSQL permits both dollar-quoted and single-quoted function bodies.
  const bodyStartPattern = /\bas\s+(?=\$[a-zA-Z_0-9]*\$|')/i;
  const starts = [...sql.matchAll(functionStart)].map((match) => match.index);
  const findings = [];

  for (let index = 0; index < starts.length; index += 1) {
    const start = starts[index];
    const end = starts[index + 1] ?? sql.length;
    const definition = sql.slice(start, end);
    const bodyStart = definition.search(bodyStartPattern);
    if (bodyStart < 0) continue;

    const header = definition.slice(0, bodyStart);
    if (!/\bsecurity\s+definer\b/i.test(header)) continue;

    if (!/\bset\s+search_path\s*(?:=|to)\s*/i.test(header)) {
      findings.push(fileName);
    }
  }

  return findings;
}

// Keep parser edge cases executable so future edits cannot silently disable the scanner.
assert.deepEqual(
  findUnpinnedSecurityDefiners(`
    CREATE FUNCTION public.safe_fn() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$ BEGIN NULL; END; $$;
    CREATE OR REPLACE FUNCTION public.unsafe_fn() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER AS $body$ BEGIN NULL; END; $body$;
  `),
  ['<fixture>'],
  'Scanner must recognize multiple functions and flag an unpinned SECURITY DEFINER function',
);
assert.deepEqual(
  findUnpinnedSecurityDefiners(`
    CREATE FUNCTION public.quoted_body() RETURNS text
    LANGUAGE sql SECURITY DEFINER AS 'SELECT current_user';
  `),
  ['<fixture>'],
  'Scanner must recognize single-quoted function bodies',
);
assert.deepEqual(
  findUnpinnedSecurityDefiners(`
    CREATE FUNCTION public.invoker_fn() RETURNS void
    LANGUAGE plpgsql SECURITY INVOKER AS $$ BEGIN NULL; END; $$;
  `),
  [],
  'SECURITY INVOKER functions do not require SECURITY DEFINER search_path checks',
);

assert.ok(files.length > 0, 'Supabase migration directory must contain SQL migrations');

const findings = files.flatMap((file) =>
  findUnpinnedSecurityDefiners(readFileSync(new URL(file, migrationsDir), 'utf8'), file),
);

assert.deepEqual(
  findings,
  [],
  'Every SECURITY DEFINER function in migrations must explicitly pin search_path. Missing in: ' + findings.join(', ')
);

console.log('SECURITY DEFINER migration checks passed across ' + files.length + ' SQL migrations (including parser fixtures).');
