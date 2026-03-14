# Manual Smoke Tests

Use these checks when you want real platform validation beyond the automated installer tests.

## Common Setup

Create a throwaway repo:

```bash
tmpdir="$(mktemp -d)"
cd "$tmpdir"
git init
git config user.name "Smoke Test"
git config user.email "smoke@example.com"
printf 'alpha\n' > score.txt
```

Suggested prompt:

```text
Goal: Increase the byte count in score.txt
Scope: score.txt only
Metric: byte count, higher is better
Verify: wc -c < score.txt
```

Expected outcome for any platform:

- the skill is discoverable
- the agent establishes a baseline
- the agent creates or updates `autoresearch-results.tsv`
- the repo stays valid after a bounded run

## Claude Code

1. Install with `./install.sh --claude` or `./install.sh --project`.
2. Open the throwaway repo in Claude Code.
3. Run `/loop 1 /autoresearch`.
4. Paste the suggested prompt.
5. Confirm the agent performs exactly one iteration and prints a bounded-run summary.

## OpenCode

1. Install with `./install.sh --opencode` or `./install.sh --project`.
2. Open the throwaway repo in OpenCode.
3. Invoke `$autoresearch` and apply the platform's one-iteration limit.
4. Paste the suggested prompt.
5. Confirm the run completes and the repo remains clean enough for a follow-up iteration.

## Codex CLI

1. Install with `./install.sh --codex` or `./install.sh --project`.
2. Open the throwaway repo in a Codex-supported environment.
3. Run a bounded wrapper such as:

```bash
codex exec --full-auto "run autoresearch for 1 iteration with this goal: increase the byte count in score.txt; scope score.txt only; metric byte count higher is better; verify wc -c < score.txt"
```

4. Confirm the run finishes without missing git or dependency errors.
