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
  by the TypeScript and Python interpreters in `spec/` in `commons`. No process.
  Most plugins, and every robot plugin by default.
- **Tier 1, code**: TypeScript under Deno (see [STACK.md](../STACK.md)), for
  what a recipe cannot express. `runtime: wasm` (Extism) is reserved for
  later.

## Supply chain and the store

- **Repo layout** (`getmaipai/catalog`, public): `plugins/<category>/<id>/`,
  `skills/<category>/<id>/`, `apps/`, `companions/`, `integrations/`,
  `models/`, `wakewords/`, `voices/`, `@maipai/spec` pinned from
  `getmaipai/commons` for the manifest and recipe shapes (no schema mirror of
  its own), `tools/` (lint, pack, sign, index, scorecard, the `check`
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

## Writing an app package

An app is any package whose manifest lists `contributes.pages`. It opens at `/apps/<package id>` in Home, appears in search and the
person's favorites, and draws pages written as data, so Home runs it with no per-package code and no rebuild. Weather is the first
one: the chat tool and the app are one package and one recipe. Design record: `home`'s `docs/plans/app-kind-2026-10-16.md`. The
contract lives in `commons` (`spec/schemas/manifest.schema.json`, `spec/ui/schema.json`, `spec/ui/app-check.ts`), from `spec-v0.1.153`
and `ui-v0.5.239`.

**The rules.** A page is a `page` document in `pages/<module>.json`. It may use only `page`, `section`, `empty_state`, `progress`,
`detail_pane`, `answer_blocks` and `picker`. It can read only its own package (`source: "package"` bindings) and can call only
`/api/plugins/<package id>/...` or navigate only to `/apps/<package id>/...`. `kind: "web"` pages are refused. All drawing is done by kit Elements reached through the answer-block dispatcher
(design rule 9); a package never ships React.

**The manifest.** One `index` page is required. `nav: true` on `index` makes the app a search and favorites entry; `nav: true` on any
other page makes it one of the app's own sections (tabs on wide screens). `keywords` (up to 8, each up to 24 characters) are extra
search words. Access is the package's own: `min_role`, `platforms` must include `home`, a passing smoke test, and its required
capabilities. A package that fails any of them is absent (404), so its existence does not leak.

```json
{
  "id": "forecast-example",
  "version": "0.1.0",
  "kind": "plugin",
  "category": "Utilities",
  "display": "Forecast",
  "description": "The weather for a saved place or where you are.",
  "min_role": "child",
  "platforms": ["home"],
  "incognito": "unaffected",
  "returns_blocks": ["weather_card", "spec_sheet"],
  "contributes": {
    "pages": [
      { "id": "index", "label": "Forecast", "icon": "cloud-sun", "nav": true, "kind": "schema", "module": "index", "keywords": ["rain", "temperature"] },
      { "id": "week", "label": "Week", "icon": "calendar", "nav": true, "kind": "schema", "module": "week" }
    ],
    "data": [
      { "id": "places", "surface": "weather", "rows": "places" },
      { "id": "forecast", "surface": "weather", "refresh_s": 1800 }
    ]
  }
}
```

**Data.** `contributes.data[]` names what a page may ask for. An entry with `surface` (`weather` or `maps`) runs the package recipe with the
place the host resolved: the host, never the page or the model, injects the coordinates, rounded to two decimals (one for a child).
An entry with `rows: "places"` returns the asking person's saved places for a picker and runs no recipe. The call is
`POST /api/plugins/<id>/data/<data id>` with `{place?, current?}`; the answer is `{as_of, blocks?, rows?, degraded?, needs?}`, and `blocks`
pass the manifest's `returns_blocks`, the person's age band and the output floor, like a chat turn's. A failed lookup shows only its kind.

**A page.** `pages/index.json` for the manifest above:

```json
{
  "type": "page", "id": "forecast", "title": "Forecast",
  "body": [
    { "type": "picker", "state": "place", "label": "Place", "placeholder": "Default place",
      "leading": [{ "value": "current", "label": "Current location", "icon": "locate-fixed", "needs": "geolocation" }],
      "bind": { "source": "package", "path": "places" }, "item_key_field": "id", "item_label_field": "label" },
    { "type": "answer_blocks", "kinds": ["weather_card"],
      "bind": { "source": "package", "path": "forecast", "params": { "place": "$state.place", "current": "$state.place_geo" } },
      "empty_state": { "type": "empty_state", "icon": "cloud-off", "text": "The weather is not available right now. Check your connection and try again." } }
  ]
}
```

A picker writes its choice to page state `place`; `params` read page state with `$state.<name>`. A `needs: "geolocation"` option asks the
browser only when it is chosen and keeps `{lat, lon}` in memory as `<state>_geo`; it rides the request body only, never a URL, a
query key, a log line, a cache key or storage. The hero is the first `answer_blocks` node. A block kind the client does not know shows the
block's `alt` sentence, which is also what a robot with no screen says.

**Settings and the gear.** An app that keeps a person's own settings (Weather's saved places and default place) declares
`contributes.settings_area`, the same record as an area in `spec/settings/areas.json`: an `id` (the route `/settings/<id>`), `app: "/apps/<package id>"`,
`audience.min_role`, and `keys` sections whose cards name groups from the package's own `config[]` (a `location` key draws the kit place picker). Home lists
the area on the app's row in `GET /api/apps` for a person whose role clears `audience.min_role`, draws it in the one settings shell, and shows a Settings gear in the
app's toolbar named "<app label> settings"; back from it returns to the app. Install refuses an area whose id is a built-in settings page, whose `app` is not the
package's own, or whose cards draw anything but the package's own `config[]` groups. Under Incognito the picker saves and searches nothing; a saved place keeps
coordinates to two decimals.

