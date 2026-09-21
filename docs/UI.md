# UI: the shell contract, the kit, patterns, responsive, PWA

One shell, one kit, one set of patterns, rendered three ways (React on web,
SwiftUI on iPhone, SwiftUI on Apple TV). An app never writes its own chrome,
breakpoint, or one-off pattern. Full source: platform plan chapter 6.

## The shell contract

The platform owns all chrome: sidebar and navigation, top bar, right pane,
settings and admin modals, breadcrumbs, dialogs, sheets, toasts, the
command palette, the player bar, theme and tokens, focus rules, the profile
picker. An app declares contributions as typed blueprints (nav entries,
pages, right-pane panels, settings sections, commands, quick actions,
player hooks, admin sections), each naming where it attaches and its typed
inputs, outputs, and config schema. A household config can disable or
override any extension by id. Blueprint creators live in `@maipai/ui`,
never in app packages.

Per surface: phone collapses the sidebar to a five-entry bottom bar with
the rest under More, the right pane becomes a bottom sheet, breadcrumbs
become a back button. TV is a focusable rail with no hover. An app declares
nothing about any of this.

## Pages are data

An app's pages are trees of the kit's primitives (`Page`, `Section`,
`CardGrid`, `MediaShelf`, `List`, `DetailPane`, `SplitView`, `Form`,
`EmptyState`, `Progress`, the pattern components) with data bindings,
conditions, and actions, versioned in `spec/ui/` with a conformance suite.
A package may still ship a custom React page for what primitives cannot
express, marked `platforms: [web]`, loaded as a signed bundle through
Module Federation 2.0 so React and `@maipai/ui` stay shared singletons. The
store card says "web only"; iPhone shows it in a web view; Apple TV shows a
"use your phone or the web" card. No iframes except opaque legacy content
(ZIM pages, docs, bookmarked sites).

## The kit

**No hand-built UI (2026-09-21).** A surface is an assistant-ui
Element, a kit primitive, or a kit block composed of those, used as
shipped and styled by tokens alone; see CLAUDE.md, platform principle
6, and DECISIONS.md, 2026-09-21. A pull that adds a hand-written
component where a shipped one exists is returned with the name of the
shipped one.


`@maipai/ui` lives in `getmaipai/commons` as the `ui` workspace (decided
2026-09-20; the kit and shell moved there from the Stack's reconciled
copy, and Home imports it like every other product). The kit's approved
design specification is `shared/ui/docs/spec.md` (the 2026-09-19
reconciliation, moved from `stack/docs/plans/ui-spec-2026-09-19/` with
`ui-v0.1.0`). It is a thin layer
over shadcn/ui on Radix and Tailwind v4: the
tokens, the layout primitives, the settings and permission-prompt
renderers, the pattern components, re-exports. It never reimplements a
widget the library ships. Icons are lucide, by name, at three token sizes;
no other set, no emoji as icons, no pasted SVG outside a companion avatar.
The kit ships the ESLint config every repo and catalog CI run (`ui/eslint.config.js` in
`getmaipai/commons`, imported by a consumer as
`@maipai/ui/eslint.config.js`; `core/eslint.config.js` covers the backend helpers the same way): no other component libraries, no raw
colors, no inline layout outside the primitives, icons only from lucide by name. `@maipai/ui` and the shell
contract move together on `ui-v` tags; an app declares the kit version it
built against.

## Patterns: one way to do each thing

Reference systems, in precedence order: GOV.UK Design System for flows,
content, and errors; Material 3 for component behavior where shadcn is
silent; WCAG 2.2 AA as the floor (2.4.13 focus appearance, 2.5.5 targets);
Apple tvOS HIG and Android TV for the TV surface; Alexa Design Guide and
Google Conversation Design for voice. Each pattern (dialog, sheet, right
pane, wizard, progress, buttons, confirmation, forms, toast, notification,
empty state, loading, errors, lists/cards/shelves, navigation, search,
selection, media controls, status, permission prompt, focus/input, voice
equivalents) has a kit docs page with the component, the rule, a good and a
bad example, the TV column, and the lint that guards it. The full pattern
table is platform plan section 6.4; new patterns are added to the kit
first, never invented inline in a package.

**Batch actions, in one rule:** every list of things a household can
delete offers a multi-select and a batch delete, and a list whose whole
contents are safely disposable (memories, notifications, history) also
offers a clear-all. One item at a time is the exception, not the
default: a parent tidying up a year of memories one row at a time is a
product that does not respect them. The kit owns the pattern (a
selection mode, a count of what is selected, one confirmation naming the
number, per-item results when some are refused), so a package never
builds its own. Partial success is reported, never swallowed: selecting
five and having one refused deletes the other four and says why the
fifth was kept. Destructive batches follow the same confirmation rule as
any single destructive action, and a clear-all always names what it is
about to remove.

**TV, in one rule:** every pattern is marked `tv: page | none | native`.
Toasts, sheets, tooltips, hover, drag, nested tabs, breadcrumbs, the right
pane, and free text entry do not exist on TV.

**Kids, in one rule:** child profiles switch to kid presets from the age
band (2 cm targets, no drag or long scroll for the youngest, icons with
labels and audio cues, a parental gate before anything leaves the
household or grants a permission, copy at reading age 9). No per-package
work.

**Toast, confirmation, sheet, and the notification center, decided
(2026-09-05, researched against Synology, Home Assistant, and Discord's
own real patterns rather than invented from scratch):** five different
"something is telling you something" shapes exist and each has exactly
one job.

