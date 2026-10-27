import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const source0 = read('settings.html');
assert.ok(source0.includes("settings-section-navigation"), "settings.html is missing contract: settings-section-navigation");
assert.ok(source0.includes("data-section"), "settings.html is missing contract: data-section");
assert.ok(source0.includes("data-setting="), "settings.html is missing contract: data-setting=");
assert.ok(source0.includes("account_settings"), "settings.html is missing contract: account_settings");
assert.ok(source0.includes("public_profile"), "settings.html is missing contract: public_profile");
assert.ok(source0.includes("public_dms"), "settings.html is missing contract: public_dms");
assert.ok(source0.includes("Settings saved."), "settings.html is missing contract: Settings saved.");
assert.ok(source0.includes("Could not load settings:"), "settings.html is missing contract: Could not load settings:");

console.log("Phase 1 settings-persistence contract checks passed.");
