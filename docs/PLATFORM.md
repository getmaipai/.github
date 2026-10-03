# Platform: products, principles and standards index

Dev tier. Full text of the products framing, the eight principles, the spec-first rule, the design-ambiguity rule and the standards index. The core keeps one line each. Load before product framing, repo descriptions, applying the no-hand-built-UI rule, or a shared record change.

## Rebuild history and build order

The platform is being rebuilt fresh on the design in `home/docs/design/`
(seeded from the platform plan). On 2026-09-03, `home` and `bot` were reset
to a clean history to start over on that design: the pre-rebuild code is
not on GitHub at all, only a full local git mirror of each
(`legacy-backups/home-legacy.git`, `legacy-backups/bot-legacy.git`, next to
the working checkouts on the dev machine, never pushed anywhere), kept
only as a reference to copy hard-won logic from, never a requirement of
feature scope. `home`'s 21 pre-rebuild releases were deleted from GitHub;
their metadata (tags, notes, asset lists with sha256, no binaries) is
backed up alongside the mirror. Build order: hub first, robot for parity,
Go last; the Stack (2026-09-20, superseding the 2026-09-17 product
framing) is Home's engine layer as a private daemon inside Home's
release, proven on the Studio beside the hub before Home moves onto it.
The libraries every product imports (`ui`, `core`, `spec`) live in
`commons`, the one public library repo.

## The products (full descriptions)

| Repo | Product | What it is |
|---|---|---|
| `stack` | MaiPai Stack | The engine foundation of MaiPai Home: the headless service that installs, sizes, runs, watches, updates and tests the engines and models behind Home, and gives Home one stable address by role. It has no interface and no users of its own; Home is its only caller. Ships inside Home's installer, updates with Home's releases. |
| `commons` | (libraries) | The three packages every product imports, tagged on their own: `ui` (`@maipai/ui`: the kit, tokens, icons, the shell, the settings and permission renderers), `core` (`@maipai/core`: log, paths, secrets, the hardware probe and the other backend helpers), `spec` (`@maipai/spec`: the shared record shapes, schemas, fixtures and the Python package). Imported by `stack`, `home` and `catalog`; `bot` and `go` pin `spec`. Nothing in it imports a product. Public, so the Catalog's contributors and CI can read the shapes. |
| `home` | MaiPai Home | The self-hosted family AI hub: the platform and the household's master (identity, people, memory, the turn engine, settings, the package host, the shell). Every feature ships as a catalog package. |
| `catalog` | MaiPai Catalog | The public package catalog: every plugin, app, companion, integration, model, wake word, voice, and theme, signed and indexed. Hub and robot install from it. Pins `spec` from `commons` for the manifest shapes; keeps no schema mirror of its own. |
| `go` | MaiPai Go | Apple TV and iPhone client. Renders the same UI schema natively. Built last, once the hub and robot have packages with schema pages. |
| `bot` | MaiPai Bot | Robot companion, on any supported body. Pairs with the hub like a pod (a full replica, the hub as its brain when reachable), stands alone complete when not: that standalone promise is the MaiPai build's; a purchased body (Reachy Mini, 2026-09-27) is a connected body whose turns the hub runs, until a measurement says its compute carries more. One body layer in `bot`, a profile per body, never a fork above it. Bench-proven, rebuilt fresh on the platform design. |
| `.github` | (this repo) | Org standards, `@maipai/standards` tooling, the shared Claude plugin, org profile |

## The promise and product copy

MaiPai's promise: private, local AI that's actually yours. Nothing leaves the
home. Every technical and product decision honors that.

Product descriptions come verbatim from [brand/COPY.md](brand/COPY.md), the
single source for pitch copy (repo description fields, org profile, READMEs,
docs). Logos come from [brand/](brand/), never redrawn. **A GitHub repo
description is succinct (2026-09-20):** one sentence, at most 120
characters, in COPY.md under the product as its "repo description"; the
longer one-liner is for READMEs, the profile and docs, never the
description field (GitHub truncates it in lists and search, and a
description that reads as a paragraph reads as marketing).

## Principles: intro

These hold across `home`, `bot`, `catalog`, and `go`. Full detail in the
platform plan; this is the standing summary every session should carry.

## Principle 1

1. **Simplify: centralize and reuse.** One definition, one implementation,
   one store. A second copy of anything is wrong even when it is faster.

## Principle 2

2. **The robot is complete without a hub**, disconnected for an hour or never
   paired. Its own people, settings, memories, companions, packages, and the
   integrations it can hold itself. Nothing on it is a stub.

## Principle 3

3. **No data debt.** Every record either product writes is the shared spec
   shape, with id, provenance, and clock stamp, from the first boot. Pairing
   later is a transfer, never a translation.

## Principle 4

4. **One definition, one place.** A settings key, a record type, a package's
   config, an integration's shape, a companion's metadata: each is declared
   exactly once, and every renderer draws from the declaration.

## Principle 5

5. **Repos only when necessary.** A new repo needs a different release
   cadence, a different committer audience, or a different visibility.

## Principle 6: prebuilt over hand-built

6. **Prebuilt over hand-built.** One component library, one icon set, one
   engine, maintained parts assembled by us, and the org standards enforced
   by lint and tests, never by memory. The same rule past the UI: a native
   capability the mandated engine already has, or a maintained library for
   a solved problem, beats hand-rolled logic doing the identical job. A
   large system prompt standing in for a real technique (activation
   steering instead of a paragraph of personality prose, a text-
   normalization library instead of asking the model to spell out numbers
   reliably) is hand-built too, and loses to the prebuilt answer on the
   same terms: slower, more tokens, less predictable.

