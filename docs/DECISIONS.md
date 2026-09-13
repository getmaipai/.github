# Org decision record

Dated entries for decisions that changed an org-wide rule, with the
incident or review that prompted each. The rule itself lives in
[CLAUDE.md](../CLAUDE.md) or the named standard; this file keeps the
why, so the rule can be revisited on the facts rather than re-argued
from memory. Newest first.

## 2026-09-13 (evening): the local coder is retired

**What happened.** The afternoon's decision to send small isolated
items to OpenCode on the household's Qwen3-Coder-30B-A3B (IQ4_XS, on
the laptop's eGPU) was tested on seven tasks of rising difficulty,
with a capability log kept for a tuner session that fixed the server
side as findings came in (dead starts traced to the laptop's NIC
shaping, one slot owning the full context, the question tool off at
the source, `git restore`/`stash`/`reset` denied, llama.cpp bumped,
an eGPU-only layout, and a dense Qwen3-8B tried and rejected on
judgment). Result: three commits landed (a wizard step in a doc, a
`--docs` flag on the gate, the TypeScript half of #72, which needed a
second pass); four tasks produced nothing usable. It took about 1 h
45 min of coder time and about 2 h of coordinator time, against
about 15 min for a Sonnet session doing the same three commits; one
broken test reached `main` past a gate, one session's staged index
was unstaged, and the shared checkout was polluted once. The model
executes a one-file change with a precise spec correctly and fails
on anything with a second concern (a setup step, a directory rule, a
subtle rule among plain ones, recovery), and its own reports cannot
be trusted, so every result had to be read line by line.

**Decisions.**

1. The local coder path is retired. Nothing is sent to OpenCode; the
   `localcode` wrapper and the tuner's write-up stay in the homelab
   repo as a record, and the capability log stays in
   `home/data-scratch/`.
2. Small isolated items go to the Claude session that owns the area
   or to a Haiku session under the model floor table. Never a pasted
   prompt.
3. Codex stays as the outside reviewer only.
4. The lesson about what to measure holds: a coder is judged by the
   coordinator time it saves, not by its token price. A free model
   that needs its diff read is more expensive than a paid one that
   does not.

**Commits.** `getmaipai/.github`: this one.

## 2026-09-13 (afternoon): small isolated items go to the local coder, sent into the live window

**What happened.** Small, isolated items (a test fixture, a normalizer,
a doc page) were being handed to Jesse as prompts to paste into Codex
or OpenCode by hand, and he had to relay the reports back. He rejected
that, rejected a Claude subagent as the substitute (the local model is
the point: private, his hardware), and asked to keep watching the live
window. His `localcode` alias runs OpenCode against the household's
Qwen3-Coder-30B and serves an HTTP API; the coordinator can put a task
into the window's own input and read the transcript back. Two
lessons from the first attempts: a prompt sent by session id after he
restarted the alias ran headless where he could not see it, and a
Qwen session left to pick its own backlog item ran the full test
suite in the shared checkout beside two editing sessions.

**Decisions.**

1. Small isolated items go to the local coder through the live
   window's API; the coordinator sends, reads, and verifies by
   artifact. No pasted prompts, no relayed reports (CLAUDE.md Roles;
   the `coordinate` skill, section 1b).
2. Qwen3-Coder-30B is Sonnet-class for S items with no shared files
   and a mechanical gate; never the chat engine, memory, safety, or
   the supervisors.
3. A local-coder prompt names its files, forbids the full suite when
   the shared checkout is dirty, and fixes the report shape; a local
   coder never chooses its own item.
4. Codex stays as the outside reviewer (a second model's reading of a
   design or a block), launched the same way.

**Commits.** `getmaipai/.github` 565f2ca, 8868fb2, and this one.

## 2026-09-13: acceptance verifies the claim, not the work order

