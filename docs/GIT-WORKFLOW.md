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

**One session, one worktree on a short-lived `wt/*` branch, created by `scripts/wt.sh start`.** Land it with `wt.sh land`, then
`wt.sh done`; never hand-run `git worktree`. A branch or worktree that outlives its session is a bug: `wt.sh reap` removes
the ones it made and lists clean older ones (branch already on `origin/main`) that a person can remove.

**Codex runs write inside their own worktree only (owner's ruling, 2026-10-17).** `wt.sh run` launches
`codex exec -s workspace-write -C <worktree>`. Plain `codex exec` defaults to a read-only sandbox, so every run ended "Blocked by
this session's enforced read-only filesystem policy". `MAIPAI_CODEX_BIN` swaps only the binary (tests); the sandbox flag stays, and
no danger, full-access or bypass flag is ever passed (`standards/tests/ts/wt.test.ts` pins both). This supersedes the
`danger-full-access` note in `docs/COORDINATION.md` for runs started by `wt.sh`.

## The main checkout belongs to wt.sh

A repo's main checkout (the folder with the real `.git`) is read-only for sessions. Only `wt.sh` fetches, fast-forwards and adds
worktrees there. The plugin hook `guard-main-checkout.sh` denies `rebase`, `reset`, `checkout`, `switch`, `merge`, `pull`,
`worktree add`, `remote set-url` and force pushes in a main checkout; when Jesse approves one such change, put
`MAIPAI_ALLOW_MAIN_CHECKOUT=1` in the command. A main checkout that drifts (2026-10-16: `home` ahead 12 and behind 146, `commons`
left on another session's lane) is parked, never discarded: commit the dirty tree to `wip/<repo>-main-<date>`, branch any
unpushed commits to `wip/...`, then reset to `origin/main`.

## Commit only completed, verified work

**Commit only completed, verified work** (see Verification below). One commit
per logical change. No checkpoint commits, no WIP commits: if work is
unfinished at session end, the honest state is a dirty tree plus a status
note, not a commit.

## History: shared-checkout guards (retired 2026-10-15)

Until 2026-10-15 several sessions shared one checkout, and three rules
guarded it: read `git status` before staging, commit atomically with the
staging, and never `git add` the shared `docs/dev.md` or `docs/BACKLOG.md`
wholesale. Parallel sessions overwrote each other's staged hunks on
2026-09-13 and 2026-09-27, which is why the rules existed. Each session now
works in its own worktree, so the hooks that enforced them
(`block-blind-staging.sh`, `block-wholesale-shared-docs.sh`,
`mark-git-status-checked.sh`) are deleted. Stage specific files by name,
never `git add -A` or `.`, and read `git show --stat HEAD` after a commit.

## Code review before committing code

**Run a code review before committing T2 code** (the risky-surface list in the
org CLAUDE.md "Checks before landing" table; narrowed 2026-10-15, a T0 or T1
commit needs no review stamp): the
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
(`plugin/hooks/README.md`),
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

## Keeping branches, worktrees and sessions tidy (owner's rule, 2026-10-09)

- **Name every session "role · work"**: `coord · admin-settings`, `cloud · link-state`, `codex-a · place-hub`. Repo goes in the work part when more than one repo is live. A session without a name that says what it does is renamed or archived.
- **At landing, the lander removes its own leftovers in the same report:** the work branch (local and remote), its worktree, its claim and lock, and archives its cloud session. The done report names each.
- **Close-out check on every agent report (2026-10-11):** before the coordinator marks an item done, it runs `bash scripts/leftovers.sh` in the repo and clears what belongs to that item: its claim, its lock, its worktree, its branch (`git branch -d` once merged; archive a marker to `data-scratch/archive/<date>/` instead of deleting when unsure). A claim or lock left on a done item is the coordinator's defect. The weekly Haiku sweep runs the same script and lists leftovers for the coordinator to check.
- **Remote branches:** delete one only when it is merged into `origin/main` or every commit is patch-equivalent (`git cherry` shows no `+`), and its newest commit is over 2 hours old. Log `repo branch sha` to `data-scratch/cleanup/deleted-branches-<date>.txt` first so it can be recreated.
- **Weekly sweep (coordinator):** list remote branches per repo, delete the provably dead ones by the rule above, list the unmerged rest with age and owner. Unmerged branches are reported, never deleted unseen.
- **Cloud sessions** are named at start; when the item lands, Jesse archives the session (the coordinator cannot reach the desktop sidebar) and the report lists which ones.
- **Worktrees** live beside the repo as `<repo>-<lane>-<item>`, never inside `data-scratch/` (a nested checkout breaks relative imports). Remove after landing.

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

## Origin guard

`standards/bin/origin-guard.sh` fails when a checkout's `origin` URL names a different repo than the checkout (on 2026-10-15
`home`'s origin pointed at `commons.git`, so fetches showed commons history and looked like a force-push). `wt.sh` runs it before
`start`, `check`, `land` and `done`, and `wt.sh start` installs it as the repo's `pre-push` hook (a pre-push hook that is not
ours is left alone and reported). Before reporting a force-push or missing history, run `git remote -v` and
`git reflog show origin/main`.
