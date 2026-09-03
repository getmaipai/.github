---
name: verify-screenshots
description: Run the two-pass AI review over a batch of generated screenshots (session open-and-confirm, then the pipeline's declared-expectation check) before they are used anywhere. Use after regenerating screenshots for the hub, robot, Go, or a catalog package, or when Jesse asks whether screenshots are actually right.
---

# Verify a batch of screenshots before they are used

Full rules: [docs/STYLE.md](../../docs/STYLE.md) > Platform screenshot
pipeline and the general screenshot rule in
[`CLAUDE.md`](../../CLAUDE.md) > Documentation. Two passes, both required,
neither is a substitute for the other.

## Pass 1: session review (do this every time, in every repo)

For every screenshot about to be embedded in docs, a README, an issue, or
shown to Jesse in chat: open the image (Read it) and confirm it shows the
intended screen, with real content, and no spinner, skeleton, empty state,
error banner, or wrong route. A picture of a loading spinner where a page
should be is not a screenshot of that page. A shot that fails gets its
capture fixed (wait for content, seed data, add an action) and re-taken.
Never embed, post, or describe a wrong shot as if it were right.

## Pass 2: pipeline review (platform repos with the generated pipeline)

Once a repo's screenshot script declares an expectation per shot (per
[docs/STYLE.md](../../docs/STYLE.md)):

1. Confirm the capture ran against fixed viewports (phone, tablet,
   desktop, TV, the Apple sizes) and fixed themes (default light, default
   dark, High Contrast). Anything outside that matrix is not part of the
   baseline set.
2. For each shot, read its declared expectation and answer it against the
   image with a vision-capable check (the hub's `vision` role in a
   platform repo, or the dev machine's vision model otherwise).
3. Write the verdict into the shot's manifest entry: model used, date,
   pass or fail.
4. A miss fails the build. Fix the capture script (never the image) and
   re-run from step 1 for that shot.
5. Check for clipping while you are looking: horizontal overflow, text
   outside its box, overlaps, undersized targets, anything wider than the
   viewport. This is the same check [UI.md](../../docs/UI.md) requires and
   there is no reason to look twice separately.

## Never real family data

Screenshots come only from the seeded demo household built from the
persona roster (see [`CLAUDE.md`](../../CLAUDE.md) > Privacy and PII). If a
screenshot shows anything that is not persona-roster data, that is a
privacy incident, not a retake: stop and flag it to Jesse before doing
anything else with that capture run.

## Report

State plainly which shots were reviewed, which pass they went through,
and which (if any) failed and were fixed. "Screenshots regenerated" alone
is not a status; "regenerated, session-reviewed, 2 fixed for wrong route"
is.
