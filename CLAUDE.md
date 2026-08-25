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
  iris, juniper, lucia, marlow, marsh, mopey, nadia, nova, oliver, pippa,
  pixel, quill, raven, riff, rivet, rover, sage, serena, sprout, tempo,
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

## READMEs

Every repo follows the README skeleton in [docs/STYLE.md](docs/STYLE.md):
logo + one-line promise, user-voice pitch, generated screenshot strip, Get
started link, the three doc links (User / Developer / API), license line.
READMEs are user-tier writing: the dad test applies, and the AI writing
standards above apply everywhere.

## Stack

See [STACK.md](STACK.md). New work uses the standard stack; a deviation needs
a written justification in that repo's dev docs.
