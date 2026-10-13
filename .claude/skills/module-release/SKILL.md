---
name: module-release
description: Use when writing or fixing a PR title in this repo, when the "Check PR title" check (pr-title.yaml) fails, when asked which version a change under modules/ will release, why a module was or was not tagged, how to pin a module with ?ref=, or when changing pipetail-cloud-role, pipetail-cloud-health-ingest or src/aws-events-to-slack.
user-invocable: true
---

# module-release

Every module under `modules/` is released on its own, as a GitHub release and tag named
`<module>-vX.Y.Z`. Nobody picks the version: it comes from the squash-merged PR title. Never edit a
version by hand, except in the three modules listed under "Modules with their own release".

## The title decides the bump

`module-release.yaml` runs on every push to `master` that touches `modules/**`. For each module
changed since the previous push it reads the subjects and bodies of the commits that touched it and
takes the largest bump:

| Commit | Bump |
|---|---|
| `feat(<module>): ...` | minor |
| `fix(<module>): ...`, and any other type | patch |
| `!` after the type or scope, or a `BREAKING CHANGE:` footer | major |

The commit subjects become the release notes. A module with no tag yet is released as `v1.0.0`.

Because the repo squash-merges, the PR title is the commit subject. Write it for the module's
consumers: `fix(eks): pin the addon versions`, not `fix: address review`.

## What the title check enforces

`pr-title.yaml` runs on every title edit and push and fails when:

- the title is not a Conventional Commit (`type(scope): subject`, or `type: subject`)
- the PR changes exactly one module and the scope is neither that module's name nor `deps`
- the PR changes two or more modules and the scope names one of them

A PR that changes two modules should be split, one PR per module, so each release carries only its
own changes. If it cannot be split, use a scope that is not a module name; each module then gets the
bump from that one title.

## What is not released

Files that do not change what a consumer gets are ignored when deciding which modules changed, both
by the title check and by the release:

- any `.md` file inside a module
- anything under a module's `tests/` directory

So a PR that only adds tests or docs to `modules/kms` cuts no release, and its scope is free.

## Modules with their own release

`module-release.yaml` skips these three. Each has its own workflow that releases whatever version is
committed and fails on `master` if the code changed but the version did not:

| What changed | Bump by hand in the same PR | Workflow |
|---|---|---|
| a `.tf` file under `modules/pipetail-cloud-role/` | `modules/pipetail-cloud-role/VERSION` | `pipetail-cloud-role-release.yaml` |
| a `.tf` file under `modules/pipetail-cloud-health-ingest/` | `modules/pipetail-cloud-health-ingest/VERSION` | `pipetail-cloud-health-ingest-release.yaml` |
| a `.mjs`, `.js` or `.json` file under `src/aws-events-to-slack/` | `version` in `src/aws-events-to-slack/package.json` | `lambda-release.yaml` |

The tag is `<name>-v<version>` for these too. Follow semver for the bump you pick.

`modules/aws-events-to-slack/` is released by `lambda-release.yaml`, which runs only when
`src/aws-events-to-slack/` changes. A PR that changes only the module's `.tf` files cuts no release;
bump `package.json` in the same PR to ship it.

## Consuming a release

Pin the module's tag, never a branch:

```hcl
module "github_oidc" {
  source = "github.com/pipetail/terraform//modules/github-oidc?ref=github-oidc-v1.0.0"
}
```

List a module's releases with `gh release list --repo pipetail/terraform | grep '^<module>-v'`.

The examples in this repo call modules by relative path (`source = "../../modules/<name>"`), so they
always use the code on the branch, not a release.
