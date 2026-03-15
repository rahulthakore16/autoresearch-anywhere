---
name: autoresearch
description: Autonomous goal-directed iteration for Claude Code, OpenCode, and Codex CLI. Use when the user wants the agent to work autonomously, iterate until done, keep improving, or run repeated measured experiments.
version: 2.1.0
---

# Autoresearch

Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch). Apply constraint-driven autonomous iteration to any task with a mechanical metric.

**Core idea:** Modify -> Verify -> Keep or discard -> Repeat.

## When to Activate

- User invokes the autoresearch skill explicitly, such as `$autoresearch` or `/autoresearch`
- User says "work autonomously", "iterate until done", "keep improving", or "run repeated experiments"
- The task has a measurable outcome and benefits from repeated focused changes

## Loop Modes

Autoresearch supports two modes:

- **Unbounded:** Keep iterating until the user interrupts the agent
- **Bounded:** Stop after a fixed number of iterations

Use the platform's native loop controls or a shell wrapper to bound execution:

- **Claude Code:** `/loop N /autoresearch`
- **OpenCode:** use the platform's max-iteration setting or wrap invocations in a shell loop
- **Codex CLI:** use a wrapper such as `codex exec --full-auto "run autoresearch for N iterations"`

If running in a containerized or sandboxed environment, ensure `.git` is initialized and the verification commands are available before starting the loop.

## Setup Phase

1. Read all in-scope files before changing anything.
2. Define the goal in terms of a mechanical metric.
3. Define scope constraints: writable files, read-only files, and any forbidden operations.
4. Create a results log using `references/results-logging.md`.
5. Establish the baseline by running verification on the current state and recording iteration `0`.
6. Confirm the setup with the user, then start iterating.

## The Loop

Read `references/autonomous-loop-protocol.md` before starting the first iteration.

```text
LOOP:
  1. Review current state, git history, and recent log entries
  2. Pick the next focused change
  3. Make one atomic modification
  4. Commit before verification
  5. Run the mechanical verification command
  6. Keep, discard, or recover from a crash
  7. Log the result
  8. Repeat until interrupted or the bounded limit is reached
```

## Critical Rules

1. Read before write.
2. Change one thing per iteration.
3. Use only mechanical verification.
4. Revert failed experiments automatically.
5. Prefer simpler solutions when results are equal.
6. Use git history as memory for what worked and what failed.
7. Do not ask whether to continue unless the user has to resolve a real blocker.

## Permissions & Autonomy

The autonomous loop requires uninterrupted tool access. The installer configures permissions automatically, but if a permission prompt blocks the loop, inform the user of the fix instead of asking "should I continue?".

**Required tool access per platform:**

| Platform | Required permissions |
|----------|---------------------|
| Claude Code | `Bash(git add *)`, `Bash(git commit *)`, `Bash(git revert *)`, `Bash(git log *)`, `Bash(git diff *)`, `Bash(git status *)`, `Edit`, `Write` |
| Codex CLI | `approval_policy = "on-request"` in `~/.codex/config.toml` |
| OpenCode | No special configuration needed |

If a permission prompt interrupts the loop:
1. Do **not** ask the user "should I continue?" — that defeats the purpose of autonomy.
2. Instead, inform the user: "Permission prompts are blocking autonomous operation. Run `./install.sh --<platform>` to configure permissions, or see the README for manual setup."
3. Then proceed with the current iteration if possible.

Permissions are configured automatically by `install.sh`. For sandboxed or trusted environments, use `--full-auto` to allow all bash commands.

## References

- Read `references/autonomous-loop-protocol.md` for the detailed loop procedure.
- Read `references/core-principles.md` for the seven general principles behind the workflow.
- Read `references/results-logging.md` for the expected TSV log format.

## Domain Adaptation

| Domain | Example Metric | Example Verify Command |
|--------|----------------|------------------------|
| Backend code | tests pass, coverage | `npm test -- --coverage` |
| Frontend UI | lighthouse score | `npx lighthouse ...` |
| Performance | latency, throughput | `npm run bench` |
| Content | readability, word count | custom script |
| Refactoring | tests pass, LOC reduced | `npm test && wc -l ...` |

Pick the fastest mechanical verification that still measures real progress.
