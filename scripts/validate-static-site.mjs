import { Script } from "node:vm";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

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
    const tag = scripts[index][0].slice(0, scripts[index][0].indexOf(">"));
    const type = tag.match(/\btype\s*=\s*["']?([^"'\s>]+)/i)?.[1]?.toLowerCase();
    const javascriptTypes = new Set(["text/javascript", "application/javascript", "module", "text/ecmascript", "application/ecmascript"]);
    if (type && !javascriptTypes.has(type)) continue;

    const source = scripts[index][1].trim();
    if (!source) continue;
    checkedScripts += 1;

    try {
      // Compile only; never execute application code or contact Supabase.
      new Script(source, { filename: `${page}:inline-script-${index + 1}` });
    } catch (error) {
      failures.push(`${page}: inline script ${index + 1}: ${error.stack}`);
    }
  }
}


const knownPages = new Set(pages);
let checkedLocalLinks = 0;

for (const page of pages) {
  const html = await readFile(path.join(root, page), "utf8");
  for (const match of html.matchAll(/\b(?:href|action)\s*=\s*["']([^"'#?]+\.html)(?:[?#][^"']*)?["']/gi)) {
    const rawTarget = match[1].replace(/^\.\//, "");
    // This smoke check intentionally covers local root-level HTML routes only.
    if (/^(?:[a-z]+:|\/\/)/i.test(rawTarget) || rawTarget.includes("/")) continue;
    checkedLocalLinks += 1;
    if (!knownPages.has(rawTarget)) {
      failures.push(page + ': local HTML link points to missing page "' + rawTarget + '"');
    }
  }
}

console.log(`Checked ${pages.length} HTML pages, ${checkedScripts} inline JavaScript blocks, and ${checkedLocalLinks} local HTML links.`);

if (failures.length) {
  console.error(failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log("Static-site JavaScript syntax checks passed.");
}
