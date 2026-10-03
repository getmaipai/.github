# Releases, security and third-party code

Dev tier. Full text of the release, security, compatibility and third-party code rules. The `release` skill runs the ceremony. Load before cutting a release, adding or copying a dependency, changing CI, or changing a hub API.

## Releases: tags, GitHub Release, changelog

Semver tags (`vX.Y.Z`), a GitHub Release, and a `CHANGELOG.md` in
Keep a Changelog format, per repo. **Users touch releases, never `main`.**

## Releases: the hub deploys from the latest tag

The hub deploys from the latest release tag, not from `main` (so `main` can
break without breaking the house). Cutting a release is the deploy button;
re-pointing to the previous tag is the rollback.

## Releases: stay 0.x until battle-tested

Everything stays `0.x` until the product passes its battle-tested checklist
(kept in that repo's dev docs); `v1.0.0` means it earned it.

## Releases: the release skill

The `release` skill in the maipai plugin runs the whole ceremony: checks,
clean-clone build, changelog from commits since the last tag, screenshot
regeneration, docs drift check, tag, GitHub release.

## Releases: notes are the changelog

**Release notes are the changelog, nothing more.** The only preamble is
one short quoted line of links (install guide for new users, the update
page for existing ones, what any attached files are), then "What
changed". No instruction blocks in release notes, and no workflow ever
writes a release body: notes own the page.

## Releases: large binaries are release assets

Downloadable model packs and large binaries ship as release assets, not
tracked files.

## Security: no push-triggered Actions in private repos

**No push-triggered GitHub Actions in private repos** (billed minutes).
Public repos may keep cheap tag- or docs-triggered workflows. Checks run
locally via `check.sh` instead of CI.

## Security: Dependabot and the monthly sweep

Dependabot alerts on everywhere; Dependabot PRs off (they fight the no-PR
workflow). Instead: a monthly local dependency sweep, updating and
re-verifying via `check.sh`.

## Security: review pass before a private release

Before each release of a private repo, run a security review pass; public
repos get CodeQL for free.

## Security: secrets live outside repos

Secrets live outside repos (env files on the target machines, the macOS
keychain locally). `.env.example` documents shape, never values.

## Compatibility: API changes are additive

The hub API serves multiple clients (Go, Desktop, firmware pods) that
update on different schedules. **API changes are additive**: never remove
or repurpose a field or endpoint the clients rely on without a versioned
path and a migration note in the changelog.

## Third-party code: intro

Our repos contain our work. Other people's work arrives through a manager or
a download, never by copying it into the tree.

## Third-party code: dependencies via a package manager

**Code dependencies** come via the package manager (bun, uv, Swift PM) with
a lockfile. Never copy a library's source into the repo.

## Third-party code: models, binaries and datasets are fetched

**Third-party models, binaries, and datasets** (wakeword base models,
transcoders, reference data) are fetched by the app on demand: pinned
version, pinned URL, checksum verified, with a clear failure message when
offline. The hub's self-healing download system is the pattern.

## Third-party code: only artifacts we created are tracked

**Only artifacts we created may be tracked**: the MaiPai-trained wakeword
model yes, upstream base models no. Even our own large artifacts ship as
release assets rather than tracked files (see Releases).

## Third-party code: exceptions are expensive on purpose

**Exceptions are allowed but expensive on purpose:** a copied snippet or
file requires AGPL-compatible licensing, a NOTICE entry, a source comment
saying where it came from, and a justification in the repo's dev docs. If
that feels like too much ceremony for the snippet, that's the point:
download it, depend on it, or reimplement it.

## Third-party code: why

Why this is a hard rule: it keeps the copyright story clean (sole ownership,
dual-licensing stays possible), keeps repos small, and means upstream fixes
arrive by bumping a version instead of hand-merging vendored copies.
