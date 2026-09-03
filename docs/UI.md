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

`@maipai/ui` is a thin layer over shadcn/ui on Radix and Tailwind v4: the
tokens, the layout primitives, the settings and permission-prompt
renderers, the pattern components, re-exports. It never reimplements a
widget the library ships. Icons are lucide, by name, at three token sizes;
no other set, no emoji as icons, no pasted SVG outside a companion avatar.
The kit ships the ESLint config every repo and catalog CI run: no other
component libraries, no raw colors, no inline layout outside the
primitives, icons only from lucide by name. `@maipai/ui` and the shell
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

**TV, in one rule:** every pattern is marked `tv: page | none | native`.
Toasts, sheets, tooltips, hover, drag, nested tabs, breadcrumbs, the right
pane, and free text entry do not exist on TV.

**Kids, in one rule:** child profiles switch to kid presets from the age
band (2 cm targets, no drag or long scroll for the youngest, icons with
labels and audio cues, a parental gate before anything leaves the
household or grants a permission, copy at reading age 9). No per-package
work.

## Responsive layout, PWA, tabs, icons

- Four surfaces, one set of breakpoints owned by the kit (phone under 640,
  tablet to 1024, desktop above, TV by input mode). Packages never write a
  breakpoint.
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
