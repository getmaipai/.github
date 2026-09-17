---
name: status-dashboard
description: Refresh the MaiPai Build Status dashboard (an Artifact) from every repo's docs/BACKLOG.md and open GitHub issue counts. Use whenever a docs/BACKLOG.md changes, at latest before a session ends, or when Jesse asks for the dashboard to be brought current.
---

# Refresh the build status dashboard

The dashboard is a published Artifact at
**https://claude.ai/code/artifact/68f69163-11ad-40ca-a272-9bc46759bbc2**
("MaiPai Build Status"). It reads live from its own shared `db` (collections
`areas` and `repos`) - refreshing it is a `write_db` call, never a redeploy.
Redeploy `dashboard.html` only for a layout/design change, not a data refresh.

Source of truth is each repo's `docs/BACKLOG.md` (see
[`CLAUDE.md`](../../CLAUDE.md) > Backlog and status) - this skill is a
derived view, never a second place status gets decided.

## Process

1. For each repo (`home`, `bot`, `catalog`, `go`, `stack`), run the parser:
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
