# MaiPai org standards

Standards for every repo in the `getmaipai` org. Each repo's own CLAUDE.md holds
only project specifics; everything here applies org-wide. If a repo file
contradicts this one, the repo file wins for that repo, but flag the conflict.

## The products

The platform is being rebuilt fresh on the design in `home/spec/design/`
(seeded from the platform plan). On 2026-09-03, `home` and `bot` were reset
to a clean history to start over on that design: the pre-rebuild code is
not on GitHub at all, only a full local git mirror of each
(`legacy-backups/home-legacy.git`, `legacy-backups/bot-legacy.git`, next to
the working checkouts on the dev machine, never pushed anywhere), kept
only as a reference to copy hard-won logic from, never a requirement of
feature scope. `home`'s 21 pre-rebuild releases were deleted from GitHub;
their metadata (tags, notes, asset lists with sha256, no binaries) is
backed up alongside the mirror. Build order: hub first, robot for parity,
Go last; the Stack (2026-09-20, superseding the 2026-09-17 product
framing) is Home's engine layer as a private daemon inside Home's
release, proven on the Studio beside the hub before Home moves onto it.
The libraries every product imports (`ui`, `core`, `spec`) live in
`commons`, the one public library repo.

| Repo | Product | What it is |
|---|---|---|
| `stack` | MaiPai Stack | The engine foundation of MaiPai Home: the headless service that installs, sizes, runs, watches, updates and tests the engines and models behind Home, and gives Home one stable address by role. It has no interface and no users of its own; Home is its only caller. Ships inside Home's installer, updates with Home's releases. |
| `commons` | (libraries) | The three packages every product imports, tagged on their own: `ui` (`@maipai/ui`: the kit, tokens, icons, the shell, the settings and permission renderers), `core` (`@maipai/core`: log, paths, secrets, the hardware probe and the other backend helpers), `spec` (`@maipai/spec`: the shared record shapes, schemas, fixtures and the Python package). Imported by `stack`, `home` and `catalog`; `bot` and `go` pin `spec`. Nothing in it imports a product. Public, so the Catalog's contributors and CI can read the shapes. |
| `home` | MaiPai Home | The self-hosted family AI hub: the platform and the household's master (identity, people, memory, the turn engine, settings, the package host, the shell). Every feature ships as a catalog package. |
| `catalog` | MaiPai Catalog | The public package catalog: every plugin, app, companion, integration, model, wake word, voice, and theme, signed and indexed. Hub and robot install from it. Pins `spec` from `commons` for the manifest shapes; keeps no schema mirror of its own. |
| `go` | MaiPai Go | Apple TV and iPhone client. Renders the same UI schema natively. Built last, once the hub and robot have packages with schema pages. |
| `bot` | MaiPai Bot | Robot companion. Pairs with the hub like a pod (a full replica, the hub as its brain when reachable), stands alone complete when not. Bench-proven, rebuilt fresh on the platform design. |
| `.github` | (this repo) | Org standards, `@maipai/standards` tooling, the shared Claude plugin, org profile |

MaiPai's promise: private, local AI that's actually yours. Nothing leaves the
home. Every technical and product decision honors that.

Product descriptions come verbatim from [brand/COPY.md](brand/COPY.md), the
single source for pitch copy (repo description fields, org profile, READMEs,
docs). Logos come from [brand/](brand/), never redrawn. **A GitHub repo
description is succinct (2026-09-20):** one sentence, at most 120
characters, in COPY.md under the product as its "repo description"; the
longer one-liner is for READMEs, the profile and docs, never the
description field (GitHub truncates it in lists and search, and a
description that reads as a paragraph reads as marketing).

## Platform principles

These hold across `home`, `bot`, `catalog`, and `go`. Full detail in the
platform plan; this is the standing summary every session should carry.

1. **Simplify: centralize and reuse.** One definition, one implementation,
   one store. A second copy of anything is wrong even when it is faster.
2. **The robot is complete without a hub**, disconnected for an hour or never
   paired. Its own people, settings, memories, companions, packages, and the
   integrations it can hold itself. Nothing on it is a stub.
3. **No data debt.** Every record either product writes is the shared spec
   shape, with id, provenance, and clock stamp, from the first boot. Pairing
   later is a transfer, never a translation.
4. **One definition, one place.** A settings key, a record type, a package's
   config, an integration's shape, a companion's metadata: each is declared
   exactly once, and every renderer draws from the declaration.
5. **Repos only when necessary.** A new repo needs a different release
   cadence, a different committer audience, or a different visibility.
