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
[`CLAUDE.md`](../../CLAUDE.md) > Backlog and status) - this skill is a
derived view, never a second place status gets decided.

## Process

1. For each repo (`stack`, `home`, `catalog`, `go`, `bot`), run the parser:
   ```
   bun run parse-backlog.ts <repo> ~/Developer/github.com/getmaipai/<repo>
   ```
   Prints `{ repo, phase, areas: [{ area, done, open, status, built, missing }] }`,
   already excluding empty/meta sections (the parser drops any area where
   `done + open === 0` itself - not a step to remember by hand).
2. Get each repo's open issue count:
   `gh issue list --repo getmaipai/<repo> --state open --limit 500 --json number --jq 'length'`
3. For each area, write one doc to collection `areas` with
   `doc_id: "<repo>--<slug(area)>"` (lowercase, non-alphanumeric to `-`) and
   **this exact shape** - `dashboard.html`'s live view groups docs by `repo`,
   so every field below must be present, not just the parser's own output:
   ```json
   {"repo": "<repo>", "area": "<area>", "phase": "<phase>", "status": "<green|yellow|red>",
    "done": 0, "open": 0, "built": ["..."], "missing": ["..."], "updated_at": "<ISO timestamp>"}
   ```
   For each repo, one doc to collection `repos` with `doc_id: "<repo>"`:
   `{ repo, phase, open_issues, issues_url, updated_at }`. Use the
   `Artifact` tool's `write_db` with `db_op: "batch"` against the dashboard
   URL above - one batch call for everything, not one write per doc.
5. Do not touch the HTML unless the visual layout itself needs to change.

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

## When to run it

Per [`CLAUDE.md`](../../CLAUDE.md) > Backlog and status: whenever a
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
