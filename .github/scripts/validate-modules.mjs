#!/usr/bin/env node
import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { chmodSync, cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { arch, platform, tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const RELEASES = "https://releases.hashicorp.com/terraform";
const CHECKPOINT = "https://checkpoint-api.hashicorp.com/v1/check/terraform";
const ARCH = { x64: "amd64", arm64: "arm64" };

// The floor is the exact version that is downloaded and run, so the lower
// bound must be a full X.Y.Z.
export function floorOf(versionsTf) {
  const constraint = /^\s*required_version\s*=\s*"([^"]*)"/m.exec(versionsTf);
  if (!constraint) return null;
  const bound = />=\s*(\d+\.\d+\.\d+)(?![\d.-])/.exec(constraint[1]);
  return bound ? bound[1] : null;
}

// `terraform validate` fails with "Provider configuration not present" in a
// module that declares configuration_aliases, because only a caller passes
// those providers in. An empty aliased provider block stands in for the caller.
export function aliasStubs(source) {
  const stubs = [];
  for (const list of source.matchAll(/configuration_aliases\s*=\s*\[([^\]]*)\]/g)) {
    for (const ref of list[1].split(",")) {
      const m = /^\s*([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)\s*$/.exec(ref);
      if (m) stubs.push(`provider "${m[1]}" {\n  alias = "${m[2]}"\n}\n`);
    }
  }
  return stubs.join("\n");
}

async function download(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`GET ${url}: ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

async function latestVersion() {
  return JSON.parse(await download(CHECKPOINT)).current_version;
}

async function install(version, binDir) {
  const dir = join(binDir, version);
  const bin = join(dir, "terraform");
  if (existsSync(bin)) return bin;

  const goarch = ARCH[arch()];
  if (!goarch) throw new Error(`unsupported architecture: ${arch()}`);
  const name = `terraform_${version}_${platform()}_${goarch}.zip`;
  const zip = await download(`${RELEASES}/${version}/${name}`);
  const sums = (await download(`${RELEASES}/${version}/terraform_${version}_SHA256SUMS`)).toString();
  const want = sums.split("\n").find((l) => l.endsWith(`  ${name}`))?.split(/\s+/)[0];
  const got = createHash("sha256").update(zip).digest("hex");
  if (!want || want !== got) throw new Error(`${name}: sha256 is ${got}, the release lists ${want ?? "nothing"}`);

  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, name), zip);
  execFileSync("unzip", ["-oq", join(dir, name), "terraform", "-d", dir]);
  chmodSync(bin, 0o755);
  return bin;
}

// A copy keeps .terraform and the provider stubs out of the checkout. tests/
// stays behind: Terraform reads it only in a root module, so a consumer never
// loads it, and older releases cannot parse the mock providers in it.
function copyModule(src, dest) {
  cpSync(src, dest, {
    recursive: true,
    filter: (path) => !/\/(\.terraform|tests)$/.test(path) && !path.endsWith(".terraform.lock.hcl"),
  });
  const source = readdirSync(dest)
    .filter((f) => f.endsWith(".tf"))
    .map((f) => readFileSync(join(dest, f), "utf8"))
    .join("\n");
  const stubs = aliasStubs(source);
  if (stubs) writeFileSync(join(dest, "validate_provider_stubs.tf"), stubs);
}

function terraform(bin, dir, args, env) {
  const r = spawnSync(bin, [`-chdir=${dir}`, ...args, "-no-color"], { env, encoding: "utf8" });
  process.stdout.write(r.stdout ?? "");
  process.stdout.write(r.stderr ?? "");
  return r.status === 0;
}

async function main() {
  const mode = process.argv[2];
  if (mode !== "floor" && mode !== "latest") {
    console.error("usage: validate-modules.mjs floor|latest");
    process.exit(2);
  }

  const work = mkdtempSync(join(tmpdir(), "validate-modules-"));
  const env = {
    ...process.env,
    TF_IN_AUTOMATION: "1",
    // Modules commit no lock file, and without this Terraform 1.4 and newer
    // download every provider again for each module instead of using the cache.
    TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE: "true",
  };
  // Terraform fails on a cache directory that does not exist.
  if (env.TF_PLUGIN_CACHE_DIR) mkdirSync(env.TF_PLUGIN_CACHE_DIR, { recursive: true });

  const latest = mode === "latest" ? await latestVersion() : null;
  const modules = readdirSync("modules", { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();
  if (modules.length === 0) throw new Error("no directory under modules/");

  const failed = [];
  for (const mod of modules) {
    const versionsTf = join("modules", mod, "versions.tf");
    const floor = existsSync(versionsTf) ? floorOf(readFileSync(versionsTf, "utf8")) : null;
    if (!floor) {
      console.log(`::error file=${versionsTf}::${versionsTf} must set required_version with a ">= X.Y.Z" lower bound.`);
      failed.push(mod);
      continue;
    }

    const version = latest ?? floor;
    console.log(`::group::${mod} with Terraform ${version}`);
    const bin = await install(version, join(work, "bin"));
    const dir = join(work, "modules", mod);
    copyModule(join("modules", mod), dir);
    const ok = terraform(bin, dir, ["init", "-backend=false", "-input=false"], env) && terraform(bin, dir, ["validate"], env);
    console.log("::endgroup::");
    if (!ok) {
      console.log(`::error file=${versionsTf}::modules/${mod} does not validate with Terraform ${version}.`);
      failed.push(mod);
    }
  }

  rmSync(work, { recursive: true, force: true });
  if (failed.length) {
    console.log(`::error::${mode} validation failed in: ${failed.join(", ")}`);
    process.exit(1);
  }
  console.log(`All ${modules.length} modules validate (${mode}).`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
