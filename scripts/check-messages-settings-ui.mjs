import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const read = (path) => readFileSync(path, "utf8");
const settings = read("settings.html");
const messages = read("messages.html");
const design = read("assets/venturify-design-system.css");

assert.ok(settings.includes('assets/venturify-design-system.css'), "settings page should use shared design system");
assert.ok(settings.includes("function activate(button)"), "settings navigation should use a shared activation handler");
assert.ok(settings.includes("section.hidden=!active"), "settings navigation should hide inactive sections");
assert.ok(settings.includes('[id^="section-"][hidden]{display:none!important}'), "hidden settings panels should not be forced visible by panel styles");
assert.ok(settings.includes('data-section'), "settings sections must retain navigation controls");
assert.match(design, /\.chat-message-list\s*\{[^}]*max-height:\s*none\s*!important/s, "conversation history should be allowed to grow and scroll");
assert.match(design, /\.messages-chat-body\s*\{[^}]*overflow:\s*hidden/s, "chat body should constrain the scrolling conversation region");
assert.match(messages, /class="[^"]*\\bchat-message-list\\b[^"]*"/, "messages page should retain its conversation history container");
console.log("Messaging and settings UI smoke checks passed.");
