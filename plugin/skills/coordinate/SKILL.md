---
name: coordinate
description: Direct one or more coder sessions to completion without coding yourself - assign lanes, write their work orders, run the ready handshake, answer questions, classify and clear blockers, verify completion reports against acceptance, and hand off cleanly when a session runs out of context. Use when Jesse says to manage, direct, coordinate, or run other sessions, or when a session is on Fable (which always holds this role).
---

# Coordinate coder sessions

Policy lives in the org `CLAUDE.md`, "Roles: coordinator and coder"
(role boundary, model floor, verification, Git). This skill is the
procedure. The coordinator architects, decides, instructs, unblocks, and
checks evidence. It never edits source or tests, never writes scripts,
never runs suites, benches, engines, builds, `check.sh`, or servers.
Quick read-only inspection is fine. Its outputs are work orders, handoff
notes, decisions, messages, and docs.

## 1. Setup

1. Read the repo's `docs/BACKLOG.md` block for the current work and its
   dev.md section. Read memory for a `coordinator-sessions-*` note; it
   points at the canonical handoff notes.
2. Discover the channel. `ListAgents` lists sessions; address one by its
   full row name with ref (`maipai 1 · sonnet [512c86]`); the bare name
   does not resolve, and the label is the terminal's original model, not
   its current one. If `ListAgents` or `SendMessage` is unavailable, the
   fallback is a work-order file whose path Jesse pastes into the
   session; everything below still applies.
3. Give each session one lane with disjoint file ownership. Two sessions
   editing the same repo means one works in a worktree (the one case
   the org branch rule allows). When both must sit in the same checkout
   (after a merge, on `main`), disjoint files are not enough: the other
   session's half-edited files make `check.sh` fail for everyone, so
   each session gates on its own diff applied to a throwaway worktree
   of `main`, commits by name in the shared checkout, and removes the
   worktree; shared docs are staged with `git add -p` only. Better
   still, do not share the prose file at all: each session writes its
   dated sections to its own `docs/dev/session-<x>.md` and the shared
   `docs/dev.md` carries one index line per item (patch-mode staging
   failed once on each side in one night when both appended to
   `dev.md`; a one-line tick in `BACKLOG.md` is safe, a 140-line
   section is not). Name each session's port and data
   directory. Say who owns which lines of `docs/BACKLOG.md` and
   `docs/dev.md`.
4. Name one session the **integrator** for the block: it merges lanes
   into `main` serially, reconciles shared docs into one consistent
   text (never two contradictory paragraphs kept "both sides"), runs
   `check.sh` on the combined `main`, pushes, and removes temporary
   branches and worktrees. The coordinator reviews its evidence.
5. Coder sessions are launched by Jesse with
   `claude --dangerously-skip-permissions` (with `--continue` to resume
   one started without the flag). Pick the model from the floor table
   in `CLAUDE.md`; the ready handshake (section 3) confirms it.

## 2. The work order

Written to a file first, then sent. The file is the canonical handoff
note for that lane: it lives at `docs/plans/<lane>-<date>.md` in the
repo when it can be committed (a doc-only commit), otherwise at one
named path; memory and messages carry its path, not a copy.

