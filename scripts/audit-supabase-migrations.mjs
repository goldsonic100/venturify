#!/usr/bin/env node
/**
 * Compare a Supabase migration ledger JSON export with local SQL migration files.
 *
 * Usage:
 *   node scripts/audit-supabase-migrations.mjs migration-ledger.json [supabase/migrations]
 *   node scripts/audit-supabase-migrations.mjs migration-ledger.json [supabase/migrations] --report-only
 *
 * The script is read-only. It never renames, edits, applies, or deletes migrations.
 */
import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

const args = process.argv.slice(2);
const ledgerPath = args.find((arg) => !arg.startsWith("--"));
const migrationsDir = args.filter((arg) => !arg.startsWith("--"))[1] ?? "supabase/migrations";
const reportOnly = args.includes("--report-only");

if (!ledgerPath) {
  console.error("Usage: node scripts/audit-supabase-migrations.mjs <ledger.json> [migrations-dir] [--report-only]");
  process.exit(64);
}

function unwrapLedger(value) {
  if (Array.isArray(value)) return value;
  if (Array.isArray(value?.migrations)) return value.migrations;
  if (Array.isArray(value?.result?.migrations)) return value.result.migrations;
  throw new Error("Ledger JSON must be an array or contain a migrations array.");
}

function parseFilename(filename) {
  if (!filename.endsWith(".sql")) return null;
  const stem = filename.slice(0, -4);
  const match = stem.match(/^(\d+)_(.+)$/);
  if (!match) return { filename, version: null, name: stem };
  return { filename, version: match[1], name: match[2] };
}

const ledgerRaw = await readFile(path.resolve(ledgerPath), "utf8");
const ledger = unwrapLedger(JSON.parse(ledgerRaw)).map((row) => ({
  version: String(row.version ?? ""),
  name: String(row.name ?? ""),
})).filter((row) => row.version && row.name);

const filenames = (await readdir(path.resolve(migrationsDir)))
  .map(parseFilename)
  .filter(Boolean);

const byExact = new Map(filenames.map((file) => [file.filename, file]));
const byName = new Map();
for (const file of filenames) {
  const entries = byName.get(file.name) ?? [];
  entries.push(file);
  byName.set(file.name, entries);
}

const duplicateLedgerVersions = [...ledger.reduce((map, row) => {
  map.set(row.version, (map.get(row.version) ?? 0) + 1);
  return map;
}, new Map())].filter(([, count]) => count > 1).map(([version, count]) => ({ version, count }));

const exactMatches = [];
const sameNameDifferentVersion = [];
const missingSource = [];
for (const row of ledger) {
  const expectedFilename = `${row.version}_${row.name}.sql`;
  if (byExact.has(expectedFilename)) {
    exactMatches.push({ ...row, filename: expectedFilename });
  } else if (byName.has(row.name)) {
    sameNameDifferentVersion.push({
      ...row,
      expectedFilename,
      candidateFiles: byName.get(row.name).map((file) => file.filename),
    });
  } else {
    missingSource.push({ ...row, expectedFilename });
  }
}

const ledgerKeys = new Set(ledger.map((row) => `${row.version}_${row.name}.sql`));
const repositoryOnlyFiles = filenames
  .filter((file) => !ledgerKeys.has(file.filename))
  .map((file) => ({
    filename: file.filename,
    version: file.version,
    name: file.name,
    ledgerHasSameName: ledger.some((row) => row.name === file.name),
  }));

const report = {
  generatedAt: new Date().toISOString(),
  ledgerPath: path.resolve(ledgerPath),
  migrationsDir: path.resolve(migrationsDir),
  counts: {
    ledgerEntries: ledger.length,
    repositorySqlFiles: filenames.length,
    exactMatches: exactMatches.length,
    sameNameDifferentVersion: sameNameDifferentVersion.length,
    missingSource: missingSource.length,
    repositoryOnlyFiles: repositoryOnlyFiles.length,
    duplicateLedgerVersions: duplicateLedgerVersions.length,
  },
  duplicateLedgerVersions,
  exactMatches,
  sameNameDifferentVersion,
  missingSource,
  repositoryOnlyFiles,
  safetyNote: "Read-only audit only. A same-name match is a candidate, not proof that SQL contents are equivalent. Do not replay or rename migrations based on filenames alone.",
};

console.log(JSON.stringify(report, null, 2));
if (!reportOnly && (missingSource.length || sameNameDifferentVersion.length || repositoryOnlyFiles.length || duplicateLedgerVersions.length)) {
  process.exitCode = 2;
}
