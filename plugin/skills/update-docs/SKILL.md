---
name: update-docs
description: Refresh a MaiPai repo's README and user docs with the latest shipped features and privacy-safe generated screenshots. Use when features shipped since the last docs update or Jesse asks to update docs, README, or screenshots.
---

# Refresh docs and screenshots

Bring the README and `docs/` user tier in line with what the app actually does
now. Org rules apply: Claude writes all prose, user tier passes the dad test
([docs/STYLE.md](https://github.com/getmaipai/.github/blob/main/docs/STYLE.md)),
no em dashes.

## Screenshots (privacy layers, do not weaken any)

1. Screenshots come ONLY from the repo's screenshot script (Playwright for
   web, simctl for Go), never hand-taken.
2. The script runs against a seeded demo household built from the persona
   roster. Never the owner's real profiles, history, or location.
3. Fixed viewports (desktop + phone) so the strip stays visually consistent.
4. Output overwrites the repo's screenshot folder (Home: `docs/site-fumadocs/public/screens/`); a partial
   retake replaces only the listed pictures.

If the repo has no screenshot script yet, writing one is part of this skill's
job, not a reason to hand-take images.

## Incremental runs (release time, never on push)

If the repo has `docs-covers.json`, it is the one map from each guide page and
screenshot to the code it describes. Run the repo's drift script (Home:
`bun scripts/docsDrift.ts`, `--json` for tools, `--since <ref>` for a window,
`--check` to verify the map is complete). Update only the pages and retake only
the pictures it lists; leave everything else untouched. A new page or picture
gets its `docs-covers.json` entry in the same commit (the repo test fails
otherwise). Full refresh only when asked.

## Process

1. Diff shipped features against the current README + user docs (read the
   changelog and recent commits), or take the drift script's list.
2. Update the README per the org skeleton (STYLE.md): pitch, screenshot
   strip, Get started, the three doc links.
3. Update or add user-tier pages for anything new, dad-test voice.
4. Regenerate screenshots.
5. One commit: docs + screenshots together.