In this order: the ready handshake request; who they are and which
lane; item id; files owned and files forbidden; setup (worktree, ports,
engines, data dir); the state they inherit ("read `git diff` first, do
not restart"), including any diagnosis the coordinator already has;
the steps in order; **acceptance evidence matched to the item** (a
regression test for deterministic behavior; the flow exercised and the
screenshot opened for UI; measured numbers with engine build, model
file, and sanitized hardware for performance or hardware work); exit
checks (`check.sh`; code review at medium with an explicit target when
the session is in a worktree, and the reviewed path and branch checked
against its own before any finding is acted on, since the review's
forked subagent can land in the main checkout; docs in the same
commit; stage by name; one commit per item; any command that can run
longer than two minutes, `check.sh` and benches included, runs in the
background or with the tool's timeout raised, because a foreground
command is killed at 120 s and the kill looks like a random test
failure; every server or engine a session starts for a live check is
recorded by pid and port when started and stopped by that pid, with
the ports confirmed free afterward, never by a command-line pattern
(a start script that changes directory and execs leaves no path to
match, so a pattern "stop" reports success while a 5 GB engine keeps
running, 2026-09-12); push at the org's natural
boundaries, a verified item merged to `main` being one); and the
reporting contract (section 3). Read ranges, not whole large files;
re-read only the acceptance list, once, before reporting done.

Size the slice so it can be implemented and verified with context to
spare. An M item that would take days is chunked into such slices, each
with its own acceptance, before it is assigned.

## 3. Events, never polling

Every send that expects work back carries `notify_when_idle: true`.
The session reports five events by message, first line naming the
event and the item id:

- **ready**: the model named in its own system prompt (or "unknown"),
  the checkout and branch, and the assignment in one line. Work starts
  only on the coordinator's reply "start". A model below the floor, or
  unknown, is resolved with Jesse before "start".
- **done**: the completion report: revision hash; each command run
  with its exit result (`check.sh`, the named tests, the review skill
  and its findings' disposition); where the evidence is (dev.md
  section, screenshot paths opened, bench table); what is left for
  whom.
- **blocked**: the exact failing assertion or error pasted, what was
  tried, and the session's own guess at the class (below).
- **question**: the decision needed and the options seen.
- **low context**: sent early, with a status note of what is in the
  tree and what is left.

Handling, within the coordinator's own turn:

- **done**: verify before accepting (section 4). Then assign the next
  item, or the integration step.
- **blocked**: classify first. *Environment* (missing dependency, port,
  tool, data): arrange the fix, no model change. *Unclear requirement*:
  decide, or dispatch `design-resolver`, and answer. *Context
  exhaustion*: handoff (below). *Reasoning failure* (the session had
  what it needed and still could not do it, or reported success that
  the evidence contradicts): the next attempt is on a stronger model
  with the same work order plus the diagnosis. When the coordinator
  can name the cause from a read-only look, it does, with file and
  line and whether the fix belongs in code or test; when it cannot, it
  asks the session for one discriminating measurement rather than
  guessing. When the strongest permitted model stalls, re-scope the
  item (chunk it, write a design note) instead of retrying.
- **question**: decide when the plan, spec, and code answer it;
  escalate to Jesse only for what is his (releases, deploys, go/no-go,
  real-world facts).
- **low context**, or an idle notice with no report: ask once for a
  status report; if none comes, snapshot the tree read-only, tell the
  session to stop without committing, reverting, or stashing, update
  the handoff note with the inherited state and diagnosis, and hand it
  to Jesse for a fresh session. A session that idles after describing
  a fix instead of making it gets one "make these edits now, in this
  order" message; a second idle at the same point is classified like
  any blocker, not assumed to be capability.
- **Missed acknowledgment or delivery failure**: one bounded recovery
  check (re-send, or a status request) is allowed; routine progress
  polling is not.

The same economy applies to the coder sessions. A session waiting on
another session's commit goes idle and is woken by one message from
the committing session (the hash and "files free"); it never re-checks
git, never writes "still waiting", never messages the coordinator to
say nothing changed. Every such turn re-reads its whole context for no
work. Messages go to the one session they concern; both sessions get
the same message only when both need the same fact (a merge window
opening, a ruling that changes what each may touch). Sessions message
each other directly for file handoffs and do not route them through
the coordinator.

## 4. Verifying a completion report

Before ticking anything: the commit exists on the branch and its diff
contains every change the report describes; each acceptance bullet in
the work order has matching evidence (test present and asserting the
promise, screenshot opened and judged, numbers meeting the threshold
with no threshold moved); the report lists `check.sh` and the review
with results (the review hook only proves the review was invoked; the
report proves it finished and what was done with the findings); docs
landed in the same commit. After the integrator merges, the combined
`main` has its own `check.sh` result before the block is called done.
A failed gate leaves the item open with its evidence.

## 5. Stop points and status

Before a context reset: the handoff notes are current, memory
(`coordinator-sessions-<date>`) says which session is which, what each
was told, what is open, and where the notes are. Every reply to Jesse
ends with the status block: Done (what shipped, whether pushed), In
flight (which session on what, which notices are armed), Blocked (what
cannot proceed and what Jesse must do, including a push that failed).
