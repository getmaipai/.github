---
name: new-package
description: Scaffold a new getmaipai/catalog package (plugin, app, companion, integration, model, wakeword, voice, or theme) with a conforming manifest and the bronze-tier definition of done. Use when starting a new package, or when a legacy feature's review verdict (PACKAGES.md) is "rebuild" or "redesign" and it is time to build it.
---

# Scaffold a new catalog package

Every package is one directory with one manifest, one format for every
kind. Full contract: [docs/PACKAGES.md](../../docs/PACKAGES.md) and the
platform plan section 5.1. This skill produces a package that can reach
bronze, not a finished feature; the routing examples, tests, and README
content still need real work.

## Before scaffolding

1. **Check the review queue first.** If this package rebuilds or redesigns
   a legacy feature, confirm its one-line verdict already exists in the
   fresh repo's dev docs (rebuild as designed / redesign / merge / drop,
   with the reason). No verdict, no package, per the org rule in
   [`CLAUDE.md`](../../CLAUDE.md) > Platform principles, point 8.
2. **Pick the kind and category** from
   [docs/PACKAGES.md](../../docs/PACKAGES.md) and confirm the id is free
   (`^[a-z0-9][a-z0-9_-]{0,63}$`, unique in the catalog, no third-party name
   in it).
3. **Pick the tier.** Tier 0 (a recipe or a prompt body) unless the logic
   genuinely cannot be expressed as `fetch` / `pick` / `format` / `action` /
   `remember` / `schedule`. Most plugins, and every robot plugin by
   default, are Tier 0.

## Scaffold

Directory: `catalog/<kind-plural>/<category>/<id>/` (plugins) or
`catalog/<kind-plural>/<id>/` (apps, companions, integrations, models,
wakewords, voices, themes). Files:

- `manifest.json`: the fields listed in platform plan section 5.1 (id,
  version, kind, category, display, description, author, license,
  homepage, `routing.examples` with five or more, `routing.patterns`,
  `args`, `requires`/`optional` capabilities, `platforms`, `min_role`,
  `consequential`, `offline`, `config[]`, `data_sources[]`,
  `permissions[]`, `notifications[]`, `cache`, `warm`, `backup`,
  `background`, `min_app`, `kit_version`, `reply`, `timeout_ms`, `tier`,
  `smoke`, `quality_scale`).
- `SKILL.md` (Tier 0 prompt body) or `recipe.json` (Tier 0 recipe) or
  `src/mod.ts` (Tier 1, Deno).
- `tests/`: at minimum the conformance/smoke fixture for the tier.
- `README.md` (user tier, this is the store card), `CHANGELOG.md`,
  `docs/dev.md`.
- `LICENSE` (AGPL-compatible; matches the catalog rule, not necessarily
  identical text to the org's own AGPL-3.0), `NOTICE` if bundling anything.
- `icon.svg` (lucide-derived or a generic glyph, never a platform logo).
- `quality_scale.yaml` stating what bronze requires and whether it is met.

## Definition of done before it is proposed for merge

Bronze per [docs/PACKAGES.md](../../docs/PACKAGES.md): tests green
everywhere declared, five or more routing examples, a privacy row per
data source, stated offline behavior, a smoke test, README and changelog
present, lint clean. Do not propose a package below bronze; catalog CI
and the store both refuse it.

## For a community contribution

If this package is not landing directly on `main` by a maintainer, it
needs the signed copyright assignment before it can merge (the one PR
carve-out in the org's git workflow). Point the contributor at
`ASSIGNMENT.md` and `CONTRIBUTING.md` in the catalog repo root.
