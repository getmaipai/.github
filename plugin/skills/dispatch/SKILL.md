---
name: dispatch
description: Hand one decided, verifiable item to Codex in its own worktree and land it, with no lane locks, claims or leftover tmux sessions. Use when Jesse says to dispatch, delegate or hand work to Codex or a subagent. Replaces the coordinate skill.
---

# Dispatch one item

One item = one worktree = one Codex run = one landing. No lanes, locks or claims.

## 1. Decide the route

- Decided, verifiable work (clear acceptance, tests can prove it): Codex first.
- Needs judgment or design: a Claude subagent (Sonnet default, Opus for one bounded question, Haiku to gather evidence).
- Never Fable unless Jesse says. At most one Haiku, one Sonnet, one Opus at a time.

## 2. Write a complete brief first

Save it as `data-scratch/briefs/<slug>.md` in the main checkout. It must hold: goal, files to touch, files not to touch,
acceptance commands with expected output, the commit message, and "land with `scripts/wt.sh land`". An unfinished brief wastes
the run; do not dispatch until it is complete.

## 3. Start the worktree

```
bash scripts/wt.sh start <slug>
```

Run it from a checkout that has `scripts/wt.sh` (origin/main, not a stale clone, and not from inside `../wt/`). It prints the
worktree path, branch and session name. Export `MAIPAI_COMMONS_DIR`, `MAIPAI_STANDARDS_DIR` and `MAIPAI_WT_SESSION=<name>` for runs
inside the worktree.

## 4. Run Codex with the launcher (never by hand)

```
bash scripts/wt.sh run codex data-scratch/briefs/<slug>.md      # run THIS as a background command
```

- One command launches and reports. It starts the owned tmux session, runs `codex exec` on the brief (no `--full-auto`, no
  approvals), logs to `data-scratch/runs/<session>.log` (always ends `EXIT=<code>`), blocks until the run ends, then prints
  DONE, FAILED, DIED (tmux gone, no `EXIT=`) or TIMEOUT (default 3600 s), the log tail and the newest report's gate lines.
  Started in the background, the harness wakes you the moment it ends, so a finish cannot go unseen.
- It records the owning Claude session and `runState` in `data-scratch/sessions/<name>.json` for status panes.
- `--detach` returns at once; then you must run `bash scripts/wt.sh wait <session>` in the background yourself.
- Never type into a running pane (the Enter is swallowed); a correction is a new `run`. Add `MAIPAI_CODEX_BIN` only in tests.
- Codex can die on "prompt flagged" (FAILED, exit 1). Check the worktree for partial work before re-dispatching.

## 5. Verify, then land

1. Read the diff yourself once. Run `bash scripts/wt.sh check` (tier-aware) in the worktree.
2. Anything wrong: fix it or re-brief; do not land.
3. `bash scripts/wt.sh land`, then `bash scripts/wt.sh done`.
4. `tmux kill-session -t <repo>-<worktree>-codex` and delete the brief and log. Confirm `git worktree list` no longer shows it.

## 6. Done means clean

No leftover worktree, branch, tmux session, lock or claim. Report the commit sha, the checks run with results, and anything
unfinished, then the STATE line.
