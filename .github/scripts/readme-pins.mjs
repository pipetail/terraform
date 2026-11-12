#!/usr/bin/env node
// Reads the repository's tag list, one tag per line, from stdin.
//
//   readme-pins.mjs                    rewrites the stale pins in the current directory
//   readme-pins.mjs --base <checkout>  writes nothing, and fails on a stale pin that
//                                      the current directory has and <checkout> lacks
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

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
function declaredVersion(root, mod) {
  const versionFile = join(root, "modules", mod, "VERSION");
  if (existsSync(versionFile)) return readFileSync(versionFile, "utf8").trim();
  const pkg = join(root, "src", mod, "package.json");
  if (existsSync(pkg)) return JSON.parse(readFileSync(pkg, "utf8")).version;
  return null;
}

// Returns null for a module with no release yet: module-release creates the
// first tag only after the merge of the PR that adds the module.
function latestVersion(root, mod) {
  const prefix = `${mod}-v`;
  const candidates = tags.filter((t) => t.startsWith(prefix)).map((t) => t.slice(prefix.length));
  candidates.push(declaredVersion(root, mod));
  const valid = candidates.filter((v) => v && SEMVER.test(v));
  return valid.length === 0 ? null : valid.reduce(newer);
}

function scan(root) {
  const modules = readdirSync(join(root, "modules"), { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
  const versions = modules.map((m) => [m, latestVersion(root, m)]).filter(([, version]) => version);
  const readmes = ["README.md", ...modules.map((m) => `modules/${m}/README.md`)].filter((f) => existsSync(join(root, f)));

  const changed = [];
  for (const file of readmes) {
    const before = readFileSync(join(root, file), "utf8");
    const stale = [];
    let after = before;
    for (const [mod, version] of versions) {
      const current = `${mod}-v${version}`;
      // The lookbehind keeps a module name from matching the tail of a longer one.
      const pin = new RegExp(`(?<=\`|\\?ref=)${mod}-v\\d+\\.\\d+\\.\\d+`, "g");
      after = after.replace(pin, (found) => {
        if (found !== current) stale.push({ file, mod, version: found.slice(mod.length + 2) });
        return current;
      });
    }
    if (after !== before) changed.push({ file, after, stale });
  }
  return changed;
}

const baseFlag = process.argv.indexOf("--base");
if (baseFlag === -1) {
  for (const { file, after } of scan(".")) {
    writeFileSync(file, after);
    console.log(`updated ${file}`);
  }
} else {
  const base = process.argv[baseFlag + 1];
  if (!base || !existsSync(join(base, "modules"))) throw new Error("--base needs the path of a checkout of the base commit");
  // A release on the base branch makes pins stale in every open PR, also a pin
  // that the PR moved to the version that was newest before that release. So a
  // stale pin of the base cancels one pin here of the same file and module
  // that is not older than it.
  const inBase = scan(base).flatMap((r) => r.stale);
  let introduced = 0;
  for (const pin of scan(".").flatMap((r) => r.stale)) {
    const i = inBase.findIndex((b) => b.file === pin.file && b.mod === pin.mod && newer(b.version, pin.version) === pin.version);
    if (i !== -1) {
      inBase.splice(i, 1);
      continue;
    }
    console.error(`${pin.file}: stale pin ${pin.mod}-v${pin.version}`);
    introduced++;
  }
  if (introduced > 0) process.exit(1);
}
