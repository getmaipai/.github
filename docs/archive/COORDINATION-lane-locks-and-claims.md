# Retired: lane locks and item claims

Moved out of `docs/COORDINATION.md` on 2026-10-16. The `dispatch` skill and one worktree per session replaced both (see the status note in that file). Kept for the dated reasons only; no procedure here runs.

## Lane locks

**Lane locks, so only one coordinator drives a given Codex or
OpenCode target (owner's rule, 2026-09-26).** Codex and OpenCode have
no per-caller identity the way `ListAgents` gives Claude sessions, so
two coordinators (a handoff mid-flight, a second session started by
mistake) can type into the same pane or server session and corrupt
each other's turn. Each lane target keeps a lock file at
`<repo>/data-scratch/lane-locks/<codex|opencode>.lock` (coordinator
name, item id, acquired-at). Before sending anything to that lane,
the coordinator reads the lock: empty or already its own name, it
writes itself in and proceeds; held by another name, it does not
touch the lane and messages that coordinator instead. The lock is
held for the lane's current item and cleared when that item reports
done, blocked, or is handed off; it is never left stale past that.

## Item claims

**Item claims, so two lanes never collide on the same work or the
same files (owner's rule, 2026-09-26).** Before dispatching any item
(agent, Codex, or OpenCode), the coordinator writes a claim at
`<repo>/data-scratch/claims/<ITEM-ID>.claim` (owner name, lane,
worktree path, started-at), after checking that none already exists
for that id anywhere the item touches. A claim answers "who has
this" the way `ListAgents` answers "who is running" for Claude
sessions, but Codex, OpenCode, and a shared checkout have no registry
of their own. A session or agent that finds unclaimed, uncommitted
work sitting in a shared checkout does not guess whose it is and does
not finish it: it reads `data-scratch/claims/` for a match, and if
none exists, reports the diff to the coordinator rather than touching
it (this is exactly what cost a night's worth of cross-session
messages on 2026-09-26, when three sessions independently tried to
identify one uncommitted diff none of them had claimed). The claim is
removed when the item lands, or when its owner reports the item done,
blocked, or handed off elsewhere.
