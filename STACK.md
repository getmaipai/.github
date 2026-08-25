# MaiPai tech stack standard

New work uses this stack. Deviating is allowed only with a written
justification in that repo's dev docs.

## Backend (MaiPai Home)

| Layer | Standard |
|---|---|
| Runtime | Bun |
| HTTP framework | Hono, routes defined with Zod schemas via `@hono/zod-openapi` |
| Validation | Zod (the same schemas that generate the OpenAPI spec) |
| Database | SQLite via Drizzle ORM |
| API docs | Generated OpenAPI spec + interactive explorer at `/api/docs` |

## Frontend (MaiPai Home web)

| Layer | Standard |
|---|---|
| Framework | React + Vite (TypeScript) |
| Styling/components | The shared component catalog in `home`'s agents.md; build from it before building new |

## Desktop (MaiPai Desktop)

Electron + electron-builder, unsigned phase-1 builds (ad-hoc signed on arm64).

## TV / Phone (MaiPai Go)

SwiftUI (tvOS + iOS), project generated with xcodegen, built locally with
`scripts/build_local.sh` style tooling, sideloaded via atvloadly. Never built
on GitHub Actions (macOS minutes bill 10x).

## Robot (MaiPai Bot)

Python managed with uv; lint and format with Ruff; tests with pytest.

## Docs sites

Astro Starlight, living inside each product repo under `docs/`, published via
GitHub Pages. Three content tiers (`user/`, `dev/`, `api/`) per
[docs/STYLE.md](docs/STYLE.md).

## Cross-cutting tooling

| Concern | Standard |
|---|---|
| Pre-commit gate | `scripts/check.sh` per repo (lint, format, tests, gitleaks, PII wordlist) |
| Screenshots | Playwright against a seeded demo household (web); `xcrun simctl` (Go) |
| Secret scanning | gitleaks locally; GitHub secret scanning on public repos |
| Releases | Semver tags + GitHub Releases + Keep a Changelog, cut by the `release` skill |
| CI | None on push for private repos; cheap tag/docs workflows allowed on public repos |
