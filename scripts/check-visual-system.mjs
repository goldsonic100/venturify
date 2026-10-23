import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const pages = [
  "index.html",
  "feed.html",
  "messages.html",
  "communities.html",
  "profile.html",
  "discover.html",
  "workspace.html",
  "collaborations.html",
  "notifications.html",
  "principles.html",
];
const stylesheet = "assets/venturify-design-system.css";
const css = readFileSync(stylesheet, "utf8");

assert.match(css, /--paper:\s*#07111f/i, "dark navy design token should exist");
assert.match(css, /--accent:\s*#3890ff/i, "blue accent token should exist");
assert.match(css, /prefers-reduced-motion/i, "reduced-motion support should exist");

for (const page of pages) {
  const html = readFileSync(page, "utf8");
  assert.ok(
    html.includes(stylesheet),
    `${page} must load the shared design system`,
  );
  assert.equal(
    (html.match(/assets\/venturify-design-system\.css/g) ?? []).length,
    1,
    `${page} should load the shared stylesheet exactly once`,
  );
}

console.log(`Visual-system smoke check passed for ${pages.length} pages.`);
