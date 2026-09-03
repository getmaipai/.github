# Settings: one definition, one renderer, three disclosure levels

Full source: platform plan section 6.6 and the settings registry
(`spec/settings/keys.json`, section 3.2).

## Rule 1: a setting lives with the thing it configures, once

Every package declares its settings; the shell renders them inside that
package (a gear in the app header opens the right pane or a sheet with
household and personal settings together, plus a "for everyone / just me"
toggle). News sources live in the News app, a companion's voice on the
companion, an integration's options on its card. Strictly declarative: no
custom settings pages. The one escape hatch is a declared `setup` flow.
Every package's settings are also reachable from the central package list
(Household → Store, Profile → Apps) as the same renderer pointed at that
package.

## Rule 2: central pages hold only what is central

- **Profile**: identity, appearance, my voice and volume, notifications, my
  connections, my AI, privacy and data, signed-in devices.
- **Household**: People and permissions, Devices (Pods, Robots), Store,
  Integrations and credentials, AI, Storage and backups, Network and
  access, Repairs, Health, System.

## Rule 3: AI settings get one home, by role

One card per role (`chat`, `router`, `embed`, `vision`, `image`, `video`,
`coding`, `tts`, `stt`, `wakeword`), with the chosen model, its eval score,
where it runs, and "change." Advanced and expert details fold.

## Rule 4: three levels, disclosed locally, never a global mode

Basic is always visible. Advanced keys fold into one collapsed group at
the end of their section, opened in place, only when there are three or
more (fewer show inline), with the hidden titles as subtext. Expert lives
under Developer tools, admin only. A "modified" filter shows every changed
key. No per-person "advanced mode" switch.

## Rule 5: one index and search, built first

A generated settings index (key, label, help, level, where it lives)
drives the palette and a "Find a setting" box with `@modified`, `@app:`,
`@level:`, and `@person` filters. The docs' settings reference is
generated from the same index, never hand-written.

## Rule 6: modern and calm

Live apply, defaults and reset, help text from the declaration, destructive
confirms, only the kit's form primitives, at most about fifteen keys per
screen, a master toggle at the top of a section, search results with
breadcrumbs.

## The registry

`spec/settings/keys.json` declares, per key: scope (household, person,
device), selector type (Home Assistant's selector names: `number`,
`select`, `text`, `boolean`, `duration`, `time`, `entity`, `area`,
`person`, `media`), range, default, label, help, `section` with
`collapsed`, `order`, `level` (basic/advanced/expert), `secret`, `needs`
(capabilities), `lives_in` (the package, companion, integration, or
central page that renders it), and `honoured_by: [home, bot]`. Robot-only
keys are declared by the robot in the same format and sent on `hello`; the
hub stores no copy.

## Storage

Values by scope with per-field last-writer-wins on the oplog (see the link
and sync design in `home/spec/dev.md` once it exists). Definitions come
from the registry above and from package manifests.
