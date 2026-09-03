---
name: standards-check
description: Verify a getmaipai repo is correctly pinned to @maipai/standards and its check.sh core passes. Use when setting up a new repo's check.sh, auditing which std-vX.Y.Z a repo targets, or when the release skill needs to confirm a repo is current before cutting a release.
---

# Verify the standards pin

`@maipai/standards` (this repo's `standards/`) is the enforceable half of
the org standards: gitleaks, the PII wordlist scan, the prose lint, and the
licence check, run via `standards/bin/check-core.sh`. Every platform repo
(`home`, `bot`, `catalog`, and `.github` itself) pins a `std-vX.Y.Z` tag and
calls the core from its own `scripts/check.sh`. See
[standards/README.md](../../standards/README.md) for the full contract.

## What to verify

1. **The repo's `scripts/check.sh` calls the core**, after its own
   build/lint/test steps, via `MAIPAI_STANDARDS_DIR` (defaulting to the
   sibling `.github` checkout) and `standards/bin/check-core.sh`.
2. **The pin is stated somewhere in the repo's dev docs** (which
   `std-vX.Y.Z` it targets), so a reader can tell whether it is current
   without re-deriving it.
3. **`MAIPAI_STANDARDS_DIR` points at a checkout on the pinned tag**, not
   just whatever `.github` happens to have on disk. On the dev machine this
   is normally true because there is one `.github` checkout; flag it if the
   local `.github` is ahead of the repo's stated pin in a way that matters
   (a new lint category that would now fail).
4. **`check.sh` actually passes**, run for real, not assumed from reading
   the script.

## The release skill's use of this

Per [`CLAUDE.md`](../../CLAUDE.md) > Releases, "the `release` skill refuses
a release in any repo whose `check.sh` is not on the current standards
tag." Run this skill's checks as part of that refusal logic: if the pin is
stale relative to a standards change that matters (not every `.github`
commit forces a bump, only ones that add or change an enforced check),
say so and stop before tagging.

## Proof this works

A deliberate em dash added to any tracked `.md` file in the target repo
must make `check.sh` fail. If it does not, the pin is broken (wrong
`MAIPAI_STANDARDS_DIR`, or a `check.sh` that swallows the core's exit
code) and that is the finding, not "standards check passed."
