# Verification and testing

Dev tier. Full definition of done and the testing standards, with the dated reasons. Hooks that enforce parts of it: `require-gate-before-commit.sh`, `mark-gate-checked.sh` (see `plugin/hooks/README.md`); `gate-lock.sh` and `check-core.sh` in `standards/bin/`. Load before gating, benching, writing tests, or claiming something is done.

## The gate: check.sh per push, not per commit (owner's rule, 2026-09-23)

Every repo exposes **`scripts/check.sh`**: lint + format check + tests +
gitleaks + the PII wordlist scan (below). **It must pass on the tree a
push sends, before that push (owner's rule, 2026-09-23: gate per push,
not per commit).** A lane may make several commits from one gated
tree: edit the block of items, run the gate once on the whole tree,
then commit each logical change on its own from that unchanged tree,
then push; a further edit after the gate means the gate runs again
before the push. Each commit stays one logical change with its own
message and docs; what is proven green is the tip that reaches
`main`. Why: on 2026-09-23 four S items each paid a four-minute
backend gate plus a review and a report to land, and the lanes spent
more time waiting on gates than typing. The docs-only case is
unchanged: a commit that touches only docs (Markdown, a prompt, a
backlog line) needs the standards core (prose lint, PII wordlist,
gitleaks, `standards/bin/check-core.sh`), which runs in seconds.

## Scoped gates (owner's rule, 2026-09-23)

