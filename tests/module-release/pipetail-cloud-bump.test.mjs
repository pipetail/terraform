import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { bumpPins, bumpTree, compareVersions, isTestPath } from "../../.github/scripts/pipetail-cloud-bump.mjs";

const ROLE = "pipetail-cloud-role";
const INGEST = "pipetail-cloud-health-ingest";
const SOURCE = "git::https://github.com/pipetail/terraform.git//modules";

const FIXTURES = {
  "worker/src/routes/accounts.ts": `export const SCAN_ROLE_MODULE_REF = "${ROLE}-v2.4.0";\n`,
  "worker/src/routes/__tests__/accounts-terraform-module.test.ts":
    `expect(SCAN_ROLE_MODULE_REF).toMatch(/^${ROLE}-v\\d+\\.\\d+\\.\\d+$/);\n`,
  "terraform/health-ingest.tf": ["a", "b", "c"]
    .map((n) => `module "${n}" {\n  source = "${SOURCE}/${INGEST}?ref=${INGEST}-v2.0.0"\n}\n`)
    .join("\n"),
  "terraform/health-ingest-module-ref.json": `{\n  "ref": "${INGEST}-v2.0.0"\n}\n`,
  "scripts/terraform/health-ingest-module-ref.test.mjs": `writeFileSync(file, '{ "ref": "${INGEST}-v1.0.0" }');\n`,
};

function fixtureRepo() {
  const dir = mkdtempSync(join(tmpdir(), "pipetail-cloud-bump-"));
  for (const [file, text] of Object.entries(FIXTURES)) {
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    writeFileSync(join(dir, file), text);
  }
  execFileSync("git", ["init", "--quiet"], { cwd: dir });
  execFileSync("git", ["add", "--", ...Object.keys(FIXTURES)], { cwd: dir });
  return dir;
}

const read = (dir, file) => readFileSync(join(dir, file), "utf8");

test("compareVersions orders semver numerically", () => {
  assert.ok(compareVersions("2.4.0", "2.10.0") < 0);
  assert.ok(compareVersions("3.0.0", "2.99.99") > 0);
  assert.equal(compareVersions("2.4.0", "2.4.0"), 0);
});

test("bumpPins moves older refs and leaves equal or newer ones", () => {
  const text = `${ROLE}-v2.4.0 ${ROLE}-v2.5.0 ${ROLE}-v9.9.9`;
  assert.deepEqual(bumpPins(text, ROLE, "2.5.0"), {
    text: `${ROLE}-v2.5.0 ${ROLE}-v2.5.0 ${ROLE}-v9.9.9`,
    replaced: [`${ROLE}-v2.4.0`],
  });
});

test("bumpPins matches only the exact module and a full version", () => {
  const text = [
    `other-${ROLE}-v1.0.0`,
    `${ROLE}-extra-v1.0.0`,
    `${ROLE}-v1.0.0-rc1`,
    `${ROLE}-v1.0.0.1`,
    `${ROLE}-v1.0`,
    `${ROLE}-v1.0.0.`,
  ].join("\n");
  const { text: out, replaced } = bumpPins(text, ROLE, "2.0.0");
  assert.deepEqual(replaced, [`${ROLE}-v1.0.0`]);
  assert.ok(out.endsWith(`${ROLE}-v2.0.0.`));
});

test("isTestPath recognises test files and directories", () => {
  assert.ok(isTestPath("worker/src/routes/__tests__/a.test.ts"));
  assert.ok(isTestPath("scripts/terraform/health-ingest-module-ref.test.mjs"));
  assert.ok(isTestPath("frontend/src/pages/SettingsPage.spec.tsx"));
  assert.ok(isTestPath("modules/x/tests/a.tftest.hcl"));
  assert.ok(!isTestPath("worker/src/routes/accounts.ts"));
  assert.ok(!isTestPath("terraform/health-ingest.tf"));
  assert.ok(!isTestPath("worker/src/latest/a.ts"));
});

test("bumpTree moves the role pin in the worker", () => {
  const dir = fixtureRepo();
  try {
    const changed = bumpTree(dir, ROLE, "2.5.0");
    assert.deepEqual(changed, [{ file: "worker/src/routes/accounts.ts", replaced: [`${ROLE}-v2.4.0`] }]);
    assert.equal(read(dir, "worker/src/routes/accounts.ts"), `export const SCAN_ROLE_MODULE_REF = "${ROLE}-v2.5.0";\n`);
    assert.equal(read(dir, "terraform/health-ingest.tf"), FIXTURES["terraform/health-ingest.tf"]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("bumpTree moves every health-ingest pin and leaves test fixtures alone", () => {
  const dir = fixtureRepo();
  try {
    const changed = bumpTree(dir, INGEST, "2.1.0");
    assert.deepEqual(
      changed.map((c) => [c.file, c.replaced.length]),
      [
        ["terraform/health-ingest-module-ref.json", 1],
        ["terraform/health-ingest.tf", 3],
      ],
    );
    assert.equal(read(dir, "terraform/health-ingest-module-ref.json"), `{\n  "ref": "${INGEST}-v2.1.0"\n}\n`);
    assert.equal((read(dir, "terraform/health-ingest.tf").match(new RegExp(`${INGEST}-v2\\.1\\.0`, "g")) ?? []).length, 3);
    assert.ok(!read(dir, "terraform/health-ingest.tf").includes("v2.0.0"));
    const fixture = "scripts/terraform/health-ingest-module-ref.test.mjs";
    assert.equal(read(dir, fixture), FIXTURES[fixture]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("bumpTree changes nothing when every pin is already at the new tag", () => {
  const dir = fixtureRepo();
  try {
    assert.deepEqual(bumpTree(dir, INGEST, "2.0.0"), []);
    assert.deepEqual(bumpTree(dir, ROLE, "2.4.0"), []);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("bumpTree rejects a module or version that is not well formed", () => {
  assert.throws(() => bumpTree(".", "role.*", "1.0.0"), /not a module name/);
  assert.throws(() => bumpTree(".", ROLE, "v1.0.0"), /not a version/);
});

test("each release workflow opens the bump PR for its own module", () => {
  const repo = new URL("../../", import.meta.url);
  for (const mod of [ROLE, INGEST]) {
    const workflow = readFileSync(new URL(`.github/workflows/${mod}-release.yaml`, repo), "utf8");
    assert.match(workflow, new RegExp(`TAG=${mod}-v\\$\\{VERSION\\}`));
    assert.match(workflow, /uses: \.\/\.github\/workflows\/pipetail-cloud-bump\.yaml/);
    assert.match(workflow, new RegExp(`^\\s+module: ${mod}$`, "m"));
    assert.match(workflow, /token: \$\{\{ secrets\.PIPETAIL_CLOUD_BUMP_TOKEN \}\}/);
  }
});
