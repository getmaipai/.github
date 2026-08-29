# MaiPai org standards

Standards for every repo in the `getmaipai` org. Each repo's own CLAUDE.md holds
only project specifics; everything here applies org-wide. If a repo file
contradicts this one, the repo file wins for that repo, but flag the conflict.

## The products

| Repo | Product | What it is |
|---|---|---|
| `home` | MaiPai Home | The self-hosted family AI hub (backend + web frontend + desktop + firmware) |
| `go` | MaiPai Go | Apple TV and iPhone client. Ground-up rewrite in progress, planned first |
| `bot` | MaiPai Bot | Robot companion. Pre-hardware, design phase |
| `.github` | (this repo) | Org standards, shared Claude plugin, org profile |

MaiPai's promise: private, local AI that's actually yours. Nothing leaves the
home. Every technical and product decision honors that.

Product descriptions come verbatim from [brand/COPY.md](brand/COPY.md), the
single source for pitch copy (repo description fields, org profile, READMEs,
docs). Logos come from [brand/](brand/), never redrawn.

## Git workflow

- **All work lands directly on `main`. Never open pull requests.** The remote is
  publishing and backup, not a review step.
- **Never create a branch or worktree** unless Jesse explicitly asks, or a
  second session is actively editing the same repo in parallel. If one was
  needed, merge it and delete it before the session ends. A branch that
  outlives its session is a bug. If you notice a stray branch or worktree,
  flag it for cleanup.
- **Commit only completed, verified work** (see Verification below). One commit
  per logical change. No checkpoint commits, no WIP commits: if work is
  unfinished at session end, the honest state is a dirty tree plus a status
  note, not a commit.
- **Push at natural boundaries** (end of a work session, or when Jesse says
  ship), never reflexively after every commit.
- **Deploys and releases are always explicit.** Cutting a release or rolling
  the hub requires Jesse's word in the moment.
- **Author identity:** Jesse's name is public and fine. His email is not:
  commits use the GitHub noreply address, and no personal email ever appears
  in code, docs, or package metadata.

## Verification (definition of done)

- Every repo exposes **`scripts/check.sh`**: lint + format check + tests +
  gitleaks + the PII wordlist scan (below). It must pass before any commit.
- "Verified" also means **exercised for real**: the feature was hit in the
  running app, the build installed on the target device, or the tests cover
  the change. "It compiles" is not verified.
- At release time, the release skill additionally does a **clean-clone build**
  (fresh clone in a temp dir must build and boot) to catch works-on-my-machine
  and over-eager gitignore mistakes.

## Documentation

- **Claude writes all documentation prose.** Jesse gives feedback,
  instructions, and occasionally a sentence to work in verbatim; he never
  types documentation himself. Never ask permission to document.
- **Docs update in the same commit as the change they describe.** A commit
  that changes behavior while the docs still describe the old behavior is
  incomplete.
- **Three tiers**, per [docs/STYLE.md](docs/STYLE.md):
  - `user/`: for dads with basic tech knowledge. Grade-6 reading level, no
    jargon, one action per step, screenshots over prose.
  - `dev/`: fully technical. Architecture, contributing, decisions.
  - `api/`: generated, never hand-written (next point).
- **APIs are self-documenting:** Hono routes defined with Zod schemas via
  `@hono/zod-openapi`, producing an OpenAPI spec served with an interactive
  explorer at `/api/docs`. Any route you touch gets converted to this style
  as part of touching it.
- **Screenshots are generated, never hand-taken:** a scripted run against a
  seeded demo household (see Privacy). If a screenshot is stale, fix the
  script, not the image.
- **Every screenshot gets looked at before it is used, anywhere.** Open the
  image (Read it) and confirm it shows what it claims: the intended screen,
  with real content, no spinner, skeleton, empty state, error banner, or
  wrong route. A picture of a loading spinner where the Videos app should
  be is not a screenshot of the Videos app. This applies to docs, READMEs,
  issues, and screenshots shown to Jesse in chat. A shot that is wrong gets
  its capture fixed (wait for content, seed data, add an action) and is
  re-taken; it is never embedded, posted, or described as if it were right.

