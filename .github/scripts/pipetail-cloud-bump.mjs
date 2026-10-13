#!/usr/bin/env node
// Usage: pipetail-cloud-bump.mjs <module> <version> [dir]
// Writes the changed paths to stdout, NUL-separated, for `git add --pathspec-file-nul`.
import { execFileSync } from "node:child_process";
import { lstatSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const SEMVER = /^(\d+)\.(\d+)\.(\d+)$/;
const MODULE = /^[a-z0-9]+(-[a-z0-9]+)*$/;

export function compareVersions(a, b) {
  const pa = SEMVER.exec(a).slice(1).map(Number);
  const pb = SEMVER.exec(b).slice(1).map(Number);
  for (let i = 0; i < 3; i++) if (pa[i] !== pb[i]) return pa[i] - pb[i];
  return 0;
}

// The lookbehind stops a longer module name ending in the same words from matching, and the
// lookahead rejects pre-release suffixes such as -rc1.
export function refPattern(module) {
  return new RegExp(`(?<![\\w-])${module}-v(\\d+\\.\\d+\\.\\d+)(?![\\w-]|\\.\\d)`, "g");
}

export function bumpPins(text, module, version) {
  const replaced = [];
  const out = text.replace(refPattern(module), (ref, v) => {
    if (compareVersions(v, version) >= 0) return ref;
    replaced.push(ref);
    return `${module}-v${version}`;
  });
  return { text: out, replaced };
}

// Tests pin made-up versions as fixtures. Bumping one would change what the test asserts.
export function isTestPath(path) {
  return /(^|\/)(__tests__|tests?)\//.test(path) || /\.(test|spec)\.[^/]+$/.test(path);
}

export function bumpTree(dir, module, version) {
  if (!MODULE.test(module)) throw new Error(`not a module name: ${module}`);
  if (!SEMVER.test(version)) throw new Error(`not a version: ${version}`);

  const files = execFileSync("git", ["ls-files", "-z"], { cwd: dir, encoding: "utf8" }).split("\0").filter(Boolean);
  const changed = [];
  for (const file of files) {
    if (isTestPath(file)) continue;
    const path = join(dir, file);
    if (!lstatSync(path, { throwIfNoEntry: false })?.isFile()) continue;
    const buf = readFileSync(path);
    if (buf.includes(0)) continue;
    const { text, replaced } = bumpPins(buf.toString("utf8"), module, version);
    if (replaced.length === 0) continue;
    writeFileSync(path, text);
    changed.push({ file, replaced });
  }
  return changed;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [module, version, dir = "."] = process.argv.slice(2);
  if (!module || !version) {
    console.error("usage: pipetail-cloud-bump.mjs <module> <version> [dir]");
    process.exit(2);
  }
  const changed = bumpTree(dir, module, version);
  for (const { file, replaced } of changed) {
    console.error(`${file}: ${[...new Set(replaced)].join(", ")} -> ${module}-v${version}`);
  }
  process.stdout.write(changed.map((c) => `${c.file}\0`).join(""));
}
