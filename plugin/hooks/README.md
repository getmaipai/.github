# maipai plugin hooks

Mechanical enforcement for things the plugin's skills could only ask
nicely for before. Hooks load at session start; editing these requires a
Claude Code restart to take effect (`claude --debug` to confirm they
loaded, `/hooks` to review what is active).

## Git hygiene (retired 2026-10-15)

`block-blind-staging.sh`, `mark-git-status-checked.sh` and
`block-wholesale-shared-docs.sh` guarded shared checkouts. Sessions now work
one per worktree, so the three hooks and their scripts are deleted.

## Main checkout guard

**`guard-main-checkout.sh`** (PreToolUse, `Bash`): MAIN-CHECKOUT-01. Denies `git rebase|reset|checkout|switch|merge|pull`,
`worktree add`, `remote set-url` and force pushes when the target (`git -C <dir>` or the cwd) is a repo's main checkout, so only
`scripts/wt.sh` changes it. Escape for an owner-approved change: `MAIPAI_ALLOW_MAIN_CHECKOUT=1` in the command. Test:
`bash plugin/hooks/tests/guard-main-checkout.test.sh`.

## Review before committing code

Jesse's rule (2026-09-04): "I have to remember to tell you that" was the
tell that self-discipline within one session doesn't survive a fresh one.
This is the same mechanical pattern as the gate below, applied to code
review.

- **`require-review-before-commit.sh`** (PreToolUse, `Bash`): since
  2026-10-15 it applies to T2 paths only (the risky-surface list in the org
  CLAUDE.md "Checks before landing" table). In a repo with `scripts/wt.sh`
  it runs `bash scripts/wt.sh tier <files>` and requires a review only when
  that prints T2. A repo without `wt.sh` keeps the older rule: it denies a
  `git commit` whose committed files include anything beyond `*.md`,
  `LICENSE`, or `NOTICE` unless the `code-review` skill has run in this
  repo within the last 4 hours. Checks `--cached` plus, when the
  command carries a `-a`/`--all`/an `-a`-flag-cluster (`-am`, `-av`...),
  unstaged tracked changes too: a first cut checked only `--cached`, so a
  bare `git commit -am` with nothing pre-staged sailed through with an
  empty diff every time, caught by a code review of this hook itself
  (2026-09-04) before it ever shipped. `--amend` is exempt (it repeats
  history rather than adding unreviewed work). Soft gate: the denial names the exact next step.
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
  task-notifications, not tool calls). Never blocks.

This does not cover `catalog`'s community-PR path (that CI, not this
hook, is the review gate there) or the cloud `ultra` review (separately
billed and user-triggered, not something a session runs on its own).

## The gate before committing (GATE-HOOK-01, 2026-09-23)

Same mechanical shape as the review gate above, for `scripts/check.sh`
instead of the `code-review` skill: "it must pass before any commit"
(`docs/VERIFICATION.md`) doesn't survive a session forgetting
to run it any better than "review before committing" did.

