# maipai plugin hooks

Mechanical enforcement for things the plugin's skills could only ask
nicely for before. Hooks load at session start; editing these requires a
Claude Code restart to take effect (`claude --debug` to confirm they
loaded, `/hooks` to review what is active).

## Git hygiene

- **`block-blind-staging.sh`** (PreToolUse, `Bash`): denies `git add -A`,
  `git add --all`, a bare `git add .`, and any `git commit` with a short
  flag cluster containing `-a` (so `-am`, `-avm`, and friends, not just a
  bare `-a`) unless `git status` or `git diff --stat` ran in this repo
  within the last 15 minutes. This is a soft gate, not a ban: the org rule
  (`CLAUDE.md` > Git workflow) is to stage specific files after reviewing
  what is actually there, not to never use these commands. Denying comes
  with the exact next step (run status, then retry), so it never dead-ends
  a session.
- **`mark-git-status-checked.sh`** (PostToolUse, `Bash`): the other half.
  Stamps a flag file at `<git-dir>/maipai-status-checked` (inside `.git/`,
  never committed) whenever `git status` or `git diff --stat` runs, so the
  PreToolUse hook has something to check the freshness of. Never blocks.

Both use `git rev-parse --git-dir` from the command's own `cwd`, so they
work correctly from a worktree, not just the main checkout.

## Review before committing code

Jesse's rule (2026-09-04): "I have to remember to tell you that" was the
tell that self-discipline within one session doesn't survive a fresh one.
This is the same mechanical pattern as git hygiene above, applied to code
review instead of staging.

- **`require-review-before-commit.sh`** (PreToolUse, `Bash`): denies a
  `git commit` whose committed files include anything beyond `*.md`,
  `LICENSE`, or `NOTICE` unless the `code-review` skill has run in this
  repo within the last 30 minutes. Checks `--cached` plus, when the
  command carries a `-a`/`--all`/an `-a`-flag-cluster (`-am`, `-av`...),
  unstaged tracked changes too: a first cut checked only `--cached`, so a
  bare `git commit -am` with nothing pre-staged sailed through with an
  empty diff every time, caught by a code review of this hook itself
  (2026-09-04) before it ever shipped. `--amend` is exempt (it repeats
  history rather than adding unreviewed work). Soft gate, same shape as
  `block-blind-staging.sh`: the denial names the exact next step.
- **`mark-review-checked.sh`** (PostToolUse, `Skill`): stamps
  `<git-dir>/maipai-review-checked` whenever the `code-review` skill is
  invoked (`tool_input.skill == "code-review"`). Originally matched
  `ReportFindings` instead; that same first review caught this too: when
  `code-review` runs as a forked/background agent (the normal way a
  session invokes it), its own loaded instructions explicitly forbid
  calling `ReportFindings`, so the flag would never have been stamped and
  the gate would have blocked every code commit forever. Stamping at
  invocation, not at "findings read and addressed", is a real limit: there
  is no tool call available to hook that fires only once a multi-agent
  review's parallel findings have all landed (those arrive as
  task-notifications, not tool calls). Same honesty level as
  `mark-git-status-checked.sh`. Never blocks.

This does not cover `catalog`'s community-PR path (that CI, not this
hook, is the review gate there) or the cloud `ultra` review (separately
billed and user-triggered, not something a session runs on its own).

## Session-start context

- **`session-start-context.sh`** (SessionStart, all events): if the
  session opens inside a git repo, prints the branch, ahead/behind count
  against its upstream (only when nonzero), the dirty file count, and, if
  the repo has one, how many open `- [ ]` items sit in `docs/dev.md`. The
  point is surfacing leftover state from a prior session (an unpushed
  commit, uncommitted work, an open review-queue item) before it gets
  discovered mid-task instead of at the start.

## Why command hooks, not prompt hooks

Every check here is a fast, deterministic, boolean question (does this
command match a pattern, is a timestamp recent, is a checkbox unchecked),
exactly the case where a fixed script is faster and more predictable than
an LLM judgment call. Reach for a prompt-based hook only for something that
genuinely needs contextual reasoning to answer.