## Writing style (AI writing standards)

Everything we write should read like a sharp human wrote it, not a model.
These apply to docs, UI copy, comments, commit messages, changelogs, issues.

- **No em dashes (U+2014), ever.** Use a comma, colon, parentheses, or a
  period. En dashes only for numeric ranges. This is the number one
  machine-generated tell.
- **No AI filler vocabulary:** delve, seamless, robust, leverage, empower,
  elevate, streamline, game-changer, "in today's world", "it's important to
  note". Say the plain thing instead.
- **No "not just X, it's Y" constructions**, no rhetorical questions as
  transitions, no exclamation points in technical prose.
- **Bullets are for lists of things, not for prose.** If the bullets read as
  sentences that flow, write a paragraph.
- Prefer concrete over abstract: "boots in 4 seconds" beats "highly
  performant". Numbers, names, and file paths beat adjectives.
- User-facing copy passes the dad test: would a busy parent with basic tech
  knowledge understand it on first read, without feeling stupid?
- **End every reply to Jesse with a status block**: Done (what shipped, and
  whether it is deployed/installed, not just committed), In flight (what is
  still running), Blocked (what cannot proceed, why, and what Jesse must do,
  repeated every turn until unblocked).

## Privacy and PII (hard rules)

- **Never commit:** family member names, home address, phone numbers,
  personal email addresses, credentials or tokens, real LAN IPs or homelab
  hostnames. Jesse's own name is the one allowed exception.
- **Example values:** IPs from documentation ranges (`192.0.2.x`), domains
  `example.com`, and people/persona names ONLY from the roster below.
- **Persona roster** (use for demo households, docs examples, fixtures):
  alfred, astro, atlas, bramble, bruno, clover, cosmo, daisy, ember, indigo,
  iris, juniper, lucia, marlow, marsh, mopey, nadia, nova, oliver, pippa, quill, raven, riff, rivet, rover, sage, serena, sprout, tempo,
  velvet, vincent, willow.
- Homelab details (hosts, containers, IPs, topology) live only in Jesse's
  private homelab repo, referenced but never embedded here.
- `check.sh` enforces this: gitleaks for secrets, plus a word-boundary grep of
  the staged diff against the private wordlist at
  `~/.config/maipai/pii-words.txt` (that file is never committed anywhere).
- Screenshots and seeded demo data must never contain the real family's
  profiles, history, or location.

## Releases

- Semver tags (`vX.Y.Z`), a GitHub Release, and a `CHANGELOG.md` in
  Keep a Changelog format, per repo. **Users touch releases, never `main`.**
- The hub deploys from the latest release tag, not from `main` (so `main` can
  break without breaking the house). Cutting a release is the deploy button;
  re-pointing to the previous tag is the rollback.
