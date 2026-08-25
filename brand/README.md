# MaiPai brand assets

The MaiPai mark: a rounded "M" that doubles as a smile, one accent color per
product, with the product's glyph inside the smile. All PNGs are transparent.

## Naming

`maipai-<product>-<kind>-<background>.png`

- `<product>`: `brand` (the org/master mark), `home`, `desktop`, `go`, `bot`
- `<kind>`: `icon` (mark only) or `logo` (mark + wordmark)
- `<background>`: `light` (dark glyph/text, for light backgrounds) or `dark`
  (white glyph/text, for dark backgrounds). The org `brand-icon` works on
  both backgrounds and carries no suffix; the brand wordmark logo has both
  variants.

## Product colors

| Product | Accent | Inner glyph |
|---|---|---|
| Brand (org) | Purple | AI brain (purple-to-blue halves, lens center, teal sparkles) |
| Home | Cyan | house |
| Desktop | Pink | monitor + cursor |
| Go | Green | wifi |
| Bot | Blue | robot face |

## Rules

- These are the only logos used across MaiPai repos, sites, and apps
  (org CLAUDE.md: no borrowed trade dress, MaiPai surfaces use MaiPai's own
  palette and iconography).
- App icons, favicons, DMG art, and docs-site logos are derived from these
  masters during each product's build/asset pass; don't hand-redraw variants.
