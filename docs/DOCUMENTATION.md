# Documentation, writing style and the status block

Dev tier. Full text of the documentation rules, the AI writing standards (including the status block in full) and the README rule. Load before writing user docs, READMEs, screenshots, build guides, or a status block with several sessions.

## Claude writes all documentation prose

**Claude writes all documentation prose.** Jesse gives feedback,
instructions, and occasionally a sentence to work in verbatim; he never
types documentation himself. Never ask permission to document.

## Docs update in the same commit

**Docs update in the same commit as the change they describe.** A commit
that changes behavior while the docs still describe the old behavior is
incomplete.

## Build guides use final parts

**Build guides use the final parts, never interim ones.** A step uses the
part, cable, or mount the finished product uses, so nothing is redone
later. An interim part appears only with a stated reason on the page and
a note on what replaces it and when.

## No owner-specific notes in docs

**Never put owner-specific notes in the docs.** Anything that exists only
because of Jesse's own setup or inventory ("check whether your drive is
SATA or NVMe", "note it for the hardware record", "tell us which one
worked", his hosts, his parts' quirks) stays out of every tier. Docs
address a reader who has the product or bought the listed parts. Owner
reminders go in the session status block or a GitHub issue.

## Scratch and private notes

**Scratch and private notes live inside the repo they belong to, in a
git-ignored folder** (`home` uses `data-scratch/`, covered by its
`data-*/` ignore rule), never at the org root, never above it. The
folder above the org is the source-control service's; the org root
holds only the repos, the standards checkout, and the two symlinks.
A throwaway gate worktree is created beside the repo for one gate and
removed the moment it ends.

## Three tiers

**Three tiers**, per [docs/STYLE.md](docs/STYLE.md):
- `user/`: for dads with basic tech knowledge. Grade-6 reading level, no
  jargon, one action per step, screenshots over prose.
- `dev/`: fully technical. Architecture, contributing, decisions.
- `api/`: generated, never hand-written (next point).

## APIs are self-documenting

**APIs are self-documenting:** Hono routes defined with Zod schemas via
`@hono/zod-openapi`, producing an OpenAPI spec served with an interactive
explorer at `/api/docs`. Any route you touch gets converted to this style
as part of touching it.

## Screenshots are generated, never hand-taken

**Screenshots are generated, never hand-taken:** a scripted run against a
seeded demo household (see Privacy). If a screenshot is stale, fix the
script, not the image.

## Every screenshot is looked at before use

**Every screenshot gets looked at before it is used, anywhere.** Open the
image (Read it) and confirm it shows what it claims: the intended screen,
with real content, no spinner, skeleton, empty state, error banner, or
wrong route. A picture of a loading spinner where the Videos app should
be is not a screenshot of the Videos app. This applies to docs, READMEs,
issues, and screenshots shown to Jesse in chat. A shot that is wrong gets
its capture fixed (wait for content, seed data, add an action) and is
re-taken; it is never embedded, posted, or described as if it were right.

## READMEs

Every repo follows the README skeleton in [docs/STYLE.md](docs/STYLE.md):
logo + one-line promise, user-voice pitch, generated screenshot strip, Get
started link, the three doc links (User / Developer / API), license line.
READMEs are user-tier writing: the dad test applies, and the AI writing
standards above apply everywhere.

## Writing style: intro

Everything we write should read like a sharp human wrote it, not a model.
These apply to docs, UI copy, comments, commit messages, changelogs, issues.

## Writing style: no em dashes

**No em dashes (U+2014), ever.** Use a comma, colon, parentheses, or a
period. En dashes only for numeric ranges. This is the number one
machine-generated tell.

## Writing style: no filler vocabulary

**No AI filler vocabulary:** delve, seamless, robust, leverage, empower, elevate, streamline, game-changer, "in today's world", "it's important to note". Say the plain thing instead. <!-- prose-lint: allow -->

## Writing style: no padded contrasts

**No "not just X, it's Y" constructions**, no rhetorical questions as transitions, no exclamation points in technical prose. <!-- prose-lint: allow -->

## Writing style: bullets

**Bullets are for lists of things, not for prose.** If the bullets read as
sentences that flow, write a paragraph.

## Writing style: concrete over abstract

Prefer concrete over abstract: "boots in 4 seconds" beats "highly
performant". Numbers, names, and file paths beat adjectives.

## Writing style: the dad test

User-facing copy passes the dad test: would a busy parent with basic tech
knowledge understand it on first read, without feeling stupid?

## The status block (2026-09-14 shape, words fixed 2026-09-27)

**End every reply to Jesse with the status block** (2026-09-14
shape, words fixed 2026-09-27): three lines, uppercase labels, in
this order, nothing after it. `STATE:` opens with exactly one of
four words, each meaning one thing:
- `done`: everything asked for has landed, nothing is running,
  nothing is owed by anyone. The reply can be the last one.
- `active`: work is running right now (a session, an agent, a
  gate, a bench), and it will report on its own.
- `waiting [<what>]`: work is stopped until a named thing happens
  that is not Jesse's to do (a gate slot, a peer's push, a
  lane's report). The bracket is mandatory: a bare `waiting` is a
  defect, because it reads as "waiting on you" (2026-09-27, a
  finished session wrote `waiting` for lack of an idle word and
  Jesse read it as something still owed).
- `blocked [<owner>: <what>]`: work has stopped and cannot restart
  until the named owner does the named thing. Used only when work
  has stopped; a fact that stops nothing is never a block.
After the word, each session with its item and condition in
parentheses (running with a time, holding and behind what,
blocked), and `landed <item>` when something shipped since the
last block. `PROGRESS:` the path to the current milestone on one
line: its name, a bar of done and remaining items, the count, `now`
and `next` in order. `YOU:` the only place an ask ever appears:
`nothing`, or each ask tagged `(whenever)` or `(blocking: <what it
holds>)`, written so a reader who saw no earlier message can act on
it (the exact command or decision, never "still yours"). `STATE:
done` and `YOU: nothing` go together: if `YOU:` carries an ask the
state is not `done`, and if the state is `done` there is nothing
left to ask.
