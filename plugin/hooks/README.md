# maipai plugin hooks

Mechanical enforcement for two things the plugin's skills could only ask
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