**Checks.** Install refuses an app whose page is missing, is not a schema page, binds to a data id the manifest does not declare, uses a
node a package page may not, or reaches outside the package (`spec/ui/app-check.ts`, run by the hub). Tests to carry: the `index` page and
each section validate against `spec/ui/schema.json`; a child, a teen and an adult each see or do not see the app as `min_role` says; a
data call with no network shows the plain empty state. Uninstall hides the app and keeps its state, so a favorite comes back on reinstall.
Use `192.0.2.x` and `example.com` in fixtures.

## Chat cards

Every package a person can call from chat shows its result as a card, or says in one line why it does not. A card is an
answer block (`spec/schemas/answer-block.schema.json`) drawn by the kit as shipped; a package never ships React and Home has
no per-package chat code.

**Declare it.** A `plugin`, `app` or `project` manifest carries `chat_card`, one of:

- `{ "block": "<kind>", "actions": [...], "open_page": "<page id>", "fallback": "alt" | "reply" }`, where the kind is also in
  `returns_blocks`;
- `{ "native": "<name>" }`, deprecated and removed by CHAT-CARDS-11; until then it names a value from the closed list Home draws itself (picture, video and song jobs, project, artifact, confirm, sources); a package cannot add a name;
- `{ "none": "<20 to 120 characters, why the reply text alone is right>" }`, for fire-and-forget or prose-only tools. Refused
  when the package has pages or lists `returns_blocks`.

**Produce it.** A Tier 1 handler returns `blocks`. A Tier 0 recipe uses the `format` step's `card` binding. The hub validates
the block, applies the person's age band and the output floor, and drops what fails; the reply text is always complete.

**Actions.** Use the standard names (`open_app`, `open`, `save`, `play`, `add_to_list`, `undo`, `copy`). `open_app` is
"Open in <App>" and needs pages. An action reaches only the package's own `/api/plugins/<id>/` routes and
`/apps/<id>/` pages. A block never names a route.

**Images** in a block must be hub cache references; the browser never fetches an image from another host.

**States.** Empty uses the kind's empty text; failure draws no card and the answer continues; an offline-degraded package
draws from cache with an "As of" line.

**Checks.** `chatCardCheck` (in `commons` `spec/ui`) runs in catalog lint, in Home's bundled-package test and at install. A
package with neither a card nor a one-line `none` reason cannot ship in the bundled or catalog set. Carry one render
fixture per declared kind and a child/teen/adult run.

## Uninstall, and a person's files

Why this section exists: a role turned off in the setup wizard or under
Settings removes every package that needs it (the hub's capability
reconcile), and a family's pictures, videos and stories must not go with
them. Owner's rule, 2026-09-23.

- **A person's output is a household record, never package data.**
  Anything a person made through a package (a picture, a video, a story,
  an export) is written into the household's own store as the spec's
  `file` record (home's `docs/plans/household-storage-2026-09-23.md`,
  commons `STORE-SPEC-01`: one owner, origin, kind, bytes below the
  household data directory, integrity digest, retention, sharing, and
  provenance naming the package, the turn and the job), owned by the
  person; ownership, sharing and the caps are that record's rules, not
  restated here. It is
  never kept inside the package's own data directory.
- **Uninstall removes code, keeps state, never touches records.**
  Uninstall removes the package's code and hides its surfaces (its app
  page, its launcher entry, its tools); it keeps the package's own
  settings and state so a reinstall restores them; it never touches a
  person's records, which stay reachable from the household's library
  and files pages with the package gone.
- **The confirmation says what goes and what stays.** Before an
  allocation change or an uninstall, the confirmation lists the packages
  being removed in these words, "the following will be uninstalled and
  users will lose access", then states what stays, "your pictures stay
  in Library" (or the kinds the records carry). Nothing is applied before
  the person confirms.
- **The mechanism is a shape check, not a promise.** A package that
  stores a person's output anywhere but the household's media record
  (its own data directory, a file path of its choosing) fails the
  manifest lint: a manifest declares its outputs as media kinds, and the
  host's record API is the only write path for them.

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
