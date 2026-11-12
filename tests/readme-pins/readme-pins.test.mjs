import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT = fileURLToPath(new URL("../../.github/scripts/readme-pins.mjs", import.meta.url));

function checkout(files) {
  const root = mkdtempSync(join(tmpdir(), "readme-pins-"));
  mkdirSync(join(root, "modules"));
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
  return root;
}

function run(cwd, tags, args = []) {
  return spawnSync(process.execPath, [SCRIPT, ...args], { cwd, input: tags.join("\n"), encoding: "utf8" });
}

const pin = (ref) => `source = "git::https://github.com/example-org/example-repo.git//modules/x?ref=${ref}"\n`;

test("rewrites a stale pin to the newest tag", () => {
  const root = checkout({ "modules/eks/README.md": pin("eks-v1.0.0") });
  const result = run(root, ["eks-v1.0.0", "eks-v1.10.0", "eks-v1.9.0"]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(join(root, "modules/eks/README.md"), "utf8"), pin("eks-v1.10.0"));
});

test("fails without tags", () => {
  const root = checkout({ "modules/eks/README.md": pin("eks-v1.0.0") });
  assert.notEqual(run(root, []).status, 0);
});

test("leaves the pins of a module with no release untouched", () => {
  const files = { "README.md": `| \`eks-v1.0.0\` | \`newmod-v1.0.0\` |\n`, "modules/eks/README.md": pin("eks-v1.0.0"), "modules/newmod/README.md": pin("newmod-v1.0.0") };
  const root = checkout(files);
  const result = run(root, ["eks-v1.1.0"]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(join(root, "modules/newmod/README.md"), "utf8"), pin("newmod-v1.0.0"));
  assert.equal(readFileSync(join(root, "README.md"), "utf8"), `| \`eks-v1.1.0\` | \`newmod-v1.0.0\` |\n`);

  const head = checkout(files);
  const base = checkout({ "README.md": `| \`eks-v1.0.0\` |\n`, "modules/eks/README.md": pin("eks-v1.0.0") });
  assert.equal(run(head, ["eks-v1.1.0"], ["--base", base]).status, 0);
});

test("--base passes on a stale pin that the base already has", () => {
  const base = checkout({ "modules/eks/README.md": `# eks\n${pin("eks-v1.0.0")}`, "modules/kms/README.md": `A tpyo.\n${pin("kms-v1.0.0")}` });
  const head = checkout({ "modules/eks/README.md": `# eks\n${pin("eks-v1.0.0")}`, "modules/kms/README.md": `A typo.\n${pin("kms-v1.0.0")}` });
  const result = run(head, ["eks-v1.1.0", "kms-v1.0.0"], ["--base", base]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(join(head, "modules/eks/README.md"), "utf8"), `# eks\n${pin("eks-v1.0.0")}`);
});

test("--base passes on a pin that the head moved forward before a newer release", () => {
  const base = checkout({ "modules/eks/README.md": pin("eks-v1.0.0") });
  const head = checkout({ "modules/eks/README.md": pin("eks-v1.1.0") });
  assert.equal(run(head, ["eks-v1.0.0", "eks-v1.1.0", "eks-v1.2.0"], ["--base", base]).status, 0);
  assert.equal(run(base, ["eks-v1.0.0", "eks-v1.1.0", "eks-v1.2.0"], ["--base", head]).status, 1);
});

test("--base passes when the head reorders the stale pins of the base", () => {
  const base = checkout({ "modules/eks/README.md": pin("eks-v1.0.0") + pin("eks-v2.0.0") });
  const head = checkout({ "modules/eks/README.md": pin("eks-v2.0.0") + pin("eks-v1.0.0") });
  const result = run(head, ["eks-v3.0.0"], ["--base", base]);
  assert.equal(result.status, 0, result.stderr);
});

test("--base fails on a stale pin that the head adds", () => {
  const base = checkout({ "modules/eks/README.md": pin("eks-v1.0.0"), "modules/kms/README.md": pin("kms-v1.2.0") });
  const tags = ["eks-v1.1.0", "kms-v1.2.0"];

  const changed = checkout({ "modules/eks/README.md": pin("eks-v1.0.0"), "modules/kms/README.md": pin("kms-v1.1.0") });
  const result = run(changed, tags, ["--base", base]);
  assert.equal(result.status, 1);
  assert.equal(result.stderr, "modules/kms/README.md: stale pin kms-v1.1.0\n");

  const repeated = checkout({ "modules/eks/README.md": pin("eks-v1.0.0") + pin("eks-v1.0.0"), "modules/kms/README.md": pin("kms-v1.2.0") });
  assert.equal(run(repeated, tags, ["--base", base]).stderr, "modules/eks/README.md: stale pin eks-v1.0.0\n");
});

test("--base fails when the head bumps a VERSION file and keeps the old pin", () => {
  const readme = { "modules/role/README.md": pin("role-v1.0.0") };
  const base = checkout({ ...readme, "modules/role/VERSION": "1.0.0\n" });
  const head = checkout({ ...readme, "modules/role/VERSION": "1.1.0\n" });
  assert.equal(run(head, ["role-v1.0.0"], ["--base", base]).status, 1);
});
