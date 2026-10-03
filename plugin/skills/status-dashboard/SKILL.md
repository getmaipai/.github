---
name: status-dashboard
description: Refresh the MaiPai Build Status dashboard (an Artifact) from every repo's docs/BACKLOG.md and open GitHub issue counts. Use whenever a docs/BACKLOG.md changes, at latest before a session ends, or when Jesse asks for the dashboard to be brought current.
---

# Refresh the build status dashboard

The dashboard is a published Artifact at
**https://claude.ai/code/artifact/68f69163-11ad-40ca-a272-9bc46759bbc2**
("MaiPai Build Status"). It reads live from its own shared `db` (collections
`areas` and `repos`) - refreshing it is a `write_db` call, never a redeploy.
Redeploy `dashboard.html` only for a layout/design change, **or to resync
the embedded `INITIAL` snapshot after an `active`/`next` write** (see
"Active work and next-up" below) - not for an ordinary built/missing data
refresh, which is `write_db` alone.

Source of truth is each repo's `docs/BACKLOG.md` (see
[`docs/BACKLOG-FORMAT.md`](../../docs/BACKLOG-FORMAT.md) > Backlog) - this skill is a
derived view, never a second place status gets decided.

## Process

1. For each repo (`stack`, `home`, `catalog`, `go`, `bot`), run the parser:
   ```
   bun run parse-backlog.ts <repo> ~/Developer/github.com/getmaipai/<repo>
   ```
   Prints `{ repo, phase, areas: [{ area, done, open, status, built, missing, waiting }] }`,
   already excluding empty/meta sections (the parser drops any area where
   `done + open === 0` itself - not a step to remember by hand). `waiting`
   is real, parsed output too - see "Waiting on you" below, not a
   coordinator-tracked field like `active`/`next`.
2. Get each repo's open issue count:
   `gh issue list --repo getmaipai/<repo> --state open --limit 500 --json number --jq 'length'`
3. List what is there first: `ArtifactData` `action: "list"` on `areas`
   (`query.limit` 200) and on `repos`, with `out_dir` set to a scratch
   folder. The listing prints each doc's `version`; every write below to
   an existing doc must carry it as `if_version`, or the whole batch is
   refused (found live 2026-09-27, when an unpinned refresh wrote
   nothing twice). The saved files hold the content only, not the
   version, so take the versions from the listing itself.
4. For each area, write one doc to collection `areas` with
   `doc_id: "<repo>--<slug(area)>"` and **this exact shape** -
   `dashboard.html`'s live view groups docs by `repo`, so every field
   below must be present, not just the parser's own output:
   ```json
   {"repo": "<repo>", "area": "<area>", "phase": "<phase>", "status": "<green|yellow|red>",
    "done": 0, "open": 0, "built": ["..."], "missing": ["..."], "waiting": ["..."],
    "updated_at": "<ISO timestamp>"}
   ```
   The slug is the area heading lowercased, every run of one or more
   non-alphanumeric characters collapsed to a single `-`, leading and
   trailing `-` trimmed: "The chat rebuild (2026-09-22)" is
   `home--the-chat-rebuild-2026-09-22`, never
   `home--the-chat-rebuild--2026-09-22-`. A slug that does not match the
   listing's ids forks a duplicate card beside the real one (found live
   2026-09-27), so check the generated ids against the listing before
   writing; every generated id but a genuinely new area must already
   exist.
   For each repo, one doc to collection `repos` with `doc_id: "<repo>"`:
   `{ repo, phase, open_issues, issues_url, updated_at }`.
5. Write with the `ArtifactData` tool, `action: "batch"`, each entry
   `{op, collection, doc_id, file_path, if_version}` pointing at the
   per-doc JSON file written in step 4 (never retype the docs inline).
   Use `op: "update"` for an area doc, not `set`: `update` merges, so
   the coordinator-tracked `active`/`next` fields below survive a data
   refresh, where `set` silently drops them. A batch holds at most 50
   writes and the five repos produce about 70 docs, so a full refresh is
   two batches; both commit atomically or not at all.
6. Do not touch the HTML unless the visual layout itself needs to change.

The plugin cache under `~/.claude/plugins/cache/maipai/` can lag this
file (on 2026-09-27 the cached 0.8.0 copy still listed four repos and
no `waiting` field); when the skill loads from the cache, read this
source file and `parse-backlog.ts` from the `.github` checkout instead.

## Active work and next-up (added 2026-09-24)

