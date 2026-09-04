---
name: verify
description: The MaiPai verification contract - what "verified" means before any commit in an org repo. Use before committing any nontrivial change, or when Jesse asks whether something was verified.
---

# Verify before commit

Org rule: never commit unverified work to `main`. "Verified" means all three
gates below pass.

## Gate 1: checks

Run `scripts/check.sh` at the repo root (lint, format, tests, gitleaks, PII
wordlist). It must exit clean. If the repo predates `check.sh`, run the
closest equivalents by hand and flag that the script is missing.

## Gate 2: exercised for real

Static success is not verification. Pick what applies:

- **Web/backend (home)**: drive the real app against an isolated instance
  (never the owner's live `data/`). The repo carries the launch recipe (see
  its `.claude/skills/` or dev docs); headless browser for UI, real HTTP for
  API changes.
- **Desktop**: build and launch the app; hit the changed surface.
- **Go (TV/phone)**: build and install to the device via the local build
  script; exercise the change on screen.
- **Bot**: tests pass; hardware-dependent behavior is flagged as untestable
  until hardware exists.
- **Docs-only**: build the docs site; check the changed pages render.
- **Anything graphical**: actually look at it (screenshot per the org
  screenshot rules, or a live browser/simulator pass), not just a green
  build. A UI change is not exercised until someone (you) has seen the
  pixels.

**Never ask Jesse to do Gate 2 for you.** "Can you check if this looks
right" or "can you try this" before you have tried it yourself is not a
verification report, it is skipping the gate and handing it to him. Run
it, look at it, then report what you saw. If a specific piece truly needs
his hardware, device, or judgment, say precisely which piece and why the
rest is already verified.

## Gate 3: what the diff removes, not just what it claims

A fix that stops the reported symptom by deleting a check, loosening a
condition, widening a permission, or dropping a case is not a fix; it is
the same bug wearing the report's exact fingerprint. Before calling
something verified, read the diff once specifically for what it takes
away (a validation, a test, an error path, a scope restriction) and
confirm each removal is intentional and correct, not the shortest path to
a green run.

## Report

State plainly in the status block what was verified and how (which script,
which device, which flow). "It compiles" or "should work" is a blocked state,
not a done state.
