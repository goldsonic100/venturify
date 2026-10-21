import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const root = process.cwd();
const entries = await readdir(root, { withFileTypes: true });
const pages = entries
  .filter((entry) => entry.isFile() && entry.name.endsWith(".html"))
  .map((entry) => entry.name)
  .sort();

if (pages.length === 0) {
  throw new Error("No root-level HTML pages were found.");
}

let checkedScripts = 0;
const failures = [];

for (const page of pages) {
  const html = await readFile(path.join(root, page), "utf8");
  const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script\s*>/gi)];

  for (let index = 0; index < scripts.length; index += 1) {
    const source = scripts[index][1].trim();
    if (!source) continue;
    checkedScripts += 1;

    try {
      // Compile only; never execute application code or contact Supabase.
      new Function(source);
    } catch (error) {
      failures.push(`${page}: inline script ${index + 1}: ${error.message}`);
    }
  }
}

console.log(`Checked ${pages.length} HTML pages and ${checkedScripts} inline JavaScript blocks.`);

if (failures.length) {
  console.error(failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log("Static-site JavaScript syntax checks passed.");
}
