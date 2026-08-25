---
name: release
description: Cut a MaiPai release - checks, clean-clone build, changelog from commits, screenshot regeneration, docs drift check, semver tag, GitHub release. Use when Jesse says release, cut a release, or ship a version.
---

# Cut a release

Releases are the only thing users (and the hub deployer) touch, so this is the
quality gate. Never cut one without Jesse asking for it.

## 1. Preflight

- Working tree clean, on `main`, local `main` pushed or pushable.
- `scripts/check.sh` passes.
- **Clean-clone build**: clone the repo into a temp dir, run `check.sh` there,
  and boot/build the app. This catches missing files and gitignore mistakes.
  A release never ships from only the working copy's word.

## 2. Version

- Find the last tag (`git describe --tags --abbrev=0`). Collect commits since.
- Pick the semver bump: breaking or removed behavior = minor while 0.x
  (call it out loudly in the changelog), features = minor, fixes/docs = patch.
  Propose the version to Jesse if the bump is ambiguous.

## 3. Changelog and docs

- Update `CHANGELOG.md` (Keep a Changelog format: Added / Changed / Fixed /
  Removed) from the commits since the last tag, written for humans, not
  restated commit subjects.
- **Docs drift check**: diff the code changes since the last tag against the
  docs changed in the same window. Anything user-visible with no matching
  user-doc change gets the doc written now (org rule: Claude writes it).
- Regenerate screenshots if the repo has a screenshot script and anything
  user-visible changed.

## 4. Ship

- Commit `release: vX.Y.Z` (changelog + docs + screenshots together).
- Tag `vX.Y.Z`, push main + tag.
- `gh release create vX.Y.Z --notes-file <notes>`. The notes follow the
  standing template: an "Install or update" section with the one-line
  installers first (most users never download release files), then "What
  are the files below?" explaining the optional Desktop installers and the
  unsigned-build first-launch steps, then "What changed" with the new
  changelog section. The Desktop Build workflow attaches installers but
  NEVER writes the release body; the notes own the page.
- If this repo deploys somewhere (the hub follows release tags), remind Jesse
  the deploy is now available, but never deploy without his word.

## Status

End with the org status block: version cut, what's in it, whether anything
still needs Jesse (deploy go-ahead, asset uploads).
