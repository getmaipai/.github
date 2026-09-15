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
   worktree, and commits atomically with its staging: stage only its
   own files or hunks, read `git diff --cached --stat`, bare `git
   commit` at once, `git show --stat HEAD` afterwards; never a
   pathspec commit on a shared file (it takes the working tree and
   sweeps the other session's hunks in) and never a commit while the
   other session's hunks are staged (this binds the coordinator's own
   doc-only commits in that checkout too); shared
   docs are staged with `git add -p` only. Better
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

## 1b. Small isolated items: the two non-Claude lanes (2026-09-15)

An S item in files no session has open, or a small M item whose brief
can name every file, rule, test and command, goes to one of two lanes
that cost no Claude tokens; anything needing a decision, a diagnosis
or a read of how subsystems interact stays with a Claude session (the
model floor table in CLAUDE.md). The first try of a local model
(2026-09-13, `docs/DECISIONS.md`) was retired for reading its own
diff badly in a shared checkout; both lanes below run in their own
worktree at the base the coordinator picks, commit only, never push,
and every result is read by the coordinator (the diff, the checks
rerun, the commit message compared) before it is stacked.

**The local model** (the household's 27B through an OpenCode server on
the dev machine, `docs/local-coding-model.md` for what it can and
cannot do). Exactly one session, never recreated; between briefs the
coordinator deletes its messages through the server API and posts the
next brief with `prompt_async` (the `session-c-post` helper in the
repo's scratch folder). The server's working directory is a scratch
folder, never a checkout, and the session's own directory is the same
folder, so a relative path in a brief cannot land in shared code. It
never works inside the turn engine file; those items go to the other
lane or to a Claude session.

**Codex**, in Jesse's visible window, driven by the coordinator. Codex
has no API for a running TUI, so it runs inside a tmux session named
`codex` started once by Jesse (`tmux new -s codex -c <the codex
worktree>`, then `codex` inside it) and the coordinator types into it:
`tmux send-keys -t codex "/clear" Enter`, a two-second wait, the
pointer line ("Read <brief path> and do exactly what it says.") sent
as text, a one-second wait, then `Enter` on its own (text typed while
`/clear` runs is lost), and reads the screen with `tmux capture-pane
-t codex -p` to see when it is done and what it printed. One fixed
worktree folder for Codex, kept forever; the coordinator re-points its
branch between briefs (`git checkout -b codex/<item> <base>` in that
folder) so Jesse never changes directory or restarts it. Reports go to
a file outside the worktree, never committed. Its failure modes so
far: a commit made over a red check, a test expectation changed to
match the code, a word list widened until a test passed, a cause
"explained" by restating the diff; the brief forbids each by name and
the coordinator reads for them.

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

A work order that names a source, a service, or a mechanism names the
platform's existing general one first and places the new thing inside
it; a specific source described as if it were the design inverts the
architecture (2026-09-13: a media metadata package was written up as
the lookup plan while the hub's own SearXNG web search, the spine of
every world lookup, went unmentioned until Jesse asked).

A work order states no premise about the code that the coordinator has
not read. If an item says "spec first", "the route logs the turn", or
"the finished reply can be fetched", the coordinator has opened the
file and cites the line; two work orders on 2026-09-13 sent a session
to build on a premise a grep would have refuted (a record that is
deliberately not spec-shaped; a reply that never exists because the
route aborts on disconnect).

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

That checks the work order was done. It does not check the claim the
item makes, and on 2026-09-13 an outside review found five items whose
own tests passed while the claim had uncovered inputs (an output
boundary that missed error fallbacks, a credential filter that missed
summaries, an edit exclusion that missed recall and the judge). So,
in addition:

- **A universal claim is accepted only with an enumeration.** When an
  item says "every", "one boundary for all", or "never enters", the
  done report lists every producer or consumer the claim covers and the
  test that exercises each, failure paths included (error fallbacks,
  partial results, aborted streams are replies, captures, and turns
  like any other). The coordinator reads that list against the code
  (grep for the call sites), not against the tests.
- **A metric name is checked against its computation.** When a verdict
  rule names precision, recall, or a rate, read the bench's lines that
  compute it before accepting a number under that name.
- **A claim about a library is verified in its installed source** and
  the report cites where; a header comment or a README is not
  verification.
- **An accepted exception opens its follow-up item in the same
  commit**, named in the tick's status line.
- **A block ends with an independent review**: a session that neither
  wrote nor accepted the work (a fresh session, or Codex) reads the
  block's whole diff against its acceptance claims, by source
  inspection, and its findings are triaged before the next block
  starts. The coordinator's acceptance is never the last review.

A tick in `BACKLOG.md` says which of three things it means, in its
status line: verified at a named commit; done with an accepted
exception (what was missed, who ruled, and the follow-up item's name);
or committed with live verification still outstanding (what remains).
An item with two acceptance gates where one is missed is the second
kind, never a bare tick. The status dashboard reads these lines, so a
bare tick on a partial result is a false report.

When two sessions commit to the same `main`, each session's gate runs
on its own diff over the current `main`, so every gate after the first
verifies the other session's committed work too; the integrator still
runs `check.sh` on bare `main` at the block's end so the final state
is verified as a whole at a named commit.

## 5. Stop points and status

Before a context reset: the handoff notes are current, memory
(`coordinator-sessions-<date>`) says which session is which, what each
was told, what is open, and where the notes are. Every reply to Jesse
ends with the status block in CLAUDE.md's shape (Writing style):

```
STATE: active | waiting | blocked [<owner>: <what>] · <session>: <item> (running ~<when> | holding, behind <what> | blocked) · landed <item>
PROGRESS: <milestone>  ▰▰▰▱▱▱  3/6  ·  now <item>  ·  next <items in order>
YOU: nothing | <ask> (whenever) | <ask> (blocking: <what it holds>)
```

`You:` is the only place an ask appears, and each ask is written for
a reader who saw no earlier message (the exact command or decision;
never "still yours"); `State: blocked` is used only when work has
stopped and names the owner; a fact that stops nothing is never a
block. The old four-section block put asks in two places and blocks
where nothing was blocked (2026-09-13 twice, 2026-09-14 once); this
shape exists to end that.
