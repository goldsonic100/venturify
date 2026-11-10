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



const triggerHardening = readFileSync(new URL('../supabase/migrations/20261111010000_pin_trigger_security_definer_search_path.sql', import.meta.url), 'utf8').toLowerCase();
const rewrittenTriggerFunctions = [
  'log_workspace_activity_event',
  'log_workspace_task_checklist_activity',
  'notify_workspace_checklist_completion',
  'notify_workspace_task_change',
  'notify_workspace_task_changes',
];
const alteredTriggerFunctions = [
  'notify_workspace_message',
  'notify_workspace_task_comment',
  'rls_auto_enable',
];
for (const name of rewrittenTriggerFunctions) {
  const start = triggerHardening.indexOf('create or replace function public.' + name + '(');
  const end = start < 0 ? -1 : triggerHardening.indexOf('$function$;', start);
  const definition = start < 0 || end < 0 ? '' : triggerHardening.slice(start, end);
  assert.ok(definition, 'Trigger hardening migration must recreate ' + name);
  assert.ok(definition.includes("set search_path to ''"), name + ' must pin an empty search_path');
  assert.ok(definition.includes('auth.uid()'), name + ' must schema-qualify auth.uid()');
}
for (const name of alteredTriggerFunctions) {
  assert.ok(
    triggerHardening.includes('alter function public.' + name + "() set search_path = '';"),
    name + ' must be altered to an empty search_path',
  );
}
console.log('Remaining SECURITY DEFINER trigger functions are pinned to an empty search_path.');
