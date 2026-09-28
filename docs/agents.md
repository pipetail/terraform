# Agent skills and reviewers

`.claude/` holds instructions for coding agents working in this repo. They describe how this repo's
CI and release process work, so an agent follows the same rules a reviewer would check.

## What is there

Skills, in `.claude/skills/<name>/SKILL.md`:

| Skill | Use it when |
|---|---|
| `tf-migrations` | adopting, renaming, re-keying, retyping or dropping a resource through `migrations.tf` |
| `tf-lock` | a provider version changes, or the lock file check fails |
| `check` | before opening a PR, to run what CI runs |
| `module-release` | writing a PR title, or working out which version a module change releases |

Agents, in `.claude/agents/<name>.md`:

| Agent | What it does |
|---|---|
| `plan-reviewer` | reads the plan CI posts on a PR and reports destroys, replacements and out-of-scope changes. Read-only. |
| `module-impact` | for a change under `modules/<name>`, lists the examples that call it, the release the PR title will cut, and the tests that cover the change |

## Using them

Each file is plain Markdown with a short YAML header (`name`, `description`). Claude Code picks them
up from `.claude/` without any setup: skills can be run as `/<name>`, and agents are offered by name.

Any other agent can use them as ordinary instructions: point it at the file ("follow
`.claude/skills/check/SKILL.md`"). Nothing in them depends on a particular tool.

`.claude/.gitignore` admits only these files, so local settings under `.claude/` stay out of git.

## Provider and registry docs

The skills cover this repo's rules. For facts about a provider or a registry module (a resource's
arguments, an import ID format, a registry module's inputs), pair them with HashiCorp's
[terraform-mcp-server](https://github.com/hashicorp/terraform-mcp-server). It runs in Docker and
answers from the public Terraform Registry. Its default `registry` tools need no token; the HCP
Terraform and Terraform Enterprise tools need `TFE_TOKEN` and `TFE_ADDRESS`.

For Claude Code, a minimal `.mcp.json` in the repo root:

```json
{
  "mcpServers": {
    "terraform": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "hashicorp/terraform-mcp-server:1.3.0"]
    }
  }
}
```

Or register it for your user instead of the project:

```bash
claude mcp add terraform -s user -t stdio -- docker run -i --rm hashicorp/terraform-mcp-server:1.3.0
```

The server's README has the configuration for other MCP clients.
