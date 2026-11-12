#!/usr/bin/env node
// Reads the repository's tag list, one tag per line, from stdin.
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";

const SEMVER = /^(\d+)\.(\d+)\.(\d+)$/;

const tags = readFileSync(0, "utf8").split("\n").map((t) => t.trim()).filter(Boolean);
// A clone without tags would otherwise rewrite nothing and pass.
if (tags.length === 0) throw new Error("no tags on stdin. Fetch the tags, then pipe the tag list into this script.");

function newer(a, b) {
  const [x, y] = [a, b].map((v) => SEMVER.exec(v).slice(1).map(Number));
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] > y[i] ? a : b;
  return a;
}

// The self-released modules get their tag only after the merge, from a version
// the PR itself bumps. That PR already pins the new version in the README, so
// the tag alone would call a correct pin stale.
function declaredVersion(mod) {
  const versionFile = `modules/${mod}/VERSION`;
  if (existsSync(versionFile)) return readFileSync(versionFile, "utf8").trim();
  const pkg = `src/${mod}/package.json`;
  if (existsSync(pkg)) return JSON.parse(readFileSync(pkg, "utf8")).version;
  return null;
}

function latestVersion(mod) {
  const prefix = `${mod}-v`;
  const candidates = tags.filter((t) => t.startsWith(prefix)).map((t) => t.slice(prefix.length));
  candidates.push(declaredVersion(mod));
  const valid = candidates.filter((v) => v && SEMVER.test(v));
  if (valid.length === 0) throw new Error(`no ${mod}-vX.Y.Z tag found`);
  return valid.reduce(newer);
}

const modules = readdirSync("modules", { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .map((d) => d.name)
  .sort();

const readmes = ["README.md", ...modules.map((m) => `modules/${m}/README.md`)].filter((f) => existsSync(f));
const versions = new Map(modules.map((m) => [m, latestVersion(m)]));

for (const file of readmes) {
  const before = readFileSync(file, "utf8");
  let after = before;
  for (const [mod, version] of versions) {
    // The lookbehind keeps a module name from matching the tail of a longer one.
    const pin = new RegExp(`(?<=\`|\\?ref=)${mod}-v\\d+\\.\\d+\\.\\d+`, "g");
    after = after.replace(pin, `${mod}-v${version}`);
  }
  if (after !== before) {
    writeFileSync(file, after);
    console.log(`updated ${file}`);
  }
}
