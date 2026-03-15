# Autoresearch

Cross-platform autoresearch skill for **Claude Code**, **OpenCode**, and **Codex CLI**.

Based on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch): constrain scope, define a mechanical metric, iterate autonomously, keep improvements, and discard failures.

## Repository Layout

```text
autoresearch-anywhere/
├── skills/autoresearch/
│   ├── SKILL.md
│   └── references/
│       ├── autonomous-loop-protocol.md
│       ├── core-principles.md
│       └── results-logging.md
├── tests/
│   ├── test.sh
│   └── manual-smoke.md
├── .github/
│   ├── workflows/ci.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── pull_request_template.md
├── install.sh
├── CONTRIBUTING.md
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Compatibility

| Platform | Skill location | Global install dir | Typical invoke |
|----------|----------------|--------------------|----------------|
| Claude Code | `.agents/skills/` or `.claude/skills/` | `~/.claude/skills/` | `/autoresearch` |
| OpenCode | `.agents/skills/`, `.claude/skills/`, or `.opencode/skills/` | `~/.config/opencode/skills/` | `$autoresearch` |
| Codex CLI | `.agents/skills/` or `.codex/skills/` | `~/.codex/skills/` | `$autoresearch` |

## Quick Start

### Install

```bash
# auto-detect installed CLIs and install for each
./install.sh

# install for one platform
./install.sh --claude
./install.sh --opencode
./install.sh --codex

# install for all supported platforms
./install.sh --all

# install into the current project
./install.sh --project
```

### Invoke

| Platform | Example |
|----------|---------|
| Claude Code | `/autoresearch` |
| Claude Code bounded | `/loop 25 /autoresearch` |
| OpenCode | `$autoresearch` |
| Codex CLI | `$autoresearch` |

Example goal:

```text
Goal: Increase test coverage from 72% to 90%
Scope: src/**/*.ts, tests/**/*.ts
Metric: coverage percent, higher is better
Verify: npm test -- --coverage
```

Permissions for autonomous operation are configured automatically during install. Use `--full-auto` to allow all bash commands in sandboxed environments:

```bash
./install.sh --claude --full-auto
```

## How the Skill Works

1. Read the full in-scope context.
2. Establish a baseline metric.
3. Make one focused change.
4. Commit before verification.
5. Keep improvements and discard failures.
6. Log each iteration in `autoresearch-results.tsv`.
7. Repeat until interrupted or the bounded limit is reached.

Detailed loop rules live in [`skills/autoresearch/references/autonomous-loop-protocol.md`](./skills/autoresearch/references/autonomous-loop-protocol.md).

## Platform Notes

### Claude Code

Use `/autoresearch` for an open-ended run or `/loop N /autoresearch` for a bounded run.

### OpenCode

Use the skill by name or natural language, and use the platform's own iteration controls if you need a fixed number of cycles.

### Codex CLI

Use the skill by name or wrap execution in a bounded command such as:

```bash
codex exec --full-auto "run autoresearch for 10 iterations"
```

If Codex is running in a sandbox or container, make sure:

- the working directory is a git repository
- the verification command is available in the container
- any required runtime dependencies are already installed

## Permissions

The installer automatically configures tool permissions for autonomous operation. No extra flags are needed — every `./install.sh --claude` sets up the required permissions.

### What gets configured

**Claude Code** (`~/.claude/settings.json` or `.claude/settings.json` for `--project`):

```json
{
  "permissions": {
    "allow": [
      "Bash(git add *)",
      "Bash(git commit *)",
      "Bash(git revert *)",
      "Bash(git log *)",
      "Bash(git diff *)",
      "Bash(git status *)",
      "Edit",
      "Write"
    ]
  }
}
```

**Codex CLI** (`~/.codex/config.toml`):

```toml
approval_policy = "on-request"
```

### Full-auto mode

For sandboxed or trusted environments where you want all bash commands allowed:

```bash
./install.sh --claude --full-auto
```

This sets `"Bash"` (unrestricted) instead of git-specific rules.

### Adding project-specific verification commands

If your verification command (e.g., `npm test`) also needs permission, add it to `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm test *)"
    ]
  }
}
```

Or re-run the installer with `--full-auto` to allow all bash commands.

## Testing

Run the automated test suite from the repo root:

```bash
./tests/test.sh
```

It covers:

- repo sanity checks
- `install.sh` syntax and explicit flag behavior
- auto-detect install behavior with stubbed CLIs
- failure behavior when no supported CLI is present
- smoke workspace bootstrap in a throwaway git repo

For real platform validation in Claude Code, OpenCode, or Codex CLI, use the manual steps in [`tests/manual-smoke.md`](./tests/manual-smoke.md).

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on reporting issues, submitting PRs, and running tests.
