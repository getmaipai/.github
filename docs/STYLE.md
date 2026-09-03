# MaiPai documentation style guide

Three tiers, three audiences, one voice per tier. Claude writes all prose;
Jesse edits and directs. Docs change in the same commit as the code they
describe.

## Tier 1: `user/` (the dad test)

Audience: a busy parent with basic tech knowledge, easily scared off by
jargon. Every page must pass the dad test, and the litmus test: could a
tired parent, phone in one hand and a kid in the other, finish this page in
under two minutes without knowing what a URL path is?

Modeled on how Sonos, Google Nest, and Apple structure consumer help (and
how Plex and Tailscale separate technical content).

**Site organization:**

- The docs front door asks "How can we help?" and offers two modes side by
  side: set something up, and **Fix a problem** (use those three words).
  Above the fold: a short rail of the most common questions.
- Nav groups are named in the user's words (Start here, Everyday use, Your
  family, Privacy &amp; safety, Fix a problem), never in feature-list words.
- Privacy &amp; safety is its own top-level category, never buried in settings.
- Troubleshooting pages phrase headings as conditions the user would say:
  "If it stopped answering", "If your phone can't find it".
- Every page ends with an escalation: "Still need help?" plus one obvious
  next action.
- Developer documentation lives on the same site behind one labeled door
  ("For tinkerers &amp; developers"), collapsed and last. Family-facing pages
  never link into it mid-article.

**Page-writing rules:**

- One task per page, done in one scroll: at most about 7 steps and 300
  words of instruction. Longer means split the page.