**Scoped gates (owner's rule, 2026-09-23).** The gate runs the checks the
diff can touch, decided from the working tree's diff against the
merge-base with `origin/main` (a commit is staged and made in one step
in this workflow, so a staged-only diff would usually be empty), plus a
check that no frontend file imports backend code, never by a session's
own judgment: a diff confined to the
frontend runs the frontend lint, tests and build; a diff confined to the
backend runs the backend suite; a docs-only diff runs the standards core
(already the rule); a diff that crosses packages, or touches shared
config, a pin, a lockfile, `scripts/`, or a spec workspace, runs the full
gate. The secrets scan and the PII wordlist run on every scope. Why: on
2026-09-22 to 23 four sessions landed about thirty mostly frontend-only
commits through one four-minute full gate, one at a time, with flaky
reruns, and each item waited twenty to sixty minutes from done to live
behind a backend suite no frontend file can break. `check.sh` prints the
scope it chose and why in its first line, and the done report repeats it.

## One full gate at a time, enforced by a real lock

**One full gate at a time on a shared machine, enforced by a real lock
(2026-09-21, mechanized 2026-09-27).** Two full `check.sh` runs at
once on the dev machine, beside the running hub's engines, put the
OS under memory pressure and made one run fail on an ephemeral port
("Failed to start server. Is port 0 in use?") in a test the change
never touched. The advisory form of this rule (a session self-
policing a `pgrep` check before starting) held up only as long as a
handful of sessions were actively watching each other; by
2026-09-27, with several peer sessions each dispatching their own
agents, it produced sessions stuck reporting "waiting" on a gate
that had already freed, with nothing to wake them (see
[DECISIONS.md](DECISIONS.md), 2026-09-27). `check.sh` now calls
`@maipai/standards`'s `bin/gate-lock.sh` before any non-`docs`
scope: it takes a real machine-wide mutex
(`~/.local/state/maipai/gate-lock/`, not per-repo), queues a waiter
FIFO instead of racing a bare `pgrep` the instant the pattern looks
clear, and releases in an `EXIT` trap so a killed gate frees the
slot. A session never hand-rolls the wait itself; it runs
`scripts/check.sh` and the lock is transparent. The docs-only gate
(seconds, no server) still runs beside anything, untouched by the
lock. A gate that fails only in a test the diff did not touch, with
a port or memory error, is rerun once alone before anything is
concluded; a second such failure is reported as an environment
finding, never fixed forward in the test. **The hold for a live measurement is narrow (owner's
rule, 2026-09-23):** a gate waits for a running bench only when that
bench measures time (a latency row, a wall-time table, the U6 rerun)
or Jesse has called a hold; a bench that measures tokens, ratios,
pass/fail or reply text (the parity and bisect arms, a replay of
outcomes) runs beside a gate, and the bench's own record names which
kind it is. Why: the port clashes that started the rule were fixed by
FLAKE-PORT-01, and on 2026-09-23 a lane waited an hour behind a
token-count measurement the gate could not have disturbed.

## Checks never change the machine; browsers are headless

**A check, test, bench, or screenshot script never changes the machine
outside the repo and its own data directory.** No system preferences
(`defaults write`), no global config, no installs, no environment
left behind, even wrapped in a restore step: a killed run leaves the
change in place, and the next contributor's OS will not have it. If
the behavior under test depends on a machine setting, the script
drives the equivalent through the browser or the tool (WebKit's
Option+Tab instead of Full Keyboard Access, 2026-09-12) or skips with
a stated reason. A session never launches a browser with a visible
window: headless only, and if a headless engine cannot start after
one retry, that is the recorded finding, not a reason to try a
window (2026-09-13: a non-headless Playwright Firefox put its own
"profile cannot be loaded" dialog on Jesse's screen).

## A universal claim needs an inventory

**A universal claim needs an inventory.** A change that promises
"every reply", "one boundary", or "never enters" is done when its
commit enumerates every producer or consumer the promise covers and
tests each, failure paths included; its own tests passing proves the
work order, not the promise. A bench's printed metric is the metric
its code computes, or it is renamed. A claim about what a library
does is verified in the installed source and the line cited.

## Evidence matches the acceptance criterion

**Evidence matches the acceptance criterion.** A deterministic behavior
change is proven by its regression test; a UI change by the flow
exercised and the screenshot opened and judged; a performance,
model, or hardware change by measured numbers with the engine build,
model file, and a sanitized hardware description (never a hostname)
recorded in the dev docs. Live numbers are required when the item's
acceptance names them, not for every item.

## Verified means exercised for real

"Verified" also means **exercised for real**: the feature was hit in the
running app, the build installed on the target device, or the tests cover
the change. "It compiles" is not verified.

## Never hand Jesse something unchecked

**Never hand Jesse something to check that you have not checked yourself
first.** This applies to every kind of change, functional or graphical:
run the app, drive the flow, look at the screenshot, read the log,
whatever proves it. A change is not "done, can you confirm" until you
already have; if you genuinely cannot verify something yourself (real
hardware only Jesse has, a judgment call that is his to make), say
exactly that and why, rather than silently skipping the check.

## Never ask Jesse to run a command you can run

**Never ask Jesse to run a command you can run yourself.** If a command
is runnable from here, run it. Ask him to run something only when it
truly requires his own session, device, or credentials (an interactive
login, a physical action).

## A second "try it again" needs re-read proof (owner's rule, 2026-09-27)

**A second "try it again" needs re-read proof, not a repeated hope
(owner's rule, 2026-09-27).** The first time a live symptom is fixed,
a dispatched session's own live-run report is real evidence. The
moment that same symptom comes back after a "fixed, try again" was
already sent, the bar changes: the next message to Jesse is not sent
on a green gate or a subagent's own claim alone. The coordinator
reads the actual evidence itself first (the stored record, the
quoted model output, the real file), confirms it says what's
claimed, and only then says anything is ready. Telling Jesse to
retry something on hope, twice, is worse than taking longer once
(2026-09-27: a `start_project` incident got "fixed, try again" sent
twice before the real cause, a second forced model round with the
wrong prompt entirely, was found by reading the actual stored turn
directly).

## Clean-clone build at release

At release time, the release skill additionally does a **clean-clone build**
(fresh clone in a temp dir must build and boot) to catch works-on-my-machine
and over-eager gitignore mistakes.

## Testing: purpose

Tests are how a change proves it works and stays working. The rules are the
same in every repo; the tools differ per language, and you use the repo's, not
your own.

## Testing: use the repo's framework

**Use the framework the repo already uses. Never stand up a second one.**
Python repos use **pytest** (async tests via the repo's existing marker,
e.g. `pytestmark = pytest.mark.asyncio`); TypeScript repos use **`bun:test`**
(`import { describe, expect, test } from 'bun:test'`). Do not add jest,
vitest, unittest, a shell-script harness, or a hand-rolled runner beside the
one that is there. If a repo has no tests yet, match the language's standard
(pytest / bun:test) before inventing anything.

## Testing: match existing test files

**Match the existing test files, not just the framework.** Before writing a
test, read a nearby test in the same area and copy its structure: the same
helpers and fixtures, the same way it builds the system under test, the same
naming and assertion style. A new private harness or a bespoke way to drive
the code is itself a smell, even when it is pytest underneath. Reuse the
real construction path the app uses (the Bot's `build_dialogue`, Home's real
handlers) rather than a parallel one that can drift from production.

## Testing: deterministic and offline by default

**Deterministic and offline by default.** A unit test does not call a live
model, a network service, or real hardware; it drives the code with a
scripted stand-in and asserts behavior. Slow, live, or hardware-in-the-loop
checks are separate, explicitly-run benches, never part of the per-commit
suite. The Bot's split is the pattern: a small deterministic suite in
`check.sh` on every commit, and a large model-driven bench run on demand.

## Testing: every real failure becomes a regression test, first

**Every real failure becomes a permanent regression test, first.** A bug
found in a running product is reproduced as a failing test before it is
fixed, in the exact words or inputs that broke it, and the test stays
forever. This is the one rule that turns "I test and tell you what broke"
into a suite that catches it next time.

## Testing: assert behavior a person cares about

**A test asserts behavior a person cares about**, not the shape of the
implementation. Name it for the promise it checks. If the assertion would
still pass while the feature is visibly broken, it is testing the wrong
thing.

## Testing: check.sh must pass before every commit

**`scripts/check.sh` runs the suite and must pass before every commit.** A
test you added is not done until the whole suite is green; a test you had to
weaken to pass is a finding to raise, not a step to skip.
