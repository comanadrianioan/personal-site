// Runs assets/site/theme.js against a stubbed page and checks that every click flips what the
// visitor sees, and that a choice matching the system setting is not stored.
// Usage: node tests/theme-switch.test.mjs — exits 1 on the first failed assertion.
import { readFileSync } from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";

const src = readFileSync(new URL("../assets/site/theme.js", import.meta.url), "utf8");

function page(systemDark, saved, { storageThrows = false, noButton = false } = {}) {
  const store = new Map(saved ? [["theme", saved]] : []);
  const root = { dataset: saved ? { theme: saved } : {} };
  const attrs = {};
  const btn = {
    hidden: true, dataset: {}, title: "", listeners: {},
    setAttribute(k, v) { attrs[k] = v; },
    addEventListener(t, f) { this.listeners[t] = f; },
    click() { this.listeners.click(); },
  };
  const mql = { matches: systemDark, addEventListener(t, f) { this.onchange = f; } };
  const ctx = {
    document: { documentElement: root, querySelector: (s) => (s === ".theme-toggle" && !noButton ? btn : null) },
    localStorage: storageThrows
      ? { getItem() { throw new Error("blocked"); }, setItem() { throw new Error("blocked"); }, removeItem() { throw new Error("blocked"); } }
      : { getItem: (k) => store.get(k) ?? null, setItem: (k, v) => store.set(k, v), removeItem: (k) => store.delete(k) },
    matchMedia: () => mql,
  };
  ctx.window = ctx;
  vm.runInNewContext(src, ctx);
  const shown = () => root.dataset.theme || (mql.matches ? "dark" : "light");
  return { btn, root, store, attrs, shown, mql };
}

for (const systemDark of [false, true]) {
  const os = systemDark ? "dark" : "light";
  const other = systemDark ? "light" : "dark";
  const p = page(systemDark);
  assert.equal(p.btn.hidden, false, `${os} OS: button is shown once the script runs`);
  assert.equal(p.attrs["aria-label"], `Switch to ${other} theme`, `${os} OS: label names the next theme`);

  p.btn.click();
  assert.equal(p.shown(), other, `${os} OS: first click switches to ${other}`);
  assert.equal(p.store.get("theme"), other, `${os} OS: a choice that differs from the system is stored`);
  assert.equal(p.attrs["aria-label"], `Switch to ${os} theme`, `${os} OS: label updates after a click`);

  p.btn.click();
  assert.equal(p.shown(), os, `${os} OS: second click switches back`);
  assert.equal(p.store.has("theme"), false, `${os} OS: a choice equal to the system is not stored`);
  assert.equal(p.root.dataset.theme, undefined, `${os} OS: back to following the system`);
}

// A saved choice is honoured: the button offers the opposite.
const saved = page(false, "dark");
assert.equal(saved.attrs["aria-label"], "Switch to light theme", "saved dark: label offers light");
saved.btn.click();
assert.equal(saved.shown(), "light", "saved dark on a light OS: click shows light");

// A page without the switch: the script does nothing and does not throw.
assert.doesNotThrow(() => page(false, null, { noButton: true }), "no switch on the page: no error");

// Storage blocked (private mode, site data off): clicks still flip the theme for this visit.
const blocked = page(false, null, { storageThrows: true });
assert.doesNotThrow(() => blocked.btn.click(), "storage blocked: click does not throw");
assert.equal(blocked.shown(), "dark", "storage blocked: click still switches to dark");

// The system setting changes while the visitor follows it: the label follows too.
const follows = page(false);
follows.mql.matches = true;
follows.mql.onchange();
assert.equal(follows.attrs["aria-label"], "Switch to light theme", "system turns dark: label offers light");

console.log("theme switch: all assertions passed");
