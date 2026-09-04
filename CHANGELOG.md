# Changelog

Tracks `@maipai/standards` releases (`std-vX.Y.Z` tags), the one
versioned, tagged artifact in this repo. Format follows
[Keep a Changelog](https://keepachangelog.com); versions follow semver.
Everything else in `.github` (org docs, the `maipai` plugin, brand
assets) changes with ordinary commits and isn't separately versioned.

## [Unreleased]

Nothing since std-v0.2.0.

## [std-v0.2.0] - 2026-09-04

### Added
- The five cross-cutting schemas platform plan 2.1 lists: `error-entry`,
  `logging-line`, `trace-span`, `budget`, `privacy-row`, each as JSON
  Schema 2020-12 with generated Zod and Pydantic v2 bindings and a
  fixture round-trip test. Meant to be imported cross-repo by `$ref`;
  `home/spec/` does this for `error-entry` and `privacy-row`.

## [std-v0.1.0] - 2026-09-03

### Added
- `bin/check-core.sh`: the shared `check.sh` core (gitleaks, the PII
  wordlist scan, the prose lint with its `<!-- prose-lint: allow -->`
  escape, the licence check), pinned by `.github`, `home`, `bot`, and
  `catalog`.
- Plugin skills `new-package`, `standards-check`, `verify-screenshots`.
- The platform standards docs this package enforces: `docs/PACKAGES.md`,
  `docs/UI.md`, `docs/SETTINGS.md`, `docs/ENGINEERING.md`,
  `docs/UPDATES.md`, `docs/BACKUPS.md`, `docs/NOTIFICATIONS.md`, and
  extensions to `CLAUDE.md`, `STACK.md`, and `docs/STYLE.md`.