Two optional fields on an `areas` doc, beyond the parser's own shape:
`active` (a string array - what a lane is doing on this area right now,
named with the lane, e.g. `"D9: delete the subject stack's world half
and pronoun machinery (Codex, in progress)"`) and `next` (a single
string - the next item in priority order once current work clears).
These are **coordinator-tracked, never parsed** - `parse-backlog.ts`
does not and should not know about them, because `docs/BACKLOG.md` has
no concept of "who is working on this right now." Only set them for an
area you are actually, live coordinating; leave them unset (or clear
them back to `[]`/absent) for everything else rather than guess. The
card sorts to the top of its lane and gets a purple accent while
`active` is non-empty; the legend and footer already say these fields
are coordinator-maintained, not parsed.

**The rule this section exists to enforce, found live 2026-09-24:** a
`write_db` update to `active`/`next` is invisible to a viewer whose
session has no live `db` connection, because the page renders the
`INITIAL` snapshot baked into `dashboard.html` at publish time first
and only overlays live data if a connection succeeds. Writing `active`
via `write_db` alone, without also patching `INITIAL` and redeploying,
is exactly the kind of silent gap Jesse caught the same day ("the
status page shows nothing active but Codex is doing stuff"). So:
**every time `active` or `next` changes - which means every time work
is assigned or reassigned to a lane, not at some later cleanup point -
do both in the same step:** `write_db` the change, and patch the
matching area's `active`/`next` fields inside `INITIAL` (a targeted
edit of that one area's JSON, not a full re-dump, is enough) and
redeploy. Doing only the first half is the bug that prompted this
paragraph.

## Waiting on you (added 2026-09-25)

`parse-backlog.ts` itself detects, per area, every open item whose own
text says `Jesse's call` or `owner's call` in its lead-in (the bold
title plus the sizing parenthetical right after - a mention buried
deep in an item's body, recording a past decision on some sub-point,
does not count; see the parser's own `WAITING_RE` comment). Unlike
`active`/`next`, this is real parsed output, not coordinator-tracked -
never hand-edit a `waiting` array, it comes from `docs/BACKLOG.md`'s
own words. Two things `WAITING_RE` deliberately excludes, found live
2026-09-25 reviewing this feature against real BACKLOG.md text: a
trailing number ("owner's call 5") is a citation to an already-made,
numbered decision recorded elsewhere with the answer quoted right
there, not a live question; a nested checklist sub-item (`  - [ ]
(1) ...`, split out from a parent item for separate tracking) is its
own item with its own lead-in, scanned the same as a top-level one -
the parser previously dropped nested items from the counts entirely,
a real accuracy gap beyond just this feature.

`dashboard.html` renders every non-empty `waiting` array from every
repo's every area as one persistent banner near the top of the page,
**always visible whenever anything is waiting, never buried inside a
lane card** - this is the whole point: Jesse asked, 2026-09-25, for
these to always be clear on the dashboard, after a night where seven
of them sat answered-only-when-asked, scattered across a 9,800-line
BACKLOG.md with no visibility. The banner is empty (and hidden) when
nothing is waiting - that is the goal state, not a bug.

**Found live, 2026-09-25: once Jesse answers a `Jesse's call` item,
reword its BACKLOG.md title to drop the phrase** (or move it out of
the lead-in) **the same commit that records the decision** - otherwise
it keeps showing as "waiting" forever, even though the question is
answered and only the follow-up work is what's actually still open. A
`- [x]` tick alone isn't enough here: the follow-up implementation item
this decision unblocks is a new, separate `- [ ]` row, which the
parser scans fresh and would flag again if it echoed the same phrase
in its own lead-in.

Same `INITIAL`-resync rule as `active`/`next` applies, and for the
identical reason: `write_db` alone is invisible to a viewer with no
live `db` connection. Whenever a `waiting` array changes for any area
(an item resolved, a new one found), patch that area's `waiting` field
inside `INITIAL` and redeploy, in the same step as the `write_db` call.

## When to run it

Per [`docs/BACKLOG-FORMAT.md`](../../docs/BACKLOG-FORMAT.md) > Backlog: whenever a
`docs/BACKLOG.md` changes, at latest before the session ends. This is an
instruction, not a hook - judging whether a BACKLOG.md actually changed in a
way worth reflecting needs contextual reading, the same reason
review-before-commit stays a soft gate instead of a script.

## If the dashboard's layout needs to change

Edit `dashboard.html` in this directory (the design token block at the top
covers color/type/spacing) and republish it with the `Artifact` tool against
the same URL, passing `capabilities: {db: {}}` only if it was ever cleared -
otherwise omit `capabilities` so the stored declaration carries forward.
Keep the embedded `const INITIAL = {...}` block as a real, current snapshot
(not stale placeholder data) so the page still renders correctly for a
viewer whose session has no `db` capability.
