# The architect gate

Dev tier. ARCH-GATE-01, owner-approved 2026-10-02.

## The problem

Home's design drifted. Sessions wrote new decision records without reading
the earlier ones, and later patches overrode an accepted design: 22
contradictions were found on 2026-10-02. A human team prevents this with an
architect, who reads a proposed change against the design and turns it away
before it is built. This gate gives the repos the same step.

## The rulebook

Each repo keeps one rulebook, `docs/design/RULES.md`: numbered hard rules,
grouped under `## Area` headings. It is the authority. `docs/dev.md` and
`docs/plans/` are history and reasoning. Each area has:

```
## Chat turn

Record: [the thin chat path](../plans/chat-thin-path-2026-10-02.md), accepted 2026-10-02.
Governs: backend/chat/**, docs/design/chat*.md

1. The first rule.
```

`Record:` names the design record that argues for the area's rules (links
resolve relative to `docs/design/`). `Governs:` is optional: a
comma-separated list of path globs for the code and docs the area's rules
cover (`**` crosses directories, `*` does not). A commit touching a governed
path needs a verdict. Every record carries a `## Supersedes` section naming
what it replaces, or "Nothing."

## The four verdicts

The `architect` agent (`plugin/agents/architect.md`, sonnet) takes a
proposal (a backlog item, a design note, a work order or a diff), the repo
path and an item id. It reads RULES.md, BACKLOG.md and only the records the
proposal touches, and returns exactly one verdict:

- `APPROVED`: fits every rule, duplicates nothing.
- `REJECTED`: breaks a rule; the verdict quotes the rule number and text.
- `DUPLICATE`: the backlog already covers it; the verdict cites the id.
- `NEEDS-RULE-CHANGE`: reasonable, but the rule as written forbids it; goes
  to the owner.

It also rejects a design note that changes behaviour without a
`## Supersedes` section. It writes the verdict to
`<repo>/data-scratch/architect/<ITEM-ID>.verdict` (git-ignored): item,
verdict, rules cited, sha256 of the proposal or of `git diff --cached`,
UTC timestamp, model.

## Three enforcement points

1. **Dispatch.** The `coordinate` skill dispatches no item without an
   `APPROVED` record for its id.
2. **Commit.** `plugin/hooks/scripts/require-architect-verdict.sh` denies a
   commit that stages `docs/design/**`, `docs/plans/**`, `docs/BACKLOG.md`
   or a `Governs:` path unless a fresh (24 hours) `APPROVED` record matches
   the item id in the commit message or the staged diff hash. A commit that
   stages RULES.md itself needs `Owner-approved: YYYY-MM-DD` in its message.
   Every denial names the remedy.
3. **Gate.** `standards/bin/architect-check.sh`, run by `check-core.sh`:
   every area names an existing record, every named record has a
   `## Supersedes` heading, and every `> **Superseded` marker in `docs/`
   links to a file that exists.

## What the architect never does

It never edits a rule, a record, the backlog or code. It never approves
around a rule, rules from an older document the rulebook overrides, or
decides a question the rulebook is silent on (that is `design-resolver`'s
research, or the owner's call).

## How a rule changes

Only the owner changes a rule. The change is made in RULES.md, names the
design record that argues for it, and that record lists what it supersedes.
The commit message carries `Owner-approved: <date>`. A session that needs a
different rule asks for it as a NEEDS-RULE-CHANGE request; it does not edit
the file.
