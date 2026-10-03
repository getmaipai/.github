# Git workflow and code review

Dev tier. Full text of the git rules, with the dated reasons. Hooks that enforce parts of it are described in `plugin/hooks/README.md`. Load before staging in a shared checkout, running a review, or when a hook denies a git command.

## Land on main, no pull requests

**All work lands directly on `main`. Never open pull requests.** The remote is
publishing and backup, not a review step.

## The catalog carve-out

**The one carve-out: `catalog` accepts community pull requests**, gated on
the signed copyright assignment and CI (manifest lint, permission diff,
banned-API scan, recipe conformance, licence check, the scorecard). This
is how outside contributors submit packages. Maintainers still land their
own work directly on `main`, same as every other repo.

## Branches and worktrees

**Never create a branch or worktree** unless Jesse explicitly asks, or a
second session is actively editing the same repo in parallel. If one was
needed, merge it and delete it before the session ends. A branch that
outlives its session is a bug. If you notice a stray branch or worktree,
flag it for cleanup.

## Commit only completed, verified work

**Commit only completed, verified work** (see Verification below). One commit
per logical change. No checkpoint commits, no WIP commits: if work is
unfinished at session end, the honest state is a dirty tree plus a status
note, not a commit.

## Never stage or commit blindly

**Never stage or commit blindly.** Run `git status` (and `git diff` for
what actually changed) first, then stage specific files by name. Never
`git add -A`, `git add .`, or `git commit -a` without having just looked
at what that would sweep in: a parallel session's in-progress work in a
shared checkout, a stray file, or something that should stay uncommitted.
The `maipai` plugin's `block-blind-staging.sh` hook enforces this
mechanically (`plugin/hooks/README.md`); it denies the blind form when no
recent `git status` exists to point to, not the command itself.

## In a shared checkout the commit is atomic with the staging

  **In a shared checkout the commit is atomic with the staging.**
  Stage exactly what is yours (`git add <file>` for a file only you
  changed, `git add -p` for a shared doc), read `git diff --cached
  --stat` and confirm it lists only yours, then commit immediately
  with a bare `git commit`; never leave anything staged for later,
  and never commit while another session's hunks sit in the index.
  Do not use `git commit -- <files>` on a shared file: a pathspec
  commit takes the file from the working tree, not the index, so it
  sweeps the other session's uncommitted hunks in and defeats the
  `git add -p` you just did (2026-09-13: it happened both ways in one
  evening, a bare commit that took Session A's staged code under a
  docs title, then a pathspec commit that took A's unstaged backlog
  hunks). After every commit, `git show --stat HEAD` is read before
  the done report.

## No rebase, reset or checkout in a shared checkout without checking

  **Never run `git rebase`, `git reset`, or `git checkout` in a shared
  checkout without checking `git status`/`git diff --cached` for
  another session's staged or uncommitted work first** (2026-09-27,
  `home`: a session's own staged `docs/BACKLOG.md` correction was
  silently wiped when another session ran a plain `git rebase` on the
  same shared checkout mid-edit - recovered only because the staged
  blob was still reachable via `git fsck --dangling`; the first version
  of this exact loss earlier the same day was not recoverable the same
  way and had to be redone by hand). A rebase/reset/checkout operates
  on the whole working tree and index at once, the same blast radius a
  blind `git add -A` has, so it gets the same check first: read the
  status, and if anything is staged or modified that isn't yours, stop
  and let that session land or clear it before touching the tree.

## Code review before committing code

**Run a code review before committing code** (not a doc-only change): the
`code-review` skill, at least medium effort, on the diff about to be
committed. In a worktree, pass the review an explicit target (the
worktree path or the branch) and read the path and branch the review
reports before acting on a single finding: the review runs in a
forked subagent whose working directory can resolve to the main
checkout, and on 2026-09-12 one reviewed another session's
uncommitted work that way. A review whose reported path is not yours
is discarded and re-run with the target; its findings go to that
file's owner, never acted on by you. This is not a "remember to do it" rule: the `maipai` plugin's
`require-review-before-commit.sh` hook enforces it mechanically
(`plugin/hooks/README.md`), the same shape as the blind-staging gate,
because a session remembering to review its own work does not survive a
fresh session picking the task back up.

> OPEN CONFLICT for the owner: the line above says "at least medium effort", while "Reviews are fast" below says `low` is the default and `medium` needs a named reason. The core carries the later rule (low default). See mapping.md, contradictions list.

## Reviews are budgeted (2026-09-20)

  **Reviews are budgeted (2026-09-20).** One review invocation fans out
  several subagents at roughly 100k tokens each, and on 2026-09-20 one
  session ran three full passes per item, close to two million tokens
  of review for a single S item, with four of five subagents stuck
  searching for a tool. So: the level matches the item (`low` for an S
  item or a docs-and-config change, `medium` for an M item or anything
  that changes a route, a guard, or a wire shape, `high` only when the
  coordinator names it); one pass per commit; after fixing findings the
  re-review covers the fix hunks only (`git diff` of those files
  against the reviewed state), never the whole diff again, and a third
  pass never happens (a second pass that still finds real defects is a
  finding about the item, reported to the coordinator, not a reason to
  loop); a review whose subagents are "searching for" a tool or a file
  for more than a minute is stopped and rerun once with the target
  path, never left to run out its budget. The done report states the
  level, the pass count and each finding's disposition, so the
  coordinator can see the budget was kept. **Vendored code is never
  reviewed (2026-09-21):** a snapshot used as it ships (the kit's
  `dashboard/` and `elements/` folders, any future vendored source)
  is not our code, so a diff that only adds or updates vendored files
  gets no review, a mixed diff is reviewed with the vendored paths
  excluded, and a review whose finders are reading vendored files is
  stopped; a config, preset, pin or docs diff gets `low` or none.

## Reviews are fast (owner's rule, 2026-09-22)

  **Reviews are fast (owner's rule, 2026-09-22).** A review never
  becomes the long pole of an item, so: `low` is the default, and
  `medium` needs a named reason (a route, a guard, a wire shape, auth or
  safety); the target is always the exact diff about to be committed
  (the staged diff, or `main...HEAD` in a worktree), never the repo or
  the branch's history; the review starts while the gate runs, never
  after it, because the review is model time and the gate is machine
  time (a finding that needs a code change reruns only the tests it
  touches, then the gate once); a mechanical follow-up (a manifest
  line, a registry entry, a one-line mirror of an already-reviewed
  guard) gets a `low` pass on that diff alone (the commit hook needs a
  review on record), never a `medium` one. The done report states the review's wall time beside
  its level and pass count.

## Push at natural boundaries

**Push at natural boundaries** (a verified item merged to `main`, the end
of a work session, or when Jesse says ship), never reflexively after
every commit. A push needs no approval; a push that fails is reported
as blocked like anything else.

## Deploys and releases are explicit

**Deploys and releases are always explicit.** Cutting a release or rolling
the hub requires Jesse's word in the moment.

## Author identity

**Author identity:** Jesse's name is public and fine. His email is not:
commits use the GitHub noreply address, and no personal email ever appears
in code, docs, or package metadata.