**What happened.** After a night of coordinated work on `home` (the
2026-09-12 chat block, ROUTE-01/02, CHAT-18/01/02, and Session B's
frontend lanes), an outside review by Codex read the whole diff
against its acceptance claims and found five defects in accepted
commits: the "one output safety boundary" skipped package error
fallbacks on two outlets (#86); the credential filter redacted history
rows but not existing summaries, and matched only a key's header line
(#89); the edit-branch exclusion covered the conversation window but
not episode recall or the memory judge (#88); the judge bench printed
"precision" and "recall" that were both a two-case pass rate (#87);
the Firefox service-worker passthrough gated one listener while the
precache library registered another (#90). Two of the coordinator's
own work orders rested on premises a grep would have refuted (a "spec
first" item for a record that is deliberately hub-internal; a
reconnection item that assumed a finished reply exists after a
disconnect that aborts generation). Every faulted item had passed its
own tests and met its written acceptance.

**Decisions.**

1. A universal claim ("every", "one boundary", "never enters") is
   accepted only with an enumeration of every producer or consumer it
   covers and a test per path, failure paths included. The acceptor
   reads the enumeration against the code (CLAUDE.md Verification;
   the `coordinate` skill, section 4).
2. A metric's name is checked against its computation before a number
   is accepted under that name.
3. A claim about a library's behavior is verified in the installed
   source, cited by line.
4. A work order states no premise about the code the coordinator has
   not read (skill, section 2).
5. An accepted exception opens its follow-up item in the same commit,
   and a `BACKLOG.md` tick states which of three things it means:
   verified at a commit, accepted exception with the ruling and the
   follow-up named, or verification outstanding.
6. A block ends with an independent review by a session that neither
   wrote nor accepted the work, triaged before the next block. The
   coordinator's acceptance is never the last review.
7. A waiting session goes idle and is woken by one message; it never
   polls, re-checks, or reports that nothing changed.

**Commits.** `getmaipai/.github` 5dea0f1, 32e78ac, and this one.

## 2026-09-12: the coordinator role, its skill, and the rules it changed

**What happened.** A Fable session reviewing `home`'s chat program
finished both concurrent Haiku tracks itself (benches, engine spawns,
fixes, gates) after the coder sessions stalled: a day of the most
expensive model on work whose value is the same whoever types it. That
evening the same session was set to manage two coder sessions instead.
Both sessions were labeled "sonnet" in the agent list and both were
Haiku; one ran out of context mid-item twice, the other closed an issue
on one of six defects fixed and "verified on all surfaces" with no
screenshot opened. A misdirected code review then read another
session's uncommitted diff because the review's forked subagent landed
in the main checkout instead of the worktree. Codex reviewed the first
cut of the resulting rules and found contradictions with the org
standard.

**Decisions.**

1. Two roles, coordinator and coder (CLAUDE.md "Roles"). Fable always
   coordinates and never codes, tests, benches, builds, or runs
   servers; Sonnet or Opus may coordinate when Jesse says so. The
   procedure is the maipai plugin skill `coordinate`.
2. Coordination is event-driven: ready, done, blocked, question, low
   context; a session starts only on the coordinator's start message
   after its ready report; idle-notice subscriptions replace polling.
3. One model-floor table, in CLAUDE.md. Haiku only for an S item with
   one clear change and a mechanical check; Sonnet for any M item,
   any verification loop, or anything that closes an issue; Opus for a
   classified reasoning failure, a live measurement plus judgment, or
   work spanning subsystems. The agent list's label and a co-author
   line are hints; the session's own report is the check.
4. Blockers are classified (environment, unclear requirement, context
   exhaustion, reasoning failure) and only a reasoning failure buys a
   stronger model; the strongest permitted model stalling means the
   item is re-scoped.
5. Evidence matches the item's acceptance (regression test, exercised
   flow plus opened screenshot, or measured numbers with a sanitized
   hardware description). Live numbers are required when the item
   names them, not for every item. The review hook proves only that a
   review was invoked; the completion report proves what was run and
   what was done with findings.
6. Each parallel block names one integrator that merges serially,
   reconciles shared docs into one text, verifies the combined `main`,
   and removes temporary branches and worktrees.
7. Coder sessions launch with `claude --dangerously-skip-permissions`;
   the isolation in the work order (worktree, ports, data directory,
   owned files) is what makes that safe.
8. Pushes need no approval: a verified item merged to `main` is a
   natural boundary, and a failed push is reported as blocked.
9. Doc-only commits need the standards core, not the full `check.sh`
   (stated under Verification).
10. A code review run from a worktree passes an explicit target and
    checks the reported path and branch before any finding is acted
    on; a mismatched review is discarded and its findings routed to
    the owner.
11. The handoff note for a lane is one canonical file whose path is
    shared; memory and messages point at it rather than copying it.

**Rejected or adjusted from the review.** "One M item per session"
became "a slice small enough to implement and verify with context to
spare", chunked before assignment. "Never re-read the work order"
became "re-read the acceptance list once before reporting done". A
bounded recovery check after a missed acknowledgment is allowed;
progress polling is not.

**Commits.** `getmaipai/.github` 36617a5, 7eb174a, b364172, 3906f14.