- Titles are tasks or questions the user would type ("Add your kid to the
  hub"), never feature-noun piles ("User Provisioning").
- Prerequisites go in a "What you need to get started" block before step 1,
  never as a mid-step surprise.
- Steps name what the user sees and taps, with the on-screen label in bold:
  "Tap **Home Inventory** on the main screen." At most 2 navigation hops
  per step, anchored to something visible.
- State the end state: "You'll know it worked when the setup wizard greets
  you."
- Branches are explicit "If you see A… / If you see B…" forks, never
  "depending on your setup".
- Grade 6 to 8 reading level, short sentences, second person, contractions
  fine. Screenshots (generated, demo household) only where the target is
  hard to find, annotated, not one per step.
- No em dashes, per the org writing rule.

**Banned in user-tier pages** (these belong in the dev tier or nowhere):

- Route paths and URLs as instructions ("Open it at `/home-inventory`",
  "browse to `http://x:3000`"). Name the button instead.
- Env vars, config files, ports, terminal verbs (SSH, logs, containers).
  If the only way to do something is an env var, that is a product gap:
  build the toggle, don't document the variable.
- System-internal nouns in user steps: say "the hub", "the app", "the
  screen", not "the server", "the instance", "the frontend".
- "Simply" and "just": they shame whoever is stuck. Delete them.

## Tier 2: `dev/` (fully technical)

Audience: developers, including future Claude sessions.

- Precise and complete beats friendly. Architecture, data flow, decisions and
  their why, contribution setup, the battle-tested checklist.
- Document constraints the code cannot show (timing, ordering, external
  quirks).
- Keep the repo's agents.md/component catalog authoritative for UI patterns;
  dev docs link to it rather than duplicating it.

## Tier 3: `api/` (generated)

- Never hand-written. The OpenAPI spec generated from the Zod route schemas
  is the single source; the docs site embeds or links the explorer.
- Prose in this tier is limited to orientation: auth, base URLs, versioning
  and compatibility policy.

## READMEs (every repo, same skeleton)

Modeled on how the most-starred self-hosted projects do it (Home Assistant,
Ollama, Jellyfin, Immich, Audiobookshelf): a README is a calm signpost, not
the manual and not a brochure. Restraint signals credibility; the biggest
projects have the shortest, plainest READMEs.

Skeleton, in order:

1. Logo (theme-aware picture element) + one-line identity as an `h3`:
   category plus differentiator ("A private, self-hosted AI hub for
   families.").
2. One row of plain text links: Documentation · Install · Releases.
3. The canonical pitch paragraph (verbatim from brand/COPY.md) plus the
   privacy promise stated as fact, not slogan.
4. Features: one-line bullets, bold keyword only, no adjectives like
   "blazing", 10 to 15 items max.
5. Getting started: ONE command per OS if it truly is one command,
   otherwise a single sentence linking to the install docs. Surface the one
   or two real gotchas (backups) as a short warning block.
6. Status: honest maturity note ("pre-1.0, runs our own household daily,
   expect rough edges").
7. Documentation links (user / developer / API), issues pointer.
8. Development: a short paragraph at the bottom; users never scroll there.
9. License line, then the standard disclaimer block.

Hard limits (the calm budget):

- **Total: about 100 to 150 lines**, user-facing content in the first 60.
- **Images: at most 2** (the logo plus optionally ONE composed hero
  screenshot). Screenshot galleries live on the docs site, never in the
  README.
- **Badges: 4 or fewer, informational only** (license, release, chat).
  Marketing badges ("Private", "Blazing fast") are banned; zero badges is
  fine.
- **No emoji in headings.** No self-praise headings ("Why is this so
  awesome?"). No star-history charts.
- If a section runs longer than its docs page would, move it to docs and
  leave one sentence.

## AI writing standards

The full list lives in [CLAUDE.md](../CLAUDE.md) and applies to every tier: no em dashes, no AI filler vocabulary (delve, seamless, robust, leverage, and friends), no "not just X, it's Y" constructions, bullets only for real lists, concrete beats abstract. If a sentence sounds like a press release, rewrite it like you'd say it to a neighbor. <!-- prose-lint: allow -->

## Platform screenshot pipeline (`home`, `bot`, `go`, `catalog`)

One pipeline and one look for the hub, the robot app, Go, and store cards,
on top of the general screenshot rules in [`CLAUDE.md`](../CLAUDE.md) >
Documentation. Full source: platform plan section 2.3.

- **Fixed viewports**: phone, tablet, desktop, TV, and the Apple sizes.
- **Fixed themes**: the default theme in light and dark, plus High
  Contrast. Never per-theme baselines beyond those three.
- Shell visible in every shot; a generated manifest per shot records the
  capture script, viewport, theme, and date.
- **AI reviews every screenshot, twice.** In a session, open each image
  before using it anywhere and confirm it shows the intended screen with
  real content and no spinner, skeleton, empty state, error, or wrong
  route (this is the org rule in [`CLAUDE.md`](../CLAUDE.md), restated
  here because the platform pipeline generates far more screenshots than a
  single-app repo does). In the pipeline itself, every screenshot carries
  a declared expectation beside its capture script, and a vision-model
  check (the hub's `vision` role, or the dev machine's) answers it and
  fails the build on a miss. The verdict is written into the screenshot's
  manifest with the model and date. A wrong shot gets its capture fixed
  and re-taken, never embedded or described as right.
- Catalog store images get the same check in CI.
- Clipping fails the build: horizontal overflow, text outside its box,
  overlaps, undersized targets, anything wider than the viewport. See
  [UI.md](UI.md) > Responsive layout.

## Build docs (the robot): Instructables style

Build guides are project-specific write-ups, not general tutorials: link
out for generic how-tos (how to solder, what a GPIO pin is) rather than
re-explaining them, and keep one page per build stage. Every stage page
ends in a check that proves the stage actually worked before moving to the
next one. Final parts only, per the org rule in [`CLAUDE.md`](../CLAUDE.md)
> Documentation; no owner-specific notes.

## Docs upkeep and the drift check

Docs update in the same commit as the behavior they describe. The release
skill's drift check refuses a release whose docs, screenshots, privacy
table, or settings reference are older than the code they describe. Every
product keeps the user-tier privacy page with the generated "what leaves
the house" table (see [`CLAUDE.md`](../CLAUDE.md) > Privacy architecture).
Docs sites are Astro Starlight per repo; the catalog's site lists every
package README so the store and the docs are one source.

## Names and examples

People and persona names in any example, fixture, or demo come from the
persona roster in [CLAUDE.md](../CLAUDE.md). IPs from `192.0.2.x`, domains
from `example.com`. Never real family data, never real homelab details.
