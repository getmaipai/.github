# Engineering standards every package inherits

These bind `home` core, every `catalog` package, and the robot's equivalent
surfaces. Full source: platform plan section 2.2. Where an org rule already
covers a topic in general (privacy, credentials, safety, licensing,
trademarks), see [`CLAUDE.md`](../CLAUDE.md); this doc adds the
platform-specific mechanics (how a package declares and is held to each
standard).

## Design tokens

One token set for light and dark, MaiPai palette only, the four-stop brand
gradient reserved for hero moments, fixed type and spacing scales, named
motion. No raw values in packages. Enforced by the kit lint.

## Icons

lucide only, referenced by name. Integrations get a generic glyph plus
their written name. No platform logos or trade dress (see the Trademarks
section of [`CLAUDE.md`](../CLAUDE.md)). Enforced by the kit and catalog
lint.

## Layout and chrome

The shell owns all chrome; apps contribute typed blueprints and compose
page bodies from layout primitives. Enforced by the kit lint. See
[UI.md](UI.md).

## Accessibility

Radix keeps keyboard and screen-reader semantics; contrast comes from
tokens; every control is labeled; TV and remote focus rules apply; reduced
motion is honored. A screen-reader and keyboard-only pass on the hub runs
per release, not only an axe pass in CI.

## Copy and voice

The dad test, no AI filler, no em dashes, no exclamation points in
technical prose (see the Writing style section of
[`CLAUDE.md`](../CLAUDE.md)). Spoken strings additionally pass the
housemate test: would this sound natural said out loud to someone in the
room. Error text says what to do next, never just what went wrong.

## Language and locale

UI strings live in a per-package message catalog; English is required.
Dates, units, and currency come from household locale, never hard-coded.
Robot languages drive which speech catalogs load (see
[STACK.md](../STACK.md) > Robot speech).

## Logging

Structured JSON lines: level, timestamp, package id, the turn or op
context, message, fields. Packages log only through `host.log`, which
stamps and redacts; a secret, token, PII value, or transcript never lands.
`debug` is per package, admin-toggled, and reverts after an hour.
Retention is by size and days. Enforced by a test that feeds a secret
through `host.log` and asserts it never appears in the output.

## Debugging and diagnostics

A local dev loop against the host emulator with hot reload, the `check`
CLI, a `smoke` entry, a redacted diagnostics download, `/metrics` per
process, and one trace id from wake word through router, package, and
integration to reply, shown as a timeline in Developer tools on hub and
robot.

## Errors

Every package error maps to a code from the shared catalogue
(`spec/errors.json`), a spoken fallback, and a UI message. A failure never
leaves a half-working feature; it raises a Repairs item instead. The host
wraps errors so a package cannot throw an unmapped one past the boundary.

## Performance budgets

A prompt budget is a test on both sides. First-token and page-open budgets
are measured against named reference machines (the MSI hub, a
two-generation-old laptop, a two-generation-old iPhone, the current Apple
TV, the bench Pi). A package's `handle` is bounded by `timeout_ms`; warm
processes stay under their memory cap. Hub UI budget: cold shell under one
second, page open under 250 ms from cache. The host faults a package that
runs over budget; CI measures; the release skill re-runs the benches.

## Privacy

Every package declares `data_sources` and a `privacy_row`; the "what
leaves the house" tables (see [`CLAUDE.md`](../CLAUDE.md) > Privacy
architecture) are generated from these declarations, never hand-maintained.
A new outbound host is a permission change, shown at install and on
update. Export and forget per person cover every package's storage:
`host.data.forget(person)` is mandatory for anything person-scoped.
Retention is declared per data class. No analytics, ever. Enforced by
catalog lint plus a forget fixture that proves the data is actually gone.

## Security and credentials

Encrypted at rest with the key outside the data, never logged, scoped and
revocable (full detail in [`CLAUDE.md`](../CLAUDE.md) > Credentials and
secrets). `secret: true` settings are write-only. Packages never see a raw
credential; they call `host.integration.call` and the host holds the key.
Supply chain per [PACKAGES.md](PACKAGES.md); the Deno sandbox per
[STACK.md](../STACK.md).

## Kid-safe

The safety layer, ceilings, age bands, and approvals are enforced in the
turn engine and the robot's authorizer, never by UI. A package sees
`age_range`, never a birthdate. Child profiles cannot reach unrestricted
models, cloud endpoints, or a package below its safety floor, and nothing
a package declares can lower a protection. See the Safety invariants
section of [`CLAUDE.md`](../CLAUDE.md) for the org-wide rule this
implements; the bypass test suite is package-specific enforcement.

## Licensing

AGPL-3.0 by default, same as every repo (see [`CLAUDE.md`](../CLAUDE.md) >
Licensing). The catalog additionally accepts only AGPL-compatible package
licences; `LICENSE` per package, `NOTICE` when bundling; model and voice
licences appear in the capability record and are shown at download with an
acceptance step for gated models.

## Versioning and compatibility

Semver per package. Additive-only within a major for anything another
package or node reads. `min_app` states the hub and robot versions, and
`kit_version` states the kit build target. The store refuses an install
that needs a newer platform than the device has. Migrations ship with the
package that needs them.

## Data safety: schema versions

Applies to core's database and every package's own SQLite file (4.9: one
database per package). Two rules, both non-negotiable:

- **Any commit that adds, removes, or renames a persisted table or column
  bumps a schema version in that same commit**, even when no migration
  needs to run. The version lives beside the schema, not inferred from
  migration file names.
- **The app refuses to open a database stamped with a newer schema
  version than its own**, rather than opening it anyway and silently
  writing data the older code does not understand. This is what makes a
  rollback (2.4: re-point to the previous release) actually safe: without
  it, a rollback can open a database a newer version already wrote to and
  corrupt or silently drop data.

## Documentation

Per package: user-tier `README.md` (its store card), `CHANGELOG.md`,
`docs/dev.md`, and a generated settings and permissions reference. Docs
land in the same commit as the behavior they describe, per the org
documentation rule. See [STYLE.md](STYLE.md) for the doc tiers and
screenshot rules.

## Testing

Deterministic offline tests per declared platform, flow fixtures,
property-based tests for sync merge policies, a smoke test on the target
machine. Every real failure becomes a package test first, the same rule as
the org testing standard in [`CLAUDE.md`](../CLAUDE.md), applied at
package granularity.

## Naming and ids

Package ids match `^[a-z0-9][a-z0-9_-]{0,63}$` and are unique in the
catalog. Settings keys are dotted, lowercase, and owned by exactly one
package. No third-party names in ids or branding (see the Trademarks
section of [`CLAUDE.md`](../CLAUDE.md)).
