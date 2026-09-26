#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

// These modules have their own release workflows. Tagging them here as well
// would cut a second tag line under the same prefix.
export const SELF_RELEASED = new Set([
  "aws-events-to-slack",
  "pipetail-cloud-health-ingest",
  "pipetail-cloud-role",
]);

const TITLE = /^(?<type>[a-z]+)(?:\((?<scope>[^()]+)\))?(?<bang>!)?: \S/;
const SEMVER = /^(\d+)\.(\d+)\.(\d+)$/;
const RANK = { patch: 0, minor: 1, major: 2 };

export function parseTitle(title) {
  const m = TITLE.exec(title);
  if (!m) return null;
  return { type: m.groups.type, scope: m.groups.scope, breaking: Boolean(m.groups.bang) };
}

export function bumpFor(subject, body = "") {
  const t = parseTitle(subject);
  if (t?.breaking || /^BREAKING[ -]CHANGE:/m.test(body)) return "major";
  if (t?.type === "feat") return "minor";
  return "patch";
}

export function maxBump(bumps) {
  return bumps.reduce((a, b) => (RANK[b] > RANK[a] ? b : a), "patch");
}

export function nextVersion(current, bump) {
  if (!current) return "1.0.0";
  const m = SEMVER.exec(current);
  if (!m) throw new Error(`not a version: ${current}`);
  const [major, minor, patch] = m.slice(1).map(Number);
  if (bump === "major") return `${major + 1}.0.0`;
  if (bump === "minor") return `${major}.${minor + 1}.0`;
  return `${major}.${minor}.${patch + 1}`;
}

// Docs do not change what a consumer resolves at a ref, so they never cut a release.
export function touchedModules(files) {
  const mods = new Set();
  for (const f of files) {
    const m = /^modules\/([^/]+)\/(.+)$/.exec(f);
    if (m && !m[2].endsWith(".md")) mods.add(m[1]);
  }
  return mods;
}

export function checkTitle(title, files, allModules) {
  const t = parseTitle(title);
  if (!t) return [`Title "${title}" is not a conventional commit, e.g. "fix(eks): pin the addon versions".`];

  const mods = touchedModules(files);
  const scopeIsModule = allModules.has(t.scope);
  const errors = [];

  if (mods.size === 1) {
    const [only] = mods;
    if (t.scope !== only && t.scope !== "deps") {
      errors.push(`This PR changes only modules/${only}, so the title scope must be "${only}". The release notes and the version bump for ${only} come from this title.`);
    }
  } else if (mods.size > 1 && scopeIsModule) {
    errors.push(`This PR changes ${mods.size} modules (${[...mods].sort().join(", ")}) but the scope names one. Split it into one PR per module, or use a scope that is not a module name.`);
  }
  return errors;
}

function git(...args) {
  return execFileSync("git", args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
}

function moduleNames() {
  return readdirSync("modules", { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
}

function latestVersion(mod) {
  const tags = git("tag", "--list", `${mod}-v*`, "--sort=-v:refname").split("\n");
  for (const tag of tags) {
    const v = tag.slice(`${mod}-v`.length);
    if (SEMVER.test(v)) return v;
  }
  return null;
}

function resolveBase(before) {
  if (before) {
    try {
      git("cat-file", "-e", `${before}^{commit}`);
      return before;
    } catch {
      // A new branch or a force-push reports a "before" SHA that is not in this clone.
    }
  }
  try {
    return git("rev-parse", "HEAD^");
  } catch {
    return null;
  }
}

function commitsTouching(base, mod) {
  const out = git(
    "log", "--format=%s%x1f%b%x1e", `${base}..HEAD`, "--",
    `modules/${mod}/`, `:(exclude,glob)modules/${mod}/**/*.md`,
  );
  return out
    .split("\x1e")
    .map((c) => c.trim())
    .filter(Boolean)
    .map((c) => {
      const [subject, body = ""] = c.split("\x1f");
      return { subject, body };
    });
}

function release() {
  const sha = process.env.GITHUB_SHA || git("rev-parse", "HEAD");
  const base = resolveBase(process.env.BEFORE);
  const dryRun = process.env.DRY_RUN === "1";

  for (const mod of moduleNames()) {
    if (SELF_RELEASED.has(mod)) continue;

    const current = latestVersion(mod);
    let version;
    let notes;
    if (!current) {
      version = nextVersion(null);
      notes = `First release of the ${mod} module.`;
    } else {
      if (!base) continue;
      const commits = commitsTouching(base, mod);
      if (commits.length === 0) continue;
      version = nextVersion(current, maxBump(commits.map((c) => bumpFor(c.subject, c.body))));
      notes = commits.map((c) => `- ${c.subject}`).join("\n");
    }

    const tag = `${mod}-v${version}`;
    console.log(`${tag} (was ${current ?? "none"})`);
    if (dryRun) continue;
    execFileSync(
      "gh",
      ["release", "create", tag, "--target", sha, "--title", tag, "--notes", notes, "--latest=false"],
      { stdio: "inherit" },
    );
  }
}

function checkTitleCli() {
  const title = process.env.TITLE ?? "";
  const base = process.env.BASE;
  if (!base) throw new Error("BASE (a git revision to diff against) is required");
  const files = git("diff", "--name-only", base, "HEAD").split("\n").filter(Boolean);
  const errors = checkTitle(title, files, new Set(moduleNames()));
  for (const e of errors) console.log(`::error::${e}`);
  if (errors.length) process.exit(1);
  console.log(`Title OK: ${title}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const cmd = process.argv[2];
  if (cmd === "release") release();
  else if (cmd === "check-title") checkTitleCli();
  else {
    console.error("usage: module-release.mjs release|check-title");
    process.exit(2);
  }
}