## Principle 6: no hand-built UI (owner's rule, 2026-09-21) and the shadcndashboard shell

   **No hand-built UI, from 2026-09-21 on (owner's rule).** Every
   surface is a shipped component used exactly as it ships: an
   assistant-ui Element for anything a chat or an assistant does, a
   kit primitive (the vendored shadcn set) or a kit block composed of
   those for everything else. A component written by hand where a
   maintained one exists is a defect, found in review and replaced,
   never kept because it already works; a shipped component is never
   edited (the kit wraps and composes, it does not fork), and the
   look comes only from the tokens the component already reads. When
   nothing shipped does the job, the gap is named in the design record
   before a line is written, and the smallest composition of shipped
   parts wins. Why: the chat rebuilt by hand on assistant-ui's runtime
   (2026-09-13 to 2026-09-21) was ugly and buggy where the library's
   own Elements were neither, and every hand-built piece cost review
   rounds the shipped one would not have. **The application shell and
   every non-chat page of Home come from `shadcndashboard`
   (github.com/shadcndashboard/shadcndashboard, MIT, React 19, Vite,
   Tailwind v4, shadcn/ui on Base UI), used as it ships (owner's rule,
   2026-09-21):** its layouts (sidebar, header, theme toggle), its
   dashboard widgets, data tables, form layouts, profile, settings and
   auth pages are the pages Home composes from, vendored into the kit
   as a snapshot with attribution in NOTICE, restyled by the tokens
   alone; the kit's own hand-built shell, panes and blocks retire as
   each page moves. Home writes routes, data and copy, never a
   component; the chat inside that shell is assistant-ui Elements.

## Principle 7

7. **Hub first, robot for parity, Go last.** Every hub step is in family use
   before its robot counterpart; nothing early may close the door on the
   later clients. The Stack sits under all three and follows the same
   rule: it is in family use the day Home runs on it, and nothing moves
   out of Home before the Stack has proven the hub's profile on the
   Studio.

## Principle 8

8. **Every feature is reviewed and rebuilt, never carried.** No existing app,
   plugin, or screen is a requirement by virtue of existing in the legacy
   code. Each is re-examined (does the family use it, does it fit a package,
   what is the right design now), then rebuilt as designed, redesigned,
   merged, or dropped, with a one-line verdict recorded in the fresh repo's
   dev docs before it is built. "Copy from legacy" applies only to hard-won
   logic (resolvers, sync, limiters, drivers, measurements), never to
   feature scope or UI.

## Shared record changes go through the spec first

**Shared record changes go through the spec first.** Anything in
`spec/` in `commons` (Person, Setting, Memory, the manifest and recipe shapes, the
link API, the UI schema) is edited in the spec, then implemented on the hub,
then on the robot. A hub-only or robot-only patch to a spec-shaped record is
a bug: the shapes drift and the round-trip fixtures catch it.

## Resolve design ambiguity before asking

**Resolve design ambiguity before asking, when it is genuinely
resolvable.** When the platform plan, a spec, or a standard is silent or
seems to conflict with itself, that is usually not a question for Jesse:
it is a research task. Dispatch the `design-resolver` agent (`plugin/
agents/design-resolver.md`, opus) to read every relevant passage, find the
pattern, and come back with a concrete decision and its reasoning, before
reaching for a clarifying question. Escalate to Jesse only for what the
agent itself reports as genuinely low-confidence, or for what was already
his call to begin with (releases, deploys, go/no-go, review verdicts, a
real-world fact only he knows). A clarifying question that a closer
reading would have answered is a round trip that did not need to happen.

## Stack

See [STACK.md](STACK.md). New work uses the standard stack; a deviation needs
a written justification in that repo's dev docs.

## Platform standards

Beyond the rules above, the platform rebuild carries its own standards docs,
all pinned by the [`@maipai/standards`](standards/) tooling core
(std-v0.2.0):

- [docs/PACKAGES.md](docs/PACKAGES.md): package definition of done, supply
  chain, review, the CLA.
- [docs/UI.md](docs/UI.md): the shell contract, the kit, patterns,
  responsive rules, PWA, tabs, icons.
- [docs/SETTINGS.md](docs/SETTINGS.md): the settings standard (one
  definition, the generic renderer, three disclosure levels).
- [docs/ENGINEERING.md](docs/ENGINEERING.md): tokens, accessibility, copy,
  i18n, logging, tracing, errors, performance budgets, privacy, security,
  kid-safe, licensing, versioning, naming, every standard a package
  inherits.
- [docs/STYLE.md](docs/STYLE.md): documentation and screenshot standards
  (extended for the platform's screenshot pipeline and build-doc format).
- [docs/UPDATES.md](docs/UPDATES.md): updates, notifications of updates, and
  install.
- [docs/BACKUPS.md](docs/BACKUPS.md): backups, integrated and scheduled.
- [docs/NOTIFICATIONS.md](docs/NOTIFICATIONS.md): the notification system.
- [docs/SERVICES.md](docs/SERVICES.md): how a daemon runs on a person's
  machine (the three pieces, service managers per OS, the watchdog
  layers, one health list, logs, install and uninstall).

A repo's own `CLAUDE.md` may add specifics; it never restates or weakens a
platform standard. `@maipai/standards` `check.sh` core is what actually
enforces the enforceable half (see [standards/README.md](standards/README.md)).
