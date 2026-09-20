# Packages: definition of done, supply chain, review, CLA

Everything on the hub and robot beyond core is a package: `plugin`,
`skill`, `app`, `companion`, `integration`, `model`, `wakeword`, `voice`,
`theme`, and `module` (declarative kinds). One package is one directory
with one manifest, one format for every kind. Full manifest and file
layout in the platform plan section 5.1; this doc is the standard a
package is held to.
A `plugin` is a self-contained, permissioned, installable capability
(Claude's and, as of 2026, OpenAI's own sense of the word) - deliberately
not called a `skill`. A `skill` is a separate, real declarative kind
(shipped 2026-09-05, `home`'s own dev docs: "The real skill kind,
shipped"): plain instructions only, a `SKILL.md`-shaped file compatible
with Claude's own Skill format, no independent permissions and no
recipe of its own - composed into a chat model's system prompt when
relevant, never executed standalone. Safely user-authorable end to end,
since there is nothing in it to review for permissions or network
access.

A third primitive, `command`, is deliberately **not** in the declarative-
kind list above: it is household-authored at runtime through a settings
flow (`home`'s own dev docs: "The command primitive, shipped"), not a
filesystem package with a manifest and a directory - "when I say X, do
Y," matched by an exact trigger phrase, with one of two fixed action
shapes. It needs no catalog entry, no review, and no CLA, because it
never leaves the household that created it.

## Definition of done

Nothing reaches a machine unproven. Every package carries:

- `tests/`, deterministic and offline on every declared platform (`deno
  test` for code, the conformance runner for recipes, flow fixtures for
  anything over the link, the speech lint on every `speech` string).
- A user-tier `README.md` (its store card) and a `CHANGELOG.md`.
- `quality_scale.yaml` against our tiers:
  - **Bronze** (the publish gate): tests green everywhere, five or more
    routing examples, a privacy row per data source, stated offline
    behavior, a smoke test, README and changelog present, lint clean.
  - **Silver**: diagnostics and reauth for integrations.
  - **Gold**: real-hardware or real-service verification with a date.
- A `smoke` entry that runs where the package will live, at install, at
  every update, and on a schedule. A failure leaves it installed but
  disabled with a Repairs item.

Default packages (ours) are held to the same bar as community ones. The
release skill refuses a default set with a package below bronze. Every real
failure a package causes becomes a package test first, per the org testing
standard in [`CLAUDE.md`](../CLAUDE.md).

## Tiers

- **Tier 0, declarative**: a prompt body, or a recipe interpreted natively
  by the TypeScript and Python interpreters in `home/spec/`. No process.
  Most plugins, and every robot plugin by default.
- **Tier 1, code**: TypeScript under Deno (see [STACK.md](../STACK.md)), for
  what a recipe cannot express. `runtime: wasm` (Extism) is reserved for
  later.

## Supply chain and the store

- **Repo layout** (`getmaipai/catalog`, public): `plugins/<category>/<id>/`,
  `skills/<category>/<id>/`, `apps/`, `companions/`, `integrations/`,
  `models/`, `wakewords/`, `voices/`, `schema/` (mirrored from
  `home/spec/`), `tools/` (lint, pack, sign, index, scorecard, the `check`
  CLI), `AGENTS.md` and package-writing skills so an agent produces a
  conforming package, `ASSIGNMENT.md`, `CONTRIBUTING.md`.
- **The one PR carve-out.** `catalog` is the only repo in the org that
  accepts pull requests (see [`CLAUDE.md`](../CLAUDE.md) > Git workflow).
  Maintainers still land their own work directly on `main`.
- **CI on every PR** (`catalog/.github/workflows/check.yml`): the same
  `scripts/check.sh` a contributor runs locally (manifest and recipe
  lint, the scorecard, the vendoring scan, the licence check and the
  banned-API scan over every package, then the standards core: gitleaks,
  the PII wordlist, the prose lint), the permission diff posted as a
  comment on the pull request, and the CLA check against
  `signers.json`. Still to come: recipe conformance on both
  interpreters, `deno test` against the host emulators, the speech
  lint, and screenshot generation with vision review of store images.
  Merge needs a maintainer review plus the green CLA check.
- **Release and signing**: a tag per package version. The maintainer's
  machine rebuilds from the reviewed commit, packs it, computes the
  sha256, signs it with the offline Ed25519 key, and publishes. The index
  follows TUF: a signed `root` (a second signer from day one, a written
  key-loss recovery), signed `targets` per version (hash, size, source
  commit, signer, `min_app`, requires, permissions, changelog) with
  delegated roles per kind, and a signed `timestamp` with a thirty-day
  expiry produced by a low-value online key on a tag-triggered public
  workflow. Apps refuse an expired or rolled-back index, verify every
  package twice (hash against targets, then the package signature and
  manifest identity), never downgrade without an explicit rollback, and
  hold one pinned store URL.
- **Moderation beyond code**: a companion's prompt may not weaken the
  safety layer; trademarked or platform names are refused in ids and
  names (see the Trademarks section of [`CLAUDE.md`](../CLAUDE.md)); store
  images are generated by CI, never hand-uploaded; an "unlisted" tier
  installs only by direct id; no review SLA is promised; community cards
  carry HACS-style honesty text ("community-made").
- **Tamper suite**: a bad hash, a swapped manifest, an expired timestamp, a
  rolled-back index, and an unknown signer are all refused on hub and
  robot, with a clear message and no partial unpack.

## The copyright assignment (CLA)

Every `catalog` contribution needs the signed copyright assignment before
it merges. No exceptions, however small the patch. A drive-by fix without
paperwork gets reimplemented from the issue description instead of merged,
same as the org's rule for any outside contribution (see the Licensing
section of [`CLAUDE.md`](../CLAUDE.md)).

## Review before rebuild

Every legacy hub feature and every legacy robot plugin is a review-queue
entry, not a spec. Before a package is built, its entry gets a one-line
verdict in the fresh repo's dev docs: rebuild as designed, redesign, merge
with another, or drop, with the reason. "Copy from legacy" applies only to
hard-won logic (resolvers, sync, limiters, drivers, trainers, measurements),
never to feature scope or UI.