- **`require-gate-before-commit.sh`** (PreToolUse, `Bash`): denies a
  `git commit` unless `scripts/check.sh` is on record for this repo, in
  a scope that actually covers the files about to be committed, within
  the last 4 hours. Detects a commit more broadly than
  a repo with `scripts/land.sh` skips the stamp for T1 commits; T2 is unchanged.
  `require-review-before-commit.sh` does (`git -C <path> commit`,
  `git --no-pager commit`, `git --git-dir=<path> commit` - not just a
  bare `git commit`, and a review found all three bypassed that hook's
  own narrower, immediate-adjacency pattern too, a pre-existing gap not
  fixed here since it's a different hook). Every regex here runs
  against the command with quoted spans (a commit `-m "message"`)
  emptied out first, not the raw text - a plain-language commit message
  is exactly the kind of free text that can contain "--amend" or
  "-all" as ordinary words rather than real flags, and a first version
  of both the `--amend` exemption and the `-a`/`--all` detection below
  (anywhere after `commit`, not just immediately following it - `git
  commit -m "msg" -a`, a real ordering) matched those words inside the
  message text too, either wrongly exempting a real commit from the
  gate or wrongly pulling in unstaged files it didn't need to.

  Scope-aware (GATE-SCOPE-01): a `frontend`-scoped run doesn't satisfy a
  commit touching `backend/`. Where the target repo has its own
  `scripts/gateScope.ts` (home, as of GATE-SCOPE-01), this hook feeds
  it exactly the files this commit is about to create (`--cached`, plus
  the working tree too when `-a`/`--all` is in play) - not a fresh
  working-tree-vs-merge-base diff mirroring `check.sh`'s own
  `compute_scope()`, which a first version of this hook used: in a
  shared checkout (the org's own workflow explicitly allows one), that
  would also pick up a second session's own unrelated, still-
  uncommitted edits sitting in the same working tree, and could inflate
  the required scope past what this specific commit touches, denying a
  commit that was genuinely, fully covered by the stamped run. What
  `check.sh` itself scopes a *gate run* to and what this hook scopes a
  *specific commit* to are different questions. The frontend-imports-
  backend escalation this feeds `gateScope.ts` is hardcoded to home's
  own `@maipai/home-backend` package name; a different repo's own
  future `gateScope.ts`, with a differently-named backend package,
  would need this hook's own regex updated too, not something it picks
  up for free. Where a repo has no `gateScope.ts` yet, the only two
  scopes every repo's `check.sh` actually supports today are `docs` and
  `full` (the org rule's own `--docs` contract), so the fallback is a
  doc-only-files test matching `gateScope.ts`'s own narrow root-docs
  rule (root-level `README.md`/`CHANGELOG.md`/`AGENTS.md`/`CLAUDE.md`/
  `LICENSE`/`NOTICE`, or `docs/` other than `docs/api/`) - not the
  broader "any `*.md` anywhere" `require-review-before-commit.sh` uses
  for its own, differently-scoped exemption, since a bundled package's
  own `README.md` is that package's content, never a doc. Unlike that
  hook, though, a doc-only commit here is never fully exempt, only
  exempt from needing more than the fast `--docs` gate (the org rule
  names that path as its own required minimum, never a full waiver).
  `full` always satisfies any commit, in every repo.

  Stamps are read per session (`<git-dir>/maipai-gate-checked-
  <session_id>`, the hook payload's own `session_id`): two sessions in
  the same shared checkout (the org's own git workflow explicitly
  allows this) running different-scoped gates at the same time would
  otherwise silently overwrite each other's still-valid stamp with a
  narrower one, denying a commit that was genuinely covered a moment
  earlier.

  **The batch allowance (GATE-HOOK-02):** the org's own "gate per
  push, not per commit" rule needs several commits to land off one
  gate run, so a scope-covering, recent-enough stamp is not itself the
  whole check - every file about to be committed also has to still
  carry exactly the content that run tested. Two `git commit` calls
  from the same tree, unchanged since the stamp, both go through on
  it; an edit to a tracked file after the stamp (even a file the gate
  already saw dirty, edited again) fails the next commit and names the
  file. `mark-gate-checked.sh` records `HEAD` at stamp time plus every
  dirty tracked file's own working-tree blob hash (`git hash-object`,
  not `git diff --raw`'s new-blob-hash column - that field reads all
  zeros for an uncommitted working-tree change, found live, since a
  raw diff only ever computes a real hash for a tree or the index); a
  path with no entry was clean (matched `HEAD`) at stamp time, so
  `require-gate-before-commit.sh` checks it against `HEAD`'s own blob
  there instead. Proven in `standards/tests/ts/gateHook.test.ts`, both
  scripts spawned for real against a scratch git repo.
- **`mark-gate-checked.sh`** (PostToolUse, `Bash`): stamps
  `<git-dir>/maipai-gate-checked-<session_id>` with the scope the run
  actually covered, read from `check.sh`'s own first output line
  (`== scope: <word> (<why>)`, GATE-SCOPE-01) - a plain word, not a
  boolean, since the requiring hook needs to know which scope this was,
  not just that something ran. Matches `bash scripts/check.sh`,
  `./scripts/check.sh`, a bare `scripts/check.sh`, or any of those with
  a real directory prefix (`bash /Users/.../home/scripts/check.sh` - a
  narrower, no-prefix-allowed version of this regex never matched an
  absolute-path invocation at all, so a genuinely passing gate run went
  unstamped), but not `cat scripts/check.sh` or a `grep` over it (the
  command's own leading word has to be empty, a separator, or
  `bash`/`sh`/`source`/`.` for the match to fire at all - a version of
  this regex that just looked for the path anywhere in the command
  would also have `cat`'d the file itself into "a gate run happened").
  Reads the command's own real output from
  `.tool_response.stdout` (not `.tool_result.text` - the actual field
  name and shape, confirmed by disassembling the installed Claude Code
  binary's own Zod schema and its Bash-execution object literal, after
  the public docs and two independent research passes each gave a
  different, wrong answer) and double-checks `.tool_response.exitCode`
  is `0` before stamping anything. `PostToolUse` should already only
  fire on a Bash command that exited 0 - a red gate simply never
  stamps, no matching `PostToolUseFailure` hook needed to clear
  anything, the same collapse-into-one-signal shape
  `mark-review-checked.sh` already has for "did it run" versus "did it
  pass" - the exit-code check is belt and suspenders on top of that,
  not a replacement for it. A run with no scope line at all is `full`
  if the command carried no `--docs` flag (every run before
  GATE-SCOPE-01 existed ran every stage) or `docs` if it did (`bot`'s,
  `stack`'s and `commons`'s own `check.sh` all support `--docs` but
  print no scope line at all, unlike home's - stamping those `full`
  would wave through a real-code commit on nothing more than the fast
  standards-core path having run).

## The architect gate (ARCH-GATE-01, 2026-10-02)

- **`require-architect-verdict.sh`** (PreToolUse, `Bash`): in a repo that
  keeps `docs/design/RULES.md`, denies a `git commit` unless a verdict is on
  record when it stages a new or changed file under `docs/design/`, a NEW
  file under `docs/plans/`, or a NEW backlog row in `docs/BACKLOG.md` (an
  added line starting `- [ ] **` whose id is not on a removed line). A
  checkbox flip or status edit in BACKLOG.md, an edit to an existing plan
  and a code path in a `Governs:` glob need no verdict (narrowed
  2026-10-15). The verdict is
  `data-scratch/architect/<ITEM-ID>.verdict` with `verdict: APPROVED`,
  under 24 hours old, for an item id that appears in the commit message
  (or whose `sha256:` equals the staged diff's). A commit that stages
  `docs/design/RULES.md` itself needs `Owner-approved: YYYY-MM-DD` in the
  message and then needs no verdict: only the owner changes a rule.
  Does nothing in a repo without RULES.md, exempts `--amend`, folds in
  unstaged tracked files under `-a`, finds the repo with `git rev-parse`
  so a worktree works (verdicts are read from the worktree's and the
  main checkout's `data-scratch/`). Soft gate: every denial names the
  next step. Tested in `plugin/hooks/tests/require-architect-verdict.test.sh`.
  See `docs/ARCHITECT.md`.

## UI rules before committing (PRECOMMIT-RULES-01, 2026-10-06)

- **`run-ui-rules-before-commit.sh`** (PreToolUse, `Bash`): before a `git commit`
  in a repo that ships `scripts/ui-rules-precommit.sh` (Home), runs that script on
  the staged files. It is deterministic (no network, no model, writes nothing),
  takes about a second, and exits at once when no staged file is under
  `frontend/src` or the Elements ledger. It denies a className override on a kit
  part, a new wrapper, a grown baseline or a missing ledger reason, naming the
  file, the Element and the fix. The same script runs as a plain git
  `pre-commit` hook (`scripts/install-hooks.sh`) so humans and Codex are covered.
  Skip with `MAIPAI_SKIP_UI_RULES=1`; the gate ignores it and always runs the
  full lint.

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
