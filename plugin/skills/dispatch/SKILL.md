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

## 4. Run Codex in an owned tmux session

```
tmux new -d -s <repo>-<worktree>-codex -c <worktree> "codex exec 'Read <brief> and do it exactly' > <log> 2>&1; echo EXIT=\$? >> <log>"
```

- Use `codex exec` (no `--full-auto`, no approval prompts). Add `--add-dir <dir>` for each outside directory it must write.
- Never type into a running tmux pane: the Enter key is swallowed. Wait on the log instead:
  `until grep -q '^EXIT=' <log>; do sleep 20; done` as a background command, so you are notified.
- Codex can die on "prompt flagged" (EXIT=1). Check the worktree for partial work before re-dispatching.

## 5. Verify, then land

1. Read the diff yourself once. Run `bash scripts/wt.sh check` (tier-aware) in the worktree.
2. Anything wrong: fix it or re-brief; do not land.
3. `bash scripts/wt.sh land`, then `bash scripts/wt.sh done`.
4. `tmux kill-session -t <repo>-<worktree>-codex` and delete the brief and log. Confirm `git worktree list` no longer shows it.

## 6. Done means clean

No leftover worktree, branch, tmux session, lock or claim. Report the commit sha, the checks run with results, and anything
unfinished, then the STATE line.
