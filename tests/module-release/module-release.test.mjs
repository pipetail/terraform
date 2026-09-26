import { test } from "node:test";
import assert from "node:assert/strict";
import {
  bumpFor,
  checkTitle,
  maxBump,
  nextVersion,
  parseTitle,
  touchedModules,
} from "../../.github/scripts/module-release.mjs";

const MODULES = new Set(["eks", "kms", "github-oidc"]);

test("parseTitle reads type, scope and the breaking marker", () => {
  assert.deepEqual(parseTitle("feat(eks)!: drop aws-auth"), { type: "feat", scope: "eks", breaking: true });
  assert.deepEqual(parseTitle("fix: typo"), { type: "fix", scope: undefined, breaking: false });
  assert.equal(parseTitle("Update eks"), null);
  assert.equal(parseTitle("feat(eks):missing space"), null);
});

test("bumpFor maps commit types to semver bumps", () => {
  assert.equal(bumpFor("fix(eks): x (#1)"), "patch");
  assert.equal(bumpFor("chore(deps): x"), "patch");
  assert.equal(bumpFor("feat(eks): x"), "minor");
  assert.equal(bumpFor("feat(eks)!: x"), "major");
  assert.equal(bumpFor("fix(eks): x", "details\n\nBREAKING CHANGE: input renamed"), "major");
  assert.equal(bumpFor("not conventional"), "patch");
});

test("maxBump takes the largest bump across a push", () => {
  assert.equal(maxBump(["patch", "minor", "patch"]), "minor");
  assert.equal(maxBump(["minor", "major"]), "major");
  assert.equal(maxBump([]), "patch");
});

test("nextVersion seeds at 1.0.0 and bumps semver", () => {
  assert.equal(nextVersion(null), "1.0.0");
  assert.equal(nextVersion("1.4.2", "patch"), "1.4.3");
  assert.equal(nextVersion("1.4.2", "minor"), "1.5.0");
  assert.equal(nextVersion("1.4.2", "major"), "2.0.0");
  assert.throws(() => nextVersion("1.4", "patch"));
});

test("touchedModules ignores docs and files outside modules/", () => {
  const mods = touchedModules([
    "modules/eks/main.tf",
    "modules/eks/templates/user-data.toml.tftpl",
    "modules/kms/README.md",
    "examples/05-aws-complete/eks.tf",
  ]);
  assert.deepEqual([...mods], ["eks"]);
});

test("checkTitle accepts a single-module PR scoped to that module", () => {
  assert.deepEqual(checkTitle("fix(eks): pin addons", ["modules/eks/main.tf"], MODULES), []);
});

test("checkTitle rejects a single-module PR with another scope", () => {
  assert.equal(checkTitle("fix: pin addons", ["modules/eks/main.tf"], MODULES).length, 1);
  assert.equal(checkTitle("fix(ci): pin addons", ["modules/eks/main.tf"], MODULES).length, 1);
});

test("checkTitle rejects a module scope that does not match the changed module", () => {
  assert.equal(checkTitle("fix(kms): x", ["modules/eks/main.tf"], MODULES).length, 1);
});

test("checkTitle allows a module scope when only non-module code changes", () => {
  assert.deepEqual(checkTitle("fix(eks): x", ["src/eks/index.mjs", "tests/eks/a.test.mjs"], MODULES), []);
});

test("checkTitle allows deps updates across modules", () => {
  const files = ["modules/eks/eks.tf", "modules/kms/main.tf"];
  assert.deepEqual(checkTitle("chore(deps): update terraform modules", files, MODULES), []);
  assert.deepEqual(checkTitle("chore(deps): update eks module", ["modules/eks/eks.tf"], MODULES), []);
});

test("checkTitle rejects a module scope on a multi-module PR", () => {
  const files = ["modules/eks/eks.tf", "modules/kms/main.tf"];
  assert.equal(checkTitle("feat(eks): x", files, MODULES).length, 1);
  assert.deepEqual(checkTitle("fix(policy): x", files, MODULES), []);
});

test("checkTitle ignores PRs that change no module", () => {
  assert.deepEqual(checkTitle("chore(ci): x", [".github/workflows/a.yaml"], MODULES), []);
  assert.deepEqual(checkTitle("docs: x", ["modules/eks/README.md"], MODULES), []);
});

test("checkTitle rejects a title that is not a conventional commit", () => {
  assert.equal(checkTitle("Update README", ["README.md"], MODULES).length, 1);
});