6. **Prebuilt over hand-built.** One component library, one icon set, one
   engine, maintained parts assembled by us, and the org standards enforced
   by lint and tests, never by memory. The same rule past the UI: a native
   capability the mandated engine already has, or a maintained library for
   a solved problem, beats hand-rolled logic doing the identical job. A
   large system prompt standing in for a real technique (activation
   steering instead of a paragraph of personality prose, a text-
   normalization library instead of asking the model to spell out numbers
   reliably) is hand-built too, and loses to the prebuilt answer on the
   same terms: slower, more tokens, less predictable.
   **No hand-built UI, from 2026-09-21 on (owner's rule).** Every
   surface is a shipped component used exactly as it ships: an
   assistant-ui Element for anything a chat or an assistant does, a
   kit primitive (the vendored shadcn set) or a kit block composed of
   those for everything else. A component written by hand where a
   maintained one exists is a defect, found in review and replaced,
   never kept because it already works; a shipped component is never
   edited (the kit wraps and composes, it does not fork), and the
   look comes only from the tokens the component already reads. When
   nothing shipped does the job, the gap is named in the design record
   before a line is written, and the smallest composition of shipped
   parts wins. Why: the chat rebuilt by hand on assistant-ui's runtime
   (2026-09-13 to 2026-09-21) was ugly and buggy where the library's
   own Elements were neither, and every hand-built piece cost review
   rounds the shipped one would not have.
7. **Hub first, robot for parity, Go last.** Every hub step is in family use
   before its robot counterpart; nothing early may close the door on the
   later clients. The Stack sits under all three and follows the same
   rule: it is in family use the day Home runs on it, and nothing moves
   out of Home before the Stack has proven the hub's profile on the
   Studio.
8. **Every feature is reviewed and rebuilt, never carried.** No existing app,
   plugin, or screen is a requirement by virtue of existing in the legacy
   code. Each is re-examined (does the family use it, does it fit a package,
   what is the right design now), then rebuilt as designed, redesigned,
   merged, or dropped, with a one-line verdict recorded in the fresh repo's
   dev docs before it is built. "Copy from legacy" applies only to hard-won
   logic (resolvers, sync, limiters, drivers, measurements), never to
   feature scope or UI.

**Shared record changes go through the spec first.** Anything in
`home/spec/` (Person, Setting, Memory, the manifest and recipe shapes, the
link API, the UI schema) is edited in the spec, then implemented on the hub,
then on the robot. A hub-only or robot-only patch to a spec-shaped record is
a bug: the shapes drift and the round-trip fixtures catch it.

**Resolve design ambiguity before asking, when it is genuinely
resolvable.** When the platform plan, a spec, or a standard is silent or
seems to conflict with itself, that is usually not a question for Jesse:
it is a research task. Dispatch the `design-resolver` agent (`plugin/
agents/design-resolver.md`, opus) to read every relevant passage, find the
pattern, and come back with a concrete decision and its reasoning, before
reaching for a clarifying question. Escalate to Jesse only for what the
agent itself reports as genuinely low-confidence, or for what was already
his call to begin with (releases, deploys, go/no-go, review verdicts, a
real-world fact only he knows). A clarifying question that a closer
reading would have answered is a round trip that did not need to happen.

## Roles: coordinator and coder (hard rule, 2026-09-12)

Two roles, held by different sessions. This section is the policy; the
`coordinate` skill in the maipai plugin
(`plugin/skills/coordinate/SKILL.md`) is the procedure. A session knows
which model it runs on from its own system prompt. Fable always holds
the coordinator role ([docs/DECISIONS.md](docs/DECISIONS.md),
2026-09-12: a day of the most expensive model doing coder work); Sonnet
or Opus may hold it when Jesse says so.

- **The coordinator architects, designs, and diagnoses; it never types
  the code and never runs a long-running process.** It makes the
  platform decisions, writes the design notes and the programs of
  work, decides what gets built and in what order, reads the code and
  the logs to find the real cause of a hard problem and names the fix,
  chooses between approaches, writes the work order and the prompt for
  the session that will do it, and checks the evidence when it comes
  back. It does not edit source or test files,
  does not write scripts, does not run test suites, benches, engines,
  builds, or `check.sh`, and does not spawn or babysit servers. Quick,
  read-only inspection is fine: `grep`, `git log`, reading a file, a
  command that returns in seconds. When it finds itself about to edit
  code or start a bench, it stops and writes the prompt instead.
- **The coordinator may still write docs**, because a design record, a
  backlog item, an issue, or a handoff note is what its job produces
  (doc-only commits: see Verification).
- **When directing sessions, the coordinator manages their context,
  handles their questions and blockers, and drives their work to
  completion.** It is event-driven, never polled: every work order
  carries the reporting contract (ready, done, blocked, question, low
  context), and a session starts only on the coordinator's start
  message after its ready report. On done the coordinator verifies the
  completion report against the item's acceptance before ticking
  anything; on blocked it classifies the blocker before choosing a
  remedy; on a question it decides or dispatches `design-resolver`; on
  low context it writes the handoff note and hands it to Jesse for a
  fresh session. Parallel lanes have one named integrator that merges
  serially, reconciles shared docs, and verifies the combined `main`.
- **Small isolated items go to one of two token-free lanes first, never
  straight to a Claude session as typing work** (2026-09-15,
  [docs/DECISIONS.md](docs/DECISIONS.md), reaffirmed 2026-09-20): the
  household's local coding model (Qwen3.8-27B) through its one OpenCode
  session, or Codex in Jesse's visible window driven over tmux by the
  coordinator; the `coordinate` skill's section 1b is the procedure for
  both, including the health check before routing to the local model
  (it costs nothing when up, but nothing routes to it while it is down
  or the coordinator has not confirmed it is running). Each takes only
  an S or small M item whose brief names every file, rule, test and
  command, works in its own worktree at the base the coordinator
  picks, commits only and never pushes, and every result is read by
  the coordinator (the diff, the checks rerun) before it is stacked.
  Anything needing a decision, a diagnosis or a read across
  subsystems stays with a Claude session at the model floor. A red
  gate means stop and report, never push. (The first local-model try
  of 2026-09-13 was retired for the reasons in DECISIONS.md; the
  2026-09-14 lane fixed them with a fresh worktree per item, a scratch
  working directory and git denies.) A lane that is producing more
  fix-up rounds than clean lands over a week reverts to Claude-floor
  routing for its class of item until re-tried; this is a standing
  check, not a one-time call (2026-09-13 retired the lane on exactly
  this measure, 2026-09-15 revived it once the cause was fixed).
- **Model floor per item** (the one authoritative table; the skill
  points here) is the floor for whichever session actually does the
  typing, Claude or not: Haiku is the floor only when both token-free
  lanes are unavailable (down, or the item needs Claude Code tool
  access neither lane has) and the item is otherwise an S item with
  one clear change and a mechanical check; Sonnet for any M item,
  anything with a verification loop (screenshots to open, a bench to
  run, a guard to prove), or anything that closes an issue; Opus for
  an item whose blocker was classified as a reasoning failure, that
  needs a live measurement plus judgment, or that spans subsystems.
  The agent list's label and a commit's co-author line are hints, not
  proof; the session's own report of the model named in its system
  prompt is the check, made before work starts, and "unknown" is an
  allowed answer that the coordinator resolves with Jesse. A model
  change is the remedy for a reasoning failure only: context
  exhaustion gets a handoff, an environmental blocker gets fixed, an
  unclear requirement gets a decision. When the strongest permitted
  model stalls, the item is re-scoped (chunked, or given a design
  note) rather than retried.
- **Coder sessions are launched with
  `claude --dangerously-skip-permissions`**, so no one sits clicking
  approve; the worktree, port, and data-directory isolation in the
  work order is what keeps that safe. A session found asking for
  approvals is restarted with the flag and `--continue`.
- **At a stop point, make the state durable, then reset the context.**
  When a block of work is finished and the next has not started, the
  session first confirms the status is written down (docs, backlog,
  the handoff note, memory pointing at it), then recommends one of two
  things: compact and continue, when the next item continues this one
  and unwritten working detail would be lost; or a fresh session with
  the handoff note, when the next item is a different task.

## Git workflow

- **All work lands directly on `main`. Never open pull requests.** The remote is
  publishing and backup, not a review step.
- **The one carve-out: `catalog` accepts community pull requests**, gated on
  the signed copyright assignment and CI (manifest lint, permission diff,
  banned-API scan, recipe conformance, licence check, the scorecard). This
  is how outside contributors submit packages. Maintainers still land their
  own work directly on `main`, same as every other repo.
- **Never create a branch or worktree** unless Jesse explicitly asks, or a
  second session is actively editing the same repo in parallel. If one was
  needed, merge it and delete it before the session ends. A branch that
  outlives its session is a bug. If you notice a stray branch or worktree,
  flag it for cleanup.
- **Commit only completed, verified work** (see Verification below). One commit
  per logical change. No checkpoint commits, no WIP commits: if work is
  unfinished at session end, the honest state is a dirty tree plus a status
  note, not a commit.
- **Never stage or commit blindly.** Run `git status` (and `git diff` for
  what actually changed) first, then stage specific files by name. Never
  `git add -A`, `git add .`, or `git commit -a` without having just looked
  at what that would sweep in: a parallel session's in-progress work in a
  shared checkout, a stray file, or something that should stay uncommitted.
  The `maipai` plugin's `block-blind-staging.sh` hook enforces this
  mechanically (`plugin/hooks/README.md`); it denies the blind form when no
  recent `git status` exists to point to, not the command itself.
  **In a shared checkout the commit is atomic with the staging.**
  Stage exactly what is yours (`git add <file>` for a file only you
  changed, `git add -p` for a shared doc), read `git diff --cached
  --stat` and confirm it lists only yours, then commit immediately
  with a bare `git commit`; never leave anything staged for later,
  and never commit while another session's hunks sit in the index.
  Do not use `git commit -- <files>` on a shared file: a pathspec
  commit takes the file from the working tree, not the index, so it
  sweeps the other session's uncommitted hunks in and defeats the
  `git add -p` you just did (2026-09-13: it happened both ways in one
  evening, a bare commit that took Session A's staged code under a
  docs title, then a pathspec commit that took A's unstaged backlog
  hunks). After every commit, `git show --stat HEAD` is read before
  the done report.
- **Run a code review before committing code** (not a doc-only change): the
  `code-review` skill, at least medium effort, on the diff about to be
  committed. In a worktree, pass the review an explicit target (the
  worktree path or the branch) and read the path and branch the review
  reports before acting on a single finding: the review runs in a
  forked subagent whose working directory can resolve to the main
  checkout, and on 2026-09-12 one reviewed another session's
  uncommitted work that way. A review whose reported path is not yours
  is discarded and re-run with the target; its findings go to that
  file's owner, never acted on by you. This is not a "remember to do it" rule: the `maipai` plugin's
  `require-review-before-commit.sh` hook enforces it mechanically
  (`plugin/hooks/README.md`), the same shape as the blind-staging gate,
  because a session remembering to review its own work does not survive a
  fresh session picking the task back up.
  **Reviews are budgeted (2026-09-20).** One review invocation fans out
  several subagents at roughly 100k tokens each, and on 2026-09-20 one
  session ran three full passes per item, close to two million tokens
  of review for a single S item, with four of five subagents stuck
  searching for a tool. So: the level matches the item (`low` for an S
  item or a docs-and-config change, `medium` for an M item or anything
  that changes a route, a guard, or a wire shape, `high` only when the
  coordinator names it); one pass per commit; after fixing findings the
  re-review covers the fix hunks only (`git diff` of those files
  against the reviewed state), never the whole diff again, and a third
  pass never happens (a second pass that still finds real defects is a
  finding about the item, reported to the coordinator, not a reason to
  loop); a review whose subagents are "searching for" a tool or a file
  for more than a minute is stopped and rerun once with the target
  path, never left to run out its budget. The done report states the
  level, the pass count and each finding's disposition, so the
  coordinator can see the budget was kept.
- **Push at natural boundaries** (a verified item merged to `main`, the end
  of a work session, or when Jesse says ship), never reflexively after
  every commit. A push needs no approval; a push that fails is reported
  as blocked like anything else.
- **Deploys and releases are always explicit.** Cutting a release or rolling
  the hub requires Jesse's word in the moment.
- **Author identity:** Jesse's name is public and fine. His email is not:
  commits use the GitHub noreply address, and no personal email ever appears
  in code, docs, or package metadata.

## Verification (definition of done)

- Every repo exposes **`scripts/check.sh`**: lint + format check + tests +
  gitleaks + the PII wordlist scan (below). It must pass before any commit.
  The one exception: a commit that touches only docs (Markdown, a prompt,
  a backlog line) needs the standards core (prose lint, PII wordlist,
  gitleaks, `standards/bin/check-core.sh`), which runs in seconds.
- **A check, test, bench, or screenshot script never changes the machine
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
- **A universal claim needs an inventory.** A change that promises
  "every reply", "one boundary", or "never enters" is done when its
  commit enumerates every producer or consumer the promise covers and
  tests each, failure paths included; its own tests passing proves the
  work order, not the promise. A bench's printed metric is the metric
  its code computes, or it is renamed. A claim about what a library
  does is verified in the installed source and the line cited.
- **Evidence matches the acceptance criterion.** A deterministic behavior
  change is proven by its regression test; a UI change by the flow
  exercised and the screenshot opened and judged; a performance,
  model, or hardware change by measured numbers with the engine build,
  model file, and a sanitized hardware description (never a hostname)
  recorded in the dev docs. Live numbers are required when the item's
  acceptance names them, not for every item.
- "Verified" also means **exercised for real**: the feature was hit in the
  running app, the build installed on the target device, or the tests cover
  the change. "It compiles" is not verified.
- **Never hand Jesse something to check that you have not checked yourself
  first.** This applies to every kind of change, functional or graphical:
  run the app, drive the flow, look at the screenshot, read the log,
  whatever proves it. A change is not "done, can you confirm" until you
  already have; if you genuinely cannot verify something yourself (real
  hardware only Jesse has, a judgment call that is his to make), say
  exactly that and why, rather than silently skipping the check.
- **Never ask Jesse to run a command you can run yourself.** If a command
  is runnable from here, run it. Ask him to run something only when it
  truly requires his own session, device, or credentials (an interactive
  login, a physical action).
- At release time, the release skill additionally does a **clean-clone build**
  (fresh clone in a temp dir must build and boot) to catch works-on-my-machine
  and over-eager gitignore mistakes.

## Testing standards

Tests are how a change proves it works and stays working. The rules are the
same in every repo; the tools differ per language, and you use the repo's, not
your own.

- **Use the framework the repo already uses. Never stand up a second one.**
  Python repos use **pytest** (async tests via the repo's existing marker,
  e.g. `pytestmark = pytest.mark.asyncio`); TypeScript repos use **`bun:test`**
  (`import { describe, expect, test } from 'bun:test'`). Do not add jest,
  vitest, unittest, a shell-script harness, or a hand-rolled runner beside the
  one that is there. If a repo has no tests yet, match the language's standard
  (pytest / bun:test) before inventing anything.
- **Match the existing test files, not just the framework.** Before writing a
  test, read a nearby test in the same area and copy its structure: the same
  helpers and fixtures, the same way it builds the system under test, the same
  naming and assertion style. A new private harness or a bespoke way to drive
  the code is itself a smell, even when it is pytest underneath. Reuse the
  real construction path the app uses (the Bot's `build_dialogue`, Home's real
  handlers) rather than a parallel one that can drift from production.
- **Deterministic and offline by default.** A unit test does not call a live
  model, a network service, or real hardware; it drives the code with a
  scripted stand-in and asserts behavior. Slow, live, or hardware-in-the-loop
  checks are separate, explicitly-run benches, never part of the per-commit
  suite. The Bot's split is the pattern: a small deterministic suite in
  `check.sh` on every commit, and a large model-driven bench run on demand.
- **Every real failure becomes a permanent regression test, first.** A bug
  found in a running product is reproduced as a failing test before it is
  fixed, in the exact words or inputs that broke it, and the test stays
  forever. This is the one rule that turns "I test and tell you what broke"
  into a suite that catches it next time.
- **A test asserts behavior a person cares about**, not the shape of the
  implementation. Name it for the promise it checks. If the assertion would
  still pass while the feature is visibly broken, it is testing the wrong
  thing.
- **`scripts/check.sh` runs the suite and must pass before every commit.** A
  test you added is not done until the whole suite is green; a test you had to
  weaken to pass is a finding to raise, not a step to skip.

## Documentation

- **Claude writes all documentation prose.** Jesse gives feedback,
  instructions, and occasionally a sentence to work in verbatim; he never
  types documentation himself. Never ask permission to document.
- **Docs update in the same commit as the change they describe.** A commit
  that changes behavior while the docs still describe the old behavior is
  incomplete.
- **Build guides use the final parts, never interim ones.** A step uses the
  part, cable, or mount the finished product uses, so nothing is redone
  later. An interim part appears only with a stated reason on the page and
  a note on what replaces it and when.
- **Never put owner-specific notes in the docs.** Anything that exists only
  because of Jesse's own setup or inventory ("check whether your drive is
  SATA or NVMe", "note it for the hardware record", "tell us which one
  worked", his hosts, his parts' quirks) stays out of every tier. Docs
  address a reader who has the product or bought the listed parts. Owner
  reminders go in the session status block or a GitHub issue.
- **Scratch and private notes live inside the repo they belong to, in a
  git-ignored folder** (`home` uses `data-scratch/`, covered by its
  `data-*/` ignore rule), never at the org root, never above it. The
  folder above the org is the source-control service's; the org root
  holds only the repos, the standards checkout, and the two symlinks.
  A throwaway gate worktree is created beside the repo for one gate and
  removed the moment it ends.
- **Three tiers**, per [docs/STYLE.md](docs/STYLE.md):
  - `user/`: for dads with basic tech knowledge. Grade-6 reading level, no
    jargon, one action per step, screenshots over prose.
  - `dev/`: fully technical. Architecture, contributing, decisions.
  - `api/`: generated, never hand-written (next point).
- **APIs are self-documenting:** Hono routes defined with Zod schemas via
  `@hono/zod-openapi`, producing an OpenAPI spec served with an interactive
  explorer at `/api/docs`. Any route you touch gets converted to this style
  as part of touching it.
- **Screenshots are generated, never hand-taken:** a scripted run against a
  seeded demo household (see Privacy). If a screenshot is stale, fix the
  script, not the image.
- **Every screenshot gets looked at before it is used, anywhere.** Open the
  image (Read it) and confirm it shows what it claims: the intended screen,
  with real content, no spinner, skeleton, empty state, error banner, or
  wrong route. A picture of a loading spinner where the Videos app should
  be is not a screenshot of the Videos app. This applies to docs, READMEs,
  issues, and screenshots shown to Jesse in chat. A shot that is wrong gets
  its capture fixed (wait for content, seed data, add an action) and is
  re-taken; it is never embedded, posted, or described as if it were right.

## Writing style (AI writing standards)

Everything we write should read like a sharp human wrote it, not a model.
These apply to docs, UI copy, comments, commit messages, changelogs, issues.

- **No em dashes (U+2014), ever.** Use a comma, colon, parentheses, or a
  period. En dashes only for numeric ranges. This is the number one
  machine-generated tell.
- **No AI filler vocabulary:** delve, seamless, robust, leverage, empower, elevate, streamline, game-changer, "in today's world", "it's important to note". Say the plain thing instead. <!-- prose-lint: allow -->
- **No "not just X, it's Y" constructions**, no rhetorical questions as transitions, no exclamation points in technical prose. <!-- prose-lint: allow -->
- **Bullets are for lists of things, not for prose.** If the bullets read as
  sentences that flow, write a paragraph.
- Prefer concrete over abstract: "boots in 4 seconds" beats "highly
  performant". Numbers, names, and file paths beat adjectives.
- User-facing copy passes the dad test: would a busy parent with basic tech
  knowledge understand it on first read, without feeling stupid?
- **End every reply to Jesse with the status block** (2026-09-14
  shape): three lines, uppercase labels, in this order, nothing after
  it. `STATE:` opens with one word, `active`, `waiting` or
  `blocked [<owner>: <what>]`, then each session with its item and
  condition in parentheses (running with a time, holding and behind
  what, blocked), and `landed <item>` when something shipped since
  the last block. `PROGRESS:` the path to the current milestone on
  one line: its name, a bar of done and remaining items, the count,
  `now` and `next` in order. `YOU:` the only place an ask ever
  appears: `nothing`, or each ask tagged `(whenever)` or
  `(blocking: <what it holds>)`, written so a reader who saw no
  earlier message can act on it (the exact command or decision,
  never "still yours"). `blocked` is used only when work has stopped
  and always names the owner; a fact that stops nothing is never a
  block.

## Privacy and PII (hard rules)

- **Never commit:** family member names, home address, phone numbers,
  personal email addresses, credentials or tokens, real LAN IPs or homelab
  hostnames. Jesse's own name is the one allowed exception.
- **Example values:** IPs from documentation ranges (`192.0.2.x`), domains
  `example.com`, and people/persona names ONLY from the roster below.
- **Persona roster** (use for demo households, docs examples, fixtures):
  alfred, astro, atlas, bramble, bruno, clover, cosmo, daisy, ember, indigo,
  iris, juniper, lucia, marlow, marsh, mopey, nadia, nova, oliver, pippa, quill, raven, riff, rivet, rover, sage, serena, sprout, tempo,
  velvet, vincent, willow.
- Homelab details (hosts, containers, IPs, topology) live only in Jesse's
  private homelab repo, referenced but never embedded here.
- `check.sh` enforces this: gitleaks for secrets, plus a word-boundary grep of
  the staged diff against the private wordlist at
  `~/.config/maipai/pii-words.txt` (that file is never committed anywhere).
- Screenshots and seeded demo data must never contain the real family's
  profiles, history, or location.

## Releases

- Semver tags (`vX.Y.Z`), a GitHub Release, and a `CHANGELOG.md` in
  Keep a Changelog format, per repo. **Users touch releases, never `main`.**
- The hub deploys from the latest release tag, not from `main` (so `main` can
  break without breaking the house). Cutting a release is the deploy button;
  re-pointing to the previous tag is the rollback.
- Everything stays `0.x` until the product passes its battle-tested checklist
  (kept in that repo's dev docs); `v1.0.0` means it earned it.
- The `release` skill in the maipai plugin runs the whole ceremony: checks,
  clean-clone build, changelog from commits since the last tag, screenshot
  regeneration, docs drift check, tag, GitHub release.
- **Release notes are the changelog, nothing more.** The only preamble is
  one short quoted line of links (install guide for new users, the update
  page for existing ones, what any attached files are), then "What
  changed". No instruction blocks in release notes, and no workflow ever
  writes a release body: notes own the page.
- Downloadable model packs and large binaries ship as release assets, not
  tracked files.

## Security

- **No push-triggered GitHub Actions in private repos** (billed minutes).
  Public repos may keep cheap tag- or docs-triggered workflows. Checks run
  locally via `check.sh` instead of CI.
- Dependabot alerts on everywhere; Dependabot PRs off (they fight the no-PR
  workflow). Instead: a monthly local dependency sweep, updating and
  re-verifying via `check.sh`.
- Before each release of a private repo, run a security review pass; public
  repos get CodeQL for free.
- Secrets live outside repos (env files on the target machines, the macOS
  keychain locally). `.env.example` documents shape, never values.

## Credentials and secrets

Hard rules on never committing secrets, encryption at rest, least privilege,
and per-person identity. Load [docs/CREDENTIALS.md](docs/CREDENTIALS.md)
before touching auth, tokens, OAuth, API keys, or session cookies.

## Issues

- Bugs and ideas noticed mid-task get filed as GitHub Issues in that repo,
  even when not being fixed now. GitHub Issues are the tracker of record for
  getmaipai repos (they mirror to Gitea automatically). Jesse's Gitea remains
  the tracker for homelab matters. File through the maipai plugin's
  `issue` skill: it searches open issues first and comments on a match
  instead of filing a duplicate.
- **Write issue bodies like a person describing the problem, not a bot filling
  out a template.** A bug report says what happened and what you expected to
  happen instead, in plain words a non-engineer could follow. A feature
  request says what someone wants and why it'd help, not a spec. The title
  and opening line should make sense to Jesse on his phone with zero context
  loaded. Technical detail (stack traces, logs, exact repro steps, file/line
  pointers) is welcome, but goes underneath the plain-language summary, not
  instead of it. The same AI writing standards as everywhere else apply here
  too (see Writing style above): no em dashes, no filler vocabulary, no
  robotic "as an AI" phrasing, no listing symptoms without ever saying what's
  actually wrong in a sentence a person would say out loud.
- **This is enforced structurally, not by memory.** `.github/ISSUE_TEMPLATE/`
  in this repo (`bug_report.yml`, `feature_request.yml`) is GitHub's
  org-wide default: any repo in the org without its own issue templates
  (every repo, currently) serves these automatically, so the plain-language
  prompts show up for human contributors and AI sessions alike, on GitHub's
  side, with no per-repo copy to keep in sync. A repo only needs its own
  templates if it genuinely needs different fields; if so, keep the same
  plain-language framing.

## Backlog and status

Issues track bugs and one-off requests; **`docs/BACKLOG.md` tracks build
status** - what's built and what's missing, per area, in every repo. One
definition, no second parallel system (no GitHub Project, no custom fields):
a visual status dashboard reads this file directly, so it has to stay real.

- **Every repo keeps a `docs/BACKLOG.md`**, in the shape `home`'s already
  uses: scannable, not narrative (the reasoning and decision history live in
  `docs/dev.md`, linked where useful); size-tagged **S** (a session or
  less), **M** (a real slice, days), **L** (a platform-level capability,
  needs its own design pass first); organized under `## Area` headings that
  reflect how that repo actually breaks down (a package category, a
  subsystem, a chapter of the platform plan); `- [ ]`/`- [x]` per item.
- **Update it in the same commit as the change that closes or opens a
  gap.** A BACKLOG.md that drifts from what `main` actually does is worse
  than not having one, because the dashboard trusts it.
- **Item template**, so a `- [ ]` is pickup-ready for any AI agent, not just
  a session that already has this conversation's context: a one-line
  objective, file/dir pointers, an existing file or pattern to mirror,
  acceptance criteria, what's explicitly out of scope, and the exact exit
  check (`scripts/check.sh` or a named test). Anything bigger than one item
  gets a short design note in `docs/dev.md` first, then gets chunked into
  BACKLOG items - never a new spec-file system invented per feature.
- **The dashboard is a derived view, never a second source.** The
  `status-dashboard` skill (`getmaipai/.github`) parses every repo's
  BACKLOG.md into a colored, phase-grouped status page; run it whenever a
  BACKLOG.md changes, at latest before the session ends. This is an
  instruction, not a hook: judging whether status actually changed needs
  contextual reading, the same reason code-review-before-commit stays a
  soft gate instead of a script.

## Compatibility

- The hub API serves multiple clients (Go, Desktop, firmware pods) that
  update on different schedules. **API changes are additive**: never remove
  or repurpose a field or endpoint the clients rely on without a versioned
  path and a migration note in the changelog.

## Privacy architecture

"Nothing leaves your house" is the product, kept structurally: zero
phone-home, no MaiPai-operated service in a user data path, a user-tier
privacy page per product. Load [docs/PRIVACY.md](docs/PRIVACY.md) before
adding or changing an outbound connection.

## Trademarks and platform references

Standing editorial rules for any mention of a third-party platform (YouTube,
TikTok, Plex, Spotify, Reddit, and the rest): names only and descriptively,
no borrowed trade dress, no filter-bypass framing. Load
[docs/TRADEMARKS.md](docs/TRADEMARKS.md) before writing copy, UI, or code
that mentions or styles one.

## Safety invariants (generation features)

Child-safety protections on generation and chat are non-removable
architecture, not a setting; child profiles are restricted by default; adult
freedom comes with a disclaimer, a one-time acknowledgment, and crisis
resources offered, never blocking. Load [docs/SAFETY.md](docs/SAFETY.md)
before touching generation, chat, child profiles, or the adult-unlock flow.

## Licensing

Every repo carries AGPL-3.0 from its first commit; copyright stays 100% with
Jesse. Load [docs/LICENSING.md](docs/LICENSING.md) at repo setup, release
time, or before adding a dependency whose license is in doubt.

## Third-party services: we are the user

Toward YouTube, Reddit, TikTok, Plex, and every other service MaiPai talks
to, it behaves as the user would, only automated: a person's pace, the
front door over scraping, back off on the first signal. Load
[docs/THIRD-PARTY-SERVICES.md](docs/THIRD-PARTY-SERVICES.md) before writing
or changing code that fetches from an external service.

## Third-party code and assets (download, don't vendor)

Our repos contain our work. Other people's work arrives through a manager or
a download, never by copying it into the tree.

- **Code dependencies** come via the package manager (bun, uv, Swift PM) with
  a lockfile. Never copy a library's source into the repo.
- **Third-party models, binaries, and datasets** (wakeword base models,
  transcoders, reference data) are fetched by the app on demand: pinned
  version, pinned URL, checksum verified, with a clear failure message when
  offline. The hub's self-healing download system is the pattern.
- **Only artifacts we created may be tracked**: the MaiPai-trained wakeword
  model yes, upstream base models no. Even our own large artifacts ship as
  release assets rather than tracked files (see Releases).
- **Exceptions are allowed but expensive on purpose:** a copied snippet or
  file requires AGPL-compatible licensing, a NOTICE entry, a source comment
  saying where it came from, and a justification in the repo's dev docs. If
  that feels like too much ceremony for the snippet, that's the point:
  download it, depend on it, or reimplement it.

Why this is a hard rule: it keeps the copyright story clean (sole ownership,
dual-licensing stays possible), keeps repos small, and means upstream fixes
arrive by bumping a version instead of hand-merging vendored copies.

## Rules, word lists and learned components (2026-09-16)

A deterministic rule needs a counter and a row, or it's retired; three
phrasings in a week is a classifier candidate, not a fourth regex; a
learned component never sits in the safety, consent, or privacy path. Load
[docs/RULES-AND-LEARNED-COMPONENTS.md](docs/RULES-AND-LEARNED-COMPONENTS.md)
before adding or editing a rule, word list, or classifier in a chat or turn
pipeline.

## Training models (wake words, and anything like them)

Verify training data actually landed, validate on real speech through a
real microphone, train against near misses, never let unverified audio
become training data. Load
[docs/TRAINING-MODELS.md](docs/TRAINING-MODELS.md) before training or
retraining any model.

## READMEs

Every repo follows the README skeleton in [docs/STYLE.md](docs/STYLE.md):
logo + one-line promise, user-voice pitch, generated screenshot strip, Get
started link, the three doc links (User / Developer / API), license line.
READMEs are user-tier writing: the dad test applies, and the AI writing
standards above apply everywhere.

## Stack

See [STACK.md](STACK.md). New work uses the standard stack; a deviation needs
a written justification in that repo's dev docs.

## Platform standards (`home`, `bot`, `catalog`, `go`)

Beyond the rules above, the platform rebuild carries its own standards docs,
all pinned by the [`@maipai/standards`](standards/) tooling core
(std-v0.2.0):

- [docs/PACKAGES.md](docs/PACKAGES.md): package definition of done, supply
  chain, review, the CLA.
- [docs/UI.md](docs/UI.md): the shell contract, the kit, patterns,
  responsive rules, PWA, tabs, icons.
- [docs/SETTINGS.md](docs/SETTINGS.md): the settings standard (one
  definition, the generic renderer, three disclosure levels).
- [docs/ENGINEERING.md](docs/ENGINEERING.md): tokens, accessibility, copy,
  i18n, logging, tracing, errors, performance budgets, privacy, security,
  kid-safe, licensing, versioning, naming, every standard a package
  inherits.
- [docs/STYLE.md](docs/STYLE.md): documentation and screenshot standards
  (extended for the platform's screenshot pipeline and build-doc format).
- [docs/UPDATES.md](docs/UPDATES.md): updates, notifications of updates, and
  install.
- [docs/BACKUPS.md](docs/BACKUPS.md): backups, integrated and scheduled.
- [docs/NOTIFICATIONS.md](docs/NOTIFICATIONS.md): the notification system.
- [docs/SERVICES.md](docs/SERVICES.md): how a daemon runs on a person's
  machine (the three pieces, service managers per OS, the watchdog
  layers, one health list, logs, install and uninstall).

A repo's own `CLAUDE.md` may add specifics; it never restates or weakens a
platform standard. `@maipai/standards` `check.sh` core is what actually
enforces the enforceable half (see [standards/README.md](standards/README.md)).
