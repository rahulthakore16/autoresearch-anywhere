# Autonomous Loop Protocol

Detailed protocol for the autoresearch iteration loop. `SKILL.md` has the summary; this file has the full rules.

## Loop Modes

Autoresearch supports two loop modes:

- **Unbounded:** loop until manually interrupted
- **Bounded:** loop exactly `N` times through a platform-native loop controller or external wrapper

When bounded, track `current_iteration` against `max_iterations`. After the final iteration, print a summary and stop.

## Phase 1: Review

Before each iteration:

```text
1. Read the current state of in-scope files
2. Read the last 10-20 entries from the results log
3. Read recent git history
4. Identify what worked, what failed, and what remains untried
5. If bounded, check current_iteration versus max_iterations
```

Always re-read the current state after discards or crash recovery. Never rely on stale assumptions.

## Phase 2: Ideate

Pick the next change in this priority order:

1. Fix unresolved crashes or breakages from the previous iteration.
2. Exploit recent successful directions.
3. Explore untried approaches.
4. Combine near-misses when there is a clear rationale.
5. Simplify while preserving or improving the metric.
6. Try a more radical change when the local search is stalled.

Avoid repeating an experiment that was already discarded unless new evidence changes the hypothesis.

## Phase 3: Modify

- Make one focused change.
- Be able to describe the change in one sentence before making it.
- Keep scope tightly aligned to the agreed objective.

## Phase 4: Commit

Commit before verification so rollback is deterministic.

```bash
git add <changed-files>
git commit -m "experiment: <one-sentence description>"
```

## Phase 5: Verify

- Run the agreed verification command.
- Capture output.
- Parse the metric mechanically.
- If verification hangs or takes far longer than normal, treat it as a crash.

## Phase 6: Decide

```text
IF metric improved:
  keep the commit
ELIF metric stayed the same or got worse:
  discard the commit
ELIF the iteration crashed:
  attempt up to 3 fixes, then discard if recovery fails
```

Rollback commands should return the tree to the last known-good state cleanly.

**Simplicity override:** if the metric gain is negligible but complexity rises materially, discard. If the metric is unchanged and the solution is clearly simpler, keep.

## Phase 7: Log

Append every baseline, keep, discard, and crash outcome to the TSV log described in `results-logging.md`.

## Phase 8: Repeat

### Unbounded Mode

Repeat until manually interrupted. Do not stop to ask for permission to continue unless there is a true blocker.

### Bounded Mode

```text
IF current_iteration < max_iterations:
  continue
ELIF goal achieved:
  print final summary and stop
ELSE:
  print final summary and stop
```

**Final summary format:**

```text
=== Autoresearch Complete (N/N iterations) ===
Baseline: {baseline} -> Final: {current} ({delta})
Keeps: X | Discards: Y | Crashes: Z
Best iteration: #{n} - {description}
```

## When Stuck

If more than five iterations in a row are discarded:

1. Re-read all in-scope files.
2. Re-read the original goal.
3. Review the full results log for patterns.
4. Combine successful ingredients from earlier iterations.
5. Try the opposite of the current strategy.
6. Try a more structural change.

## Crash Recovery

- Syntax error: fix immediately and continue within the same iteration.
- Runtime error: attempt up to three fixes, then discard.
- Resource exhaustion: discard and try a smaller variant later.
- Infinite loop or hang: kill, discard, and avoid that exact path.
- Missing dependency or permissions: log the blocker and switch approaches if possible.

## Communication

- Do not ask "should I keep going?" unless blocked by something the user must resolve.
- Do not write long summaries after every iteration.
- Emit brief progress updates periodically during long bounded runs.
- Always print a final summary when a bounded run completes.