- Everything stays `0.x` until the product passes its battle-tested checklist
  (kept in that repo's dev docs); `v1.0.0` means it earned it.
- The `release` skill in the maipai plugin runs the whole ceremony: checks,
  clean-clone build, changelog from commits since the last tag, screenshot
  regeneration, docs drift check, tag, GitHub release.
- **Release notes are the changelog, nothing more.** The only preamble is
  one short quoted line of links (install guide for new users, the update
  page for existing ones, what any attached files are), then "What
  changed". No instruction blocks in release notes, and no workflow ever
  writes a release body: notes own the page.
- Downloadable model packs and large binaries ship as release assets, not
  tracked files.

## Security

- **No push-triggered GitHub Actions in private repos** (billed minutes).
  Public repos may keep cheap tag- or docs-triggered workflows. Checks run
  locally via `check.sh` instead of CI.
- Dependabot alerts on everywhere; Dependabot PRs off (they fight the no-PR
  workflow). Instead: a monthly local dependency sweep, updating and
  re-verifying via `check.sh`.
- Before each release of a private repo, run a security review pass; public
  repos get CodeQL for free.
- Secrets live outside repos (env files on the target machines, the macOS
  keychain locally). `.env.example` documents shape, never values.

## Issues

- Bugs and ideas noticed mid-task get filed as GitHub Issues in that repo,
  even when not being fixed now. GitHub Issues are the tracker of record for
  getmaipai repos (they mirror to Gitea automatically). Jesse's Gitea remains
  the tracker for homelab matters.

## Compatibility

- The hub API serves multiple clients (Go, Desktop, firmware pods) that
  update on different schedules. **API changes are additive**: never remove
  or repurpose a field or endpoint the clients rely on without a versioned
  path and a migration note in the changelog.

## Privacy architecture (the promise, kept structurally)

"Nothing leaves your house" is the product. These rules keep it true:

- **Zero phone-home, ever.** No analytics, telemetry, crash reporting, usage
  pings, or unique identifiers are sent to us or to any third party we
  choose, in any product, under any setting. Local stats stored in the
  user's own database are fine and are not telemetry.
- **No MaiPai-operated service ever sits in a user data path.** No relays,
  proxies, sync servers, or cloud accounts. Org web properties (docs sites,
  the org page) are static and carry no trackers.
- **Outbound connections are user-serving and transparent.** The app talks
  to the network only to serve the user: update checks, on-demand model and
  dependency downloads, and integrations the user enabled. An integration
  that identifies the user (their YouTube account, their location for
  weather) is opt-in, connects directly from their hub to that service with
  credentials stored locally, and never transits anything of ours.
- **Every product keeps a user-tier privacy page** with the "what leaves the
  house" table: each outbound connection, when it happens, what it carries,
  and who receives it. Plain dad-test language. Adding or changing an
  outbound endpoint updates this page in the same commit, no exceptions
  (this is the docs-with-the-change rule applied to privacy).

## Trademarks and platform references

Standing editorial rules for any mention of third-party platforms (YouTube,
TikTok, Plex, Spotify, Reddit, and the rest) anywhere: code, docs, UI copy,
READMEs, release notes, commit messages, issues.

- **Names only, descriptively.** Third-party names may be used to state
  compatibility ("connects to YouTube"), never in product or feature branding,
  app names, icons, or logos. No platform logos or brand assets in any repo,
  ever.
- **Every product README carries the standard disclaimer block**, kept
  word-for-word consistent across repos: MaiPai is open-source software for
  personal, self-hosted, non-commercial use by you and your household; it is
  not affiliated with, endorsed by, or sponsored by any platform it can
  connect to; all product names and trademarks belong to their respective
  owners; you are responsible for complying with the terms and laws that
  apply to you and the services you access. The release skill checks the
  block is present and current before cutting a release.
- **Banned vocabulary in all copy:** "bypass", "free <platform> content",
  "ad-free <platform>", "without limits", "avoid paying", or any phrasing
  that pitches a MaiPai feature as a way around another service's rules or
  pricing. Describe what MaiPai is (a private family hub for your own media
  and accounts), not what it gets around.
- **Integrations are described, not branded:** "YouTube integration" as a
  descriptive phrase is fine; "MaiPaiTube" or platform-styled UI is not.
- **No borrowed trade dress.** A platform's distinctive visual identity is as
  off-limits as its logo: signature brand colors used as identifiers
  (YouTube's red on a play control, Spotify's green on anything audio,
  Netflix-red accents on a video shelf), containered icon shapes (the rounded
  red play-button tile), typography lockups, or screen layouts recognizable
  as a specific app's look. MaiPai surfaces use MaiPai's own palette and
  iconography everywhere, including for integration tiles: an integration is
  represented by a generic glyph (a play triangle, a music note) in MaiPai
  colors plus its written name, never by an imitation of the platform's mark.
  Colors as plain colors are fine (red exists); what's banned is using a
  brand's color-plus-shape combination where users would read it as that
  brand.
- **How strict: conventions are free, signatures are not.** UI patterns found
  across three or more competing apps (thumbnail card grids, focus/hover
  autoplay previews, duration badges, watched-progress bars, category
  shelves, vertical short-video feeds, "continue watching" rows) are industry
  conventions: use them freely. An element that lives in one app and evokes
  it is a signature: skip it. Two tests: the convention test above, and the
  squint test (if a glance from the couch could mistake the screen for the
  other app, it's too close; if it just reads "a streaming app", it's fine).
  The craft rule: copy the function, restyle the form in MaiPai's own
  palette, shapes, and type.
- **Section and feature naming in our UIs:** generic descriptive names
  (Trending, Popular, Subscriptions, Continue watching) are always fine, and
  so is honestly labeling a source section with the platform's name
  ("YouTube", with a generic glyph). Prefer plain English over a platform's
  branded jargon for features: "Short videos", not "Shorts". Platform
  taxonomy displayed as data (their category names on their content) is data,
  not branding.
- **Trademark and copyright symbols:** don't sprinkle them. Third-party names
  appear unmarked in running text; the README disclaimer block covers
  attribution once. Our own marks carry no ™ for now, and never ® (that
  requires an actual registration). Copyright is the "Copyright (c) <years>
  Jesse Torres" line in each LICENSE; no per-file headers, no © elsewhere.
- When writing anything that touches these rules and the right wording is
  unclear, flag it for Jesse instead of improvising.

## Safety invariants (generation features)

MaiPai gives adults full control of their own local AI. Two things are not
controls, they are architecture:

- **Child-safety protections on generation and chat are non-removable.** No
  admin setting, config flag, environment variable, or "advanced mode" may
  disable or weaken them, including for the household's own admin. Code
  review treats any change that makes them bypassable as a correctness bug
  of the highest severity. These protections and their design may be
  documented publicly; they are a feature, not a liability.
- **Child profiles are restricted by default.** Unrestricted generation and
  chat are unlocked per-user by an adult, never inherited, never the default
  for a new profile. Safe-by-default, adult-opt-in.
- No feature is built whose purpose is generating imagery of identifiable
  real people.

Marketing and copy rule (all tiers, all repos): never pitch generation
features as "uncensored", "unfiltered", "no restrictions", or any
filter-bypass framing. The honest pitch is the one we mean: your hardware,
your rules; no cloud company deciding for your family; parents decide what
kids can access.

Adult freedom comes with three standing pieces:

- **AI-outputs disclaimer** in every product README (joining the standard
  disclaimer block) and in the product's first-run: outputs come from
  third-party models the user chooses to download; they can be wrong,
  offensive, or harmful; they are not medical, legal, or professional
  advice; the user is responsible for how they use them.
- **One-time adult acknowledgment to unlock unrestricted mode**: a single
  clear dialog, per adult, stating that unrestricted mode answers without
  filters and that what they do with it is their responsibility. One
  confirmation, no legalese ceremony, never repeated.
- **Crisis resources: offer, never block.** When self-harm intent appears in
  a conversation, the app adds crisis resources (988 and local equivalents)
  alongside the conversation without blocking or censoring what an adult can
  discuss. This overlay is part of the safety architecture: it is not
  configurable off.

Neutrality rule: MaiPai ships neutral. No jailbreak presets, no
harm-optimized prompt packs, nothing that curates toward dangerous uses.
Users bring their own models and their own intentions.

Licensing note: no acceptable-use restrictions get added to our license
(added restrictions are incompatible with AGPL-3.0). The README disclaimer
and the models' own licenses carry use responsibility, which rests with the
user.

## Licensing

- **Every repo carries a LICENSE from its first commit: AGPL-3.0.** It fits
  the MaiPai promise (anyone who runs or hosts a modified version must share
  their changes) and it applies to private repos too, so nothing scrambles
  for a license on the day it goes public.
- **Every repo with third-party components carries a NOTICE file** listing
  required attributions. The release skill checks NOTICE against dependency
  changes since the last tag; new components with attribution requirements
  get added before the release cuts.
- READMEs state the license in one line at the bottom, linking to LICENSE.
- Never vendor code whose license is incompatible with AGPL-3.0; when in
  doubt, flag it to Jesse before adding the dependency.
- **Copyright stays 100% with Jesse (dual-licensing and sale stay possible):**
  - Every LICENSE carries the line "Copyright (c) 2026 Jesse Torres" (update
    the year range at each release that touches it).
  - **Never merge an outside contribution without a signed copyright
    assignment.** No exceptions, however small the patch. A drive-by fix
    without paperwork gets reimplemented from the issue description instead
    of merged.
  - Because Jesse is sole copyright holder, he is not bound by the AGPL
    himself: commercial licenses can be sold separately, and the project can
    be sold outright (already-published versions remain AGPL forever).

## Third-party services: we are the user (hard rules)

MaiPai is the family's assistant, so toward YouTube, Reddit, TikTok, Vimeo,
Plex, Google, the weather API and every other service it talks to, **it behaves
as the user would, only automated**. It never behaves like a scraper. YouTube
walled the hub's home IP on 2026-08-28 because the server's own background
fan-out (discovery expansion, suggestion pools, warm-aheads, transcripts) far
exceeded what a person could ever generate; every family member's player was
dark for a day. These rules exist so that never repeats, on any service.

- **A person's pace.** Budget every service to what one engaged human does:
  a page every few seconds, not dozens a second. Every integration gets a
  rate limiter (token bucket) at its single choke point, and all traffic to
  that service goes through it - never a raw fetch on the side.
- **Only what the user asked for, or would see next.** Foreground requests
  serve the screen in front of someone. Background work (warming, expanding,
  building pools, enriching) is bounded, staggered, and stops entirely when
  the service pushes back. No fan-out that multiplies per item (related-of-
  related, all-pages-now, every-thumbnail-now).
- **Prefer the front door.** A signed-in official session (the user's linked
  account, the platform's own feed, its official API with a token) beats
  anonymous scraping every time: it is what the user's own app would do, it is
  rate-limited generously, and it does not get the address flagged. Anonymous
  access is the fallback, never the plan.
- **Back off on the first signal.** A 429, a captcha, a "confirm you're not a
  bot", a LOGIN_REQUIRED where none is expected: stop that class of traffic
  immediately (quiet mode), keep only user-initiated requests, probe on a
  schedule, and resume only when the service is answering normally. Never
  retry through a block.
- **Look like the user's client, honestly.** Real user agents, the client's
  own headers, one identity per household session. No header spoofing tricks
  beyond what the platform's own app sends, no rotating identities, no
  proxies-as-evasion. If a service says no, the answer is to ask less, sign
  in properly, or drop the feature - not to sneak around it.
- **Cache like a client.** Once fetched, keep it (TTL by how fast it changes).
  A refresh is a user action or a slow schedule, never "on every render".
- **Prove it before shipping.** Any feature that adds traffic to a service
  states its request budget in the PR/commit message and is checked against
  the limiter; any block seen in prod is written up (cause, budget, fix) in
  the repo's dev docs so the lesson stays.

## Third-party code and assets (download, don't vendor)

Our repos contain our work. Other people's work arrives through a manager or
a download, never by copying it into the tree.

- **Code dependencies** come via the package manager (bun, uv, Swift PM) with
  a lockfile. Never copy a library's source into the repo.
- **Third-party models, binaries, and datasets** (wakeword base models,
  transcoders, reference data) are fetched by the app on demand: pinned
  version, pinned URL, checksum verified, with a clear failure message when
  offline. The hub's self-healing download system is the pattern.
- **Only artifacts we created may be tracked**: the MaiPai-trained wakeword
  model yes, upstream base models no. Even our own large artifacts ship as
  release assets rather than tracked files (see Releases).
- **Exceptions are allowed but expensive on purpose:** a copied snippet or
  file requires AGPL-compatible licensing, a NOTICE entry, a source comment
  saying where it came from, and a justification in the repo's dev docs. If
  that feels like too much ceremony for the snippet, that's the point:
  download it, depend on it, or reimplement it.

Why this is a hard rule: it keeps the copyright story clean (sole ownership,
dual-licensing stays possible), keeps repos small, and means upstream fixes
arrive by bumping a version instead of hand-merging vendored copies.

## READMEs

Every repo follows the README skeleton in [docs/STYLE.md](docs/STYLE.md):
logo + one-line promise, user-voice pitch, generated screenshot strip, Get
started link, the three doc links (User / Developer / API), license line.
READMEs are user-tier writing: the dad test applies, and the AI writing
standards above apply everywhere.

## Stack

See [STACK.md](STACK.md). New work uses the standard stack; a deviation needs
a written justification in that repo's dev docs.