A *toast* is a courtesy echo of an action the household member just took
themselves, self-dismissing, never blocking, and never the only place
the outcome is recorded - it always writes to the notification center
too, so nothing is lost because a toast was missed while looking away.
`tv: none` (it never appears there, per the TV rule above); on TV the
same event surfaces only through the center.

A *confirmation* is an inline card in the flow, never a floating dialog
- `PeoplePage`'s existing Remove pattern (names the count, states what
is lost, offers Cancel and confirm without leaving the list) is the
model, not an exception to standardize away later. It is the only
pattern for "are you sure" before a destructive-but-recoverable action,
chosen specifically because it never traps focus or hides what the
person was already looking at. `tv: page` (promoted to full-page focus
on TV, the same way any floating pattern is there).

A *sheet or full dialog* is reserved for a genuinely separate task that
needs its own real estate and real focus (a multi-field form: authoring
a household command, editing a person's role). None exists in the kit
today because nothing built so far has actually needed one - a generic
Dialog component gets built the first time a real caller needs it, not
speculatively ahead of one.

The *notification center* (`getmaipai/.github/docs/NOTIFICATIONS.md`)
is the durable, thirty-day record: every notification writes here
regardless of which other channel also fired, so toast, Telegram, and a
future push channel are courtesy layers on top of it, never a
substitute for it. It is a non-blocking panel, not a modal - it never
traps focus, matching the same "inline over floating" preference the
confirmation pattern above already takes. A notification type marked
non-configurable (`getmaipai/.github/docs/NOTIFICATIONS.md`'s `locked`
declarations - a safety alert to a parent, a security action awaiting
confirmation) still writes here and still respects its declared level's
delivery rule; "non-configurable" means the household can't reroute or
silence it, never that the UI shows it any less prominently than a
routine one. `tv: page` (the doc's own "TV overlay" channel: a
full-screen take, never a corner toast, since TV has no toast surface
and no hover to reveal a panel).

Two things researched specifically because they'd be easy to get wrong
by assuming rather than checking: Home Assistant's "critical" alert is a
flag the *sender* sets on the notification payload, never a per-person
override a user can promote a normal notification into after the fact
- a locked/immediate notification's urgency is declared once, at the
source, the same way `NOTIFICATIONS.md`'s own `level` field already
works. And Discord's "Suppress @everyone" needs an explicit, separate
toggle even when a channel or server is otherwise muted - a broad
"mute everything" control must never silently cover a locked type; if
MaiPai ever builds a household-wide mute, it has to name and skip every
locked notification explicitly, not fall through to muting them by
omission.

## Responsive layout, PWA, tabs, icons

**One product on every screen.** The phone is not a second design. A
page on a phone is the same page as on the desktop: the same tokens,
type scale, icons, wording, order of content and actions, and the same
states, so a person who knows the desktop already knows the phone.
What changes is only what the small screen forces: one column instead
of three, the rail collapses to the phone tab bar with the rest under
More, a table becomes labeled rows with the same fields in the same
order, a side pane becomes a sheet, hover actions become a long press,
targets grow to 48 px and body type never drops below 16 px. Nothing
that matters on the desktop is hidden on the phone; a field the desktop
shows in a secondary column moves into the row's detail, it does not
disappear. The screenshot matrix captures every page at both widths,
and the review judges each pair as one design: a phone capture that
would not be recognized as the desktop page is a failure, and so is a
wide screen left empty by a page designed phone-first.

- Four surfaces, one set of breakpoints owned by the kit and pinned in
  its `tokens.css` (`sm` 640, `md` 720, `lg` 960, `xl` 1280: phone under
  640, tablet to 960, desktop above, TV by input mode); the kit's
  `responsive.ts` follows the tokens. Packages never write a breakpoint.
- No fixed widths or heights on content; text wraps by default; images and
  video are fluid with declared aspect ratios.
- Density budgets per surface live in the primitives (one column on phone,
  two on tablet, three on desktop, a single focused row on TV; at most
  fifteen settings keys per section).
- Type and target minimums the kit refuses to go below: 16 px body on
  phone and desktop, TV sizes for ten feet, 48 px targets, a visible focus
  ring.
- Every page is captured at every surface, light and dark, and clipping
  fails the build (horizontal overflow, text outside its box, overlaps,
  undersized targets, anything wider than the viewport). See
  [STYLE.md](STYLE.md) for the screenshot pipeline.
- Tabs are peer views of one thing only, never navigation or steps; at
  most five with overflow into a menu; one or two word nouns, unique,
  never icon-only; the active tab lives in the URL.
- Icons are lucide only, by name; the lint fails any other import or
  pasted SVG.
- The PWA is built once in the shell: a manifest with every icon size,
  standalone display, theme colors from tokens, safe-area insets; an
  app-shell service worker that caches only shell and kit, never household
  data; an offline page that says which packages work offline; iOS quirks
  (install hint, standalone navigation, audio and wake-lock, viewport
  height) handled once.

## Settings live with the thing they configure

A setting lives with the thing it configures, once. Every package declares
its settings; the shell renders them inside that package. Full rules
(central pages, AI settings by role, disclosure levels, the settings
index) live in [SETTINGS.md](SETTINGS.md).

## Themes: per person, generated, never CSS

A theme is a small declared object (seed color, mode, variant, contrast,
radius, density, font from an allowlist), stored on the person's profile,
synced, and applied after login on every device. The full token set is
generated from it with a guaranteed contrast floor. Presets ship with the
kit; `kind: theme` packages hold exactly that object, lint-validated at
publish. Never CSS, a wallpaper, a remote asset, or a layout change. Full
detail: platform plan section 6.8.
