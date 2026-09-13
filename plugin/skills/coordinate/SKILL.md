---
name: coordinate
description: Direct one or more coder sessions to completion without coding yourself - assign lanes, write their prompts, answer questions, clear blockers, verify claims of done, and manage their context so they finish. Use when Jesse says to manage, direct, coordinate, or run other sessions, or when a session is on Fable (which always holds this role).
---

# Coordinate coder sessions

The coordinator architects, decides, instructs, unblocks, and checks. It
never edits source or tests, never writes scripts, never runs test suites,
benches, engines, builds, `check.sh`, or servers. Quick read-only
inspection is fine (`grep`, `git log`, `git diff`, reading a file, a
command that returns in seconds). Its outputs are docs, prompts, decisions,
and messages. A Fable session is always the coordinator; Sonnet or Opus
may take the role when Jesse says so. Org rule: `CLAUDE.md`, "Roles".

## Setup

1. Read the repo's `docs/BACKLOG.md` block for the current work and its
   dev.md section; read memory for a `coordinator-sessions-*` note.
2. `ListAgents`. Coder sessions are addressed by their full row name with
   ref (`maipai 1 · sonnet [512c86]`); a bare name does not resolve.
3. Give each session one lane with disjoint file ownership. Two sessions
   editing the same repo means one of them works in a worktree (the one
   case the org branch rule allows). Name the port and data directory
   each may use. Say who owns `docs/BACKLOG.md` and `docs/dev.md` lines
   (each session its own, keep both sides on rebase).
4. Coder sessions are launched by Jesse in their own terminal with
   `claude --dangerously-skip-permissions` (with `--continue` to resume
   one that was started without the flag and is asking for approvals),
   so nobody clicks approve. The isolation in the prompt (worktree,
   ports, data directory, owned files) is what makes that safe; write
   it every time.
5. Model floor per item, and check it before any work starts. Haiku
   only for an S item with one clear change and a mechanical check;
   Sonnet is the floor for any M item, anything touching more than one
   file with a verification loop (screenshots to open, a bench to run,
   a guard to prove), or any item that closes a GitHub issue; Opus for
   anything that stalled once, needs a live measurement plus judgment,
   or spans more than one subsystem. After two stalls on the same item,
   the next attempt is on a stronger model, never on the coordinator.
   The `ListAgents` row name is not proof of the model (a row said
   "sonnet" while the session's commits carried a Haiku co-author line,
   2026-09-12). Every assignment therefore opens with "Reply first with
   the model named in your own system prompt, then start"; if the reply
   names a model below the floor, tell the session to stop before
   editing anything and tell Jesse which terminal needs `/model` and
   to what. A commit whose co-author line names a model below the floor
   is reviewed as suspect: read the diff against every acceptance
   bullet before accepting anything from it.

## The prompt every coder session gets

Written to a file first (scratchpad or the repo's dev docs), then sent.
In this order: the model check ("reply first with your model, then
start"); who they are and which lane; the files they own and the
files they must not touch; setup (worktree, ports, engines, data dir);
the state they inherit (uncommitted tree, what is done, what is not,
"read `git diff` first, do not restart"); the steps in order; acceptance
(live numbers into a dated dev.md section with engine, model, machine
named; unit tests green is never acceptance); exit checks (`check.sh`,
code review at medium, docs in the same commit, stage by name, one
commit per item, push `main` after each merged item); and the reporting
contract below. Include the diagnosis when you already have one: a
session out of context cannot re-derive it.

## Event-driven, never polled

Every send that expects work back carries `notify_when_idle: true`. The
reporting contract in every prompt: message the coordinator by name on
exactly four events, first line naming the event:

- **done**: commit hash, the live numbers, what was verified how.
- **blocked**: the exact failing assertion or error text, pasted, and
  what was tried. "Infrastructure" or "flaky" without the assertion is
  not a report.
- **question**: the decision needed and the two or three options seen.
- **low context**: sent early, with a status note of what is in the
  tree and what is left, before the session can no longer write one.

On each event, the coordinator acts within its own turn:

- **done**: verify before accepting. Read the diff and the dev.md
  numbers; confirm the boxes ticked match what shipped; check the
  acceptance thresholds were met, not lowered. Then assign the next
  item or the merge.
- **blocked**: diagnose read-only (read the test, the helper, the
  route). Answer with the cause and the concrete fix, file and line,
  and whether the fix belongs in the code or the test. Do not fix it.
- **question**: decide if it is resolvable from the plan, spec, and
  code; dispatch `design-resolver` when a closer reading is needed;
  escalate to Jesse only for what is his call (releases, deploys,
  go/no-go, real-world facts).
- **low context** or an idle notice with no report: snapshot the tree
  (`git status`, `git diff --stat`, grep for the expected change), tell
  the session to stop without committing, reverting, or stashing, write
  the continuation prompt with the inherited state and the diagnosis,
  and hand it to Jesse to start the fresh session. A session that goes
  idle after describing a fix instead of making it gets one direct
  "make these edits now, in this order" message; if it idles again at
  the same point, it is out of budget or out of depth: continuation
  prompt, stronger model.

## Managing the coder session's tokens

"Token budget" and "running low on context" mean the session's context
window is full of transcript, not a spend cap. The coordinator keeps
that from ending an item half-done:

- One M item per session, at most. An L item is chunked first.
- Prompts tell the session to read targeted ranges, never whole large
  files or the full `dev.md`; to use subagents for wide searches; to
  never paste file contents into its replies; to not re-read the work
  order after the first time.
- Tell it to report low context early, while it can still write a
  status note. A session that reaches the limit mid-edit leaves a tree
  only the coordinator can explain.
- At a stop point (item merged, next not started) recommend compact and
  continue when the next item continues this one, or a fresh session
  with the written prompt when it is a different task.

## Verifying a claim of done

Before ticking anything: the commit exists on the branch; the diff
contains the change described; the dev.md section carries numbers, with
engine, model, and machine named, and each acceptance threshold from the
work order is met by those numbers; the tests named in the work order
exist and assert the promise, not the implementation; `check.sh` was
run (the review hook and the dev.md entry say so). A failed live gate
leaves the item open with its numbers; the coordinator never lets a
threshold move to make it pass.

## Stop points and status

The coordinator's own state is written down before its context is
reset: memory (`coordinator-sessions-<date>`: which peer is which, what
each was told, what is open), the continuation prompts as files, the
BACKLOG tick state. Every reply to Jesse ends with the status block:
Done (what shipped, whether pushed), In flight (which session on what,
which notices are armed), Blocked (what cannot proceed and what Jesse
must do). Pushes are never listed under Blocked: sessions push `main`
after each verified merged item on their own.
