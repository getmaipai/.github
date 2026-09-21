# Org decision record

Dated entries for decisions that changed an org-wide rule, with the
incident or review that prompted each. The rule itself lives in
[CLAUDE.md](../CLAUDE.md) or the named standard; this file keeps the
why, so the rule can be revisited on the facts rather than re-argued
from memory. Newest first.

## 2026-09-20: the `shared` repo (`ui`, `core`, `spec`)

**Decision.** The libraries every product imports live in one new
repo, `getmaipai/shared`, as three workspaces tagged on their own:
`ui` (`@maipai/ui`, `ui-vX.Y.Z`: the kit, tokens, icons, the shell,
the settings and permission renderers, the kit's ESLint config),
`core` (`@maipai/core`, `core-vX.Y.Z`: log, withTimeout, paths,
archive, hlc, id, secrets and the keystore, secretThrottle,
rateLimiter, singleflight, ssrfGuard, diagnostics, the openapi helper,
the hardware probe, backup crypto) and `spec` (`@maipai/spec`,
`spec-vX.Y.Z`: everything now in `home/spec`, the Python package
included). Dependency direction, never reversed: `shared` is imported
by `stack`, `home` and `catalog`; `bot` gets `ui`, `core` and `spec`
through Home's pinned runtime package and pins `spec` directly for its
Python body at the same version; `go` pins `spec`. Nothing in `shared`
imports a product. `@maipai/standards` stays in `.github` (org
tooling, not product code). The org rule "shared record changes go
through the spec first" now means a commit in `shared/spec` before the
hub commit.

**Why one repo and not three.** The three packages move together: a
kit primitive renders a spec shape, a core helper logs a spec error,
and a change in one is verified against the other two in one gate.
Three repos would mean three tag ceremonies for one change and a
sibling-checkout matrix in every consumer's `check.sh`; one repo with
per-workspace tags keeps one gate and three version numbers, which is
what consumers actually pin.

**Why Catalog stays separate.** It is the one community-PR surface,
with its own cadence and its own trust gate (the CLA, the scorecard,
the signing). It becomes a consumer of `spec` and deletes its schema
mirror, whose `manifest.schema.json` had already drifted from
`home/spec`.

**Why now.** The refocus below made the Stack a second consumer of the
kit and of eight `lib` helpers that had already diverged between
`home/backend/src/lib` and `stack/backend/src/lib` (`log.ts` and
`withTimeout.ts` differed on 2026-09-20). Principle 1 forbids the copy;
the Stack's reconciled kit and shell (owner-approved 2026-09-19) is the
version that moves, and Home adopts it.

## 2026-09-20: the Stack is Home's engine foundation, not a product

**Decision.** Supersedes the 2026-09-17 entry below. MaiPai Stack is
the engine foundation of MaiPai Home: the headless daemon that
installs, sizes, runs, watches, updates and tests the engines and
models Home uses, and gives Home (and Bot, which runs the same
platform code) one stable address by role. It has no user interface,
no users, no operator login, no client keys, no LAN exposure, no
public release, no standalone installer, no docs site and no pitch of
its own; Home is its only caller, Home's installer installs it, and it
updates with Home's releases. The name stays: "Stack" is the name of
Home's engine layer the way "turn engine" is the name of Home's
conversation layer. The repo stays, as a service with its own process
and port, because a separate process survives a Home crash and is
shared by Bot on the same box. Every human-facing fundamental
(notifications, the updates page, repairs, settings rendering, the
privacy page, backups, logs viewing, identity) is Home's; the Stack
declares its facts as data and Home renders them. The full ownership
table is in `stack/docs/plans/refocus-work-order-2026-09-20.md` and
`stack/AGENTS.md`. Of the three-piece shipping shape decided on the
evening of 2026-09-17, the Stack keeps only the first piece (one
binary under the OS service manager, exit codes that mean what they
say); the web UI and the status app are Home's.

**Why.** The necessity review
(`stack/docs/plans/stack-necessity-review-2026-09-20.md`) checked the
field on 2026-09-20: Msty Nexus, Lemonade and LocalAI each ship
"several engines, one service, one API, a model manager" on a Mac
today, two of them open source, and Msty Nexus announced the Stack's
exact pitch three months before the Stack's first commit. The one
thing none of them ships, one measured residency budget across the
processes a family hub launches, is a feature Home needs, not a
product strangers would install. After four days and 247 commits,
roughly a third of the backlog by line count was console surface
(showroom, panels, palette, library, Try-it studio, tray, channels):
a second admin UI, a second docs site, a second notification center
and a second update feed, each a copy principle 1 forbids inside one
product and which the repo split had made permissible by naming them
a different product. The continuing cost (qualifying upstream
nightlies per OS and GPU, Apple signing and notarization, a rollback
proof per release, support for people who are not the household) is
release engineering for a public runtime with zero users, on top of
Home, which has a family waiting and which principle 7 puts first.
The 2026-09-17 reasons for a repo (a different cadence, a different
audience) fall with the audience; the cadence argument and the
robot's need for the same layer are met by a private daemon inside
Home's release.

## 2026-09-20: reviews, repo descriptions and session context are budgeted

Three rules from the owner in one afternoon, each after a measured
waste. A code review invocation fans out several subagents at roughly
100k tokens each; one session ran eight full passes on a single item,
several with subagents stuck searching for a tool, so reviews now run
at the level the item needs (low for an S item, medium for M or a
route, guard or wire change), one pass per commit, a re-review of the
fix hunks only, never a third pass, and a review stuck searching is
stopped and rerun once with its target. The GitHub description field
had been carrying the README's full one-liner, which GitHub truncates
in lists, so a repo description is now one sentence under 120
characters kept in `brand/COPY.md` beside the longer pitch. And a
Claude session's context is budgeted like tokens: every done report
states the percentage used, and a session past 60 percent is handed
off at its next stop point instead of run to exhaustion, because
every later turn re-reads the whole window; the two token-free lanes
are cleared between briefs by the autofeed, and a Claude session
cannot clear itself, so the handoff is the mechanism. The rules live
in `CLAUDE.md` (Git workflow, the products) and the `coordinate`
skill; this entry is the why.

## 2026-09-20: the music role's candidate is ACE-Step 1.5; Jev is a no until it ships weights

The owner asked whether two projects should be used. Jev (TypeSafe
AI's "System One" model, released 2026-09-18) makes fast, calibrated,
typed decisions rather than text, which is exactly the classifier the
org's rules want in place of a fourth regex or a small-model judge;
but it is served only from TypeSafe's metered API with no published
weights, and a hosted-only model cannot sit anywhere in a product
whose promise is that nothing leaves the house. Verdict: no, revisited
only if weights ship or an open reproduction publishes a calibration
study against human labels. For the Stack's `music` role, YuE2 is the
more capable model on paper but is a Linux and NVIDIA product with
CC BY-NC weights and no Apple silicon path outside low-provenance
forks; ACE-Step 1.5 (MIT code and weights, an official MLX backend, a
REST server, an ungated download, full songs with vocals) fits every
Stack constraint and is the candidate, pinned only after a measured
run on the Studio (stack STACK-99). The research with its citations
is `stack/docs/plans/jev-and-yue-2026-09-20.md`.

## 2026-09-17 (evening): the shipping shape, no Docker, the tray on Tauri, the services standard

**Decision.** Every MaiPai daemon ships as three pieces: one compiled
binary under the OS service manager, a web UI on localhost, and a thin
native status app that is the only poster of native notifications and
an independent observer of the daemon. No Docker (no Metal in a Mac
container; a second install to explain). The status app is Tauri 2, a
written deviation from STACK.md's Electron for Desktop (no UI of its
own, sits in the menu bar all day beside large models). Install is one
command hosted by us, downloading only our own binary; the board is
the first screen, no wizard; the operator password is deferred until a
client key or LAN access needs it. The new [docs/SERVICES.md](SERVICES.md)
holds the per-OS table, the watchdog layers, the one health list and
the install rules; NOTIFICATIONS.md gains the `operator` audience and
names Telegram and ntfy as the off-LAN channels.

**Why.** The survey in `stack/docs/plans/operations-design-2026-09-17.md`:
Ollama, LM Studio, oMLX, mlx-serve, Tailscale and Syncthing all ship
this shape; a bare daemon cannot post macOS notifications; launchd and
systemd already provide the outer watchdog when the daemon's exit codes
mean what they say; five-step wizards and up-front multi-gigabyte
downloads are where people abandon local-AI apps (LM Studio's tracker),
while Ollama's thirty-second install and Jan's "chatting in seconds"
are what people keep.

## 2026-09-17: the Stack, the hub's engine layer as its own product

**Decision.** The engine layer (engine catalog, downloads and checksums,
the supervisors, the resource governor, model identity, engine updates)
becomes MaiPai Stack, its own repo and product (`getmaipai/stack`), with
Home and Bot as its first two clients. It ships on the Mac first, Linux
with the robot, Windows for the CUDA catalogue. Design first, no
migration: nothing moves out of `home` until the Stack has proven the
hub's residency profile on the Mac Studio beside the running hub
(STACK-14, then STACK-16).

**The line.** The Stack knows clients, not people: one operator login,
per-client API keys scoped to roles, no Person, no household, no memory,
no history, no packages. Its test surfaces are stateless. The moment a
second person in the house wants a turn, that is Home's job, and the
Stack's own page says so ("Share with your family"). The case that fixed
it: Oliver installs the Stack and tests everything as himself; he wants
Sprout to try it without pictures or video. Sprout is a child profile in
Home, restricted by default; the Stack never learns the name. A users
table in the Stack would put a child in two places with two permission
models and two safety paths the day Home installs, which is the drift
the no-data-debt and one-definition rules forbid.

**Why a repo (principle 5).** A different cadence (engine bumps and
model revisions land weekly regardless of hub features), a different
audience (a person who wants local AI on a Mac done right, with no
family hub), and a second consumer in the robot, which needs the same
supervised, provenance-checked, memory-governed engine set on its own
hardware. That last point is principle 1: one implementation, not one
per product.

**Why not adopt an existing host.** Surveyed the same day: LocalAI,
Harbor, mlx-serve, oMLX, Ollama, LM Studio and ComfyUI. None covers the
role table with the operating promises (sizing, one budget, updates with
rollback, notifications, a try-it per role) on Apple silicon, and the
MaiPai-specific parts (provenance before selection, the governor's
admission decision, the operator-only safety posture, the Home hand-off)
are what a generic host would never own. They become engines under the
Stack; `mlx-serve` and `oMLX` join `llama-server` and `mlx-lm` on the
Studio bench. The survey and what each taught is in
`stack/docs/dev.md`.

**Name.** "Core" was rejected: it names nothing specific and collides
with `check-core.sh`, "the standards core" and "core components".
"Engine" collides with `engineCatalog` and principle 6's "the mandated
engine". "Stack" is the word the owner reaches for, honest about what
the thing is, and fits the family of plain nouns (Home, Bot, Go,
Catalog). "Station" was the runner-up. Final confirmation is the
owner's; the rename costs nothing before the remote exists.

**What changed in the standards.** The products table and build order
in CLAUDE.md; STACK.md's "Models and the engine" names the Stack as the
owner, keeps llama-server as the baseline everywhere and the only engine
on the robot, admits the MLX candidates on Apple silicon as measured
alternatives, and extends the role list (`judge`, `rerank`, `music`, the
`quality` tiers). The pitch line is in brand/COPY.md.

**Bot.** Bot builds on the Stack and never requires Home: the robot runs
its own Linux Stack for the three language roles, the body keeps speech
over `spec/voice/` as a managed engine, and GOV-01's one governor is the
Stack's, fed by the body's power and thermal budget. The robot design
pass confirms or amends this in `bot/docs/dev.md`.

## 2026-09-16: rules, word lists and learned components

**Decision.** Six standing rules in CLAUDE.md ("Rules, word lists and
learned components"): no rule without a counter and a corpus row; three
phrasings in a week make a classifier candidate, never a fourth regex;
classifier labels come from people or a frontier model, never a small
local model; nothing learned sits in the safety, consent or privacy
path; a model judge is a trend line, never a gate; tone is the plan
line, the example lines and a steering vector, not prose.

**Why.** The owner asked whether the chat pipeline's regexes, word
banks and if-then rules were a non-intelligent, hard-to-maintain
approach. A frontier design review with 159 references (the plan
file named above) found the shape right (every fast, private assistant
puts decisions in code; an 8B model is measurably bad at the decisions
it would be handed) and the word lists the wrong ceiling: one evening
had added about ten regex families and nothing reported which rules
fired; ACT-02's classifier heads had failed on 4B-labeled data, not on
the idea. The rules keep the floor deterministic and make the ceiling
learnable.

## 2026-09-15: two token-free lanes, the local model and Codex over tmux

**Decision.** Small isolated items (S, or a small M whose brief names
every file, rule, test and command) go to one of two lanes that spend
no Claude tokens: the household's local coding model (a 27B dense
model, run through one OpenCode session the coordinator posts into
and clears through the server API) and Codex (in Jesse's visible
window, inside a tmux session the coordinator types into and reads
back). Claude sessions keep the work that needs judgment. The
procedure is the `coordinate` skill's section 1b; what the local
model is and is not good for is `docs/local-coding-model.md`.

**Why.** Two facts changed since the 2026-09-13 retirement. The model
changed: measured side by side with Sonnet on the same briefs, the
27B produced the same code on a small item (2.4x the time) and on a
medium one (1.9x the time), where the earlier small mixture model had
not; a 48K window and a 100-step cap were the limits, not the model.
And the budget changed: with the Claude subscription at three
quarters of its week by Tuesday, every S item typed by a Claude
session was a token cost the plan could not carry. The three
retirement failure modes have fixes in the lane rules: a fresh
worktree per item (its own diff is the only diff), the OpenCode
server and session pointed at a scratch folder (a relative path
cannot reach shared code), and git denied except commit (no merge, no
push). Codex joined when its quota returned; its own failure modes
(a commit over a red check, an expectation edited to match the code)
are named in the brief and read for.

**What it costs.** The coordinator reads every result: the diff,
the checks rerun, the commit message compared. On a precise brief
that is two minutes; a vague brief costs a whole run and a fix-up
round, which is why the brief shape in the skill is not optional.

## 2026-09-13 (evening): the local coder is retired

**What happened.** The afternoon's decision to send small isolated
items to OpenCode on the household's Qwen3-Coder-30B-A3B (IQ4_XS, on
the laptop's eGPU) was tested on seven tasks of rising difficulty,
with a capability log kept for a tuner session that fixed the server
side as findings came in (dead starts traced to the laptop's NIC
shaping, one slot owning the full context, the question tool off at
the source, `git restore`/`stash`/`reset` denied, llama.cpp bumped,
an eGPU-only layout, and a dense Qwen3-8B tried and rejected on
judgment). Result: three commits landed (a wizard step in a doc, a
`--docs` flag on the gate, the TypeScript half of #72, which needed a
second pass); four tasks produced nothing usable. It took about 1 h
45 min of coder time and about 2 h of coordinator time, against
about 15 min for a Sonnet session doing the same three commits; one
broken test reached `main` past a gate, one session's staged index
was unstaged, and the shared checkout was polluted once. The model
executes a one-file change with a precise spec correctly and fails
on anything with a second concern (a setup step, a directory rule, a
subtle rule among plain ones, recovery), and its own reports cannot
be trusted, so every result had to be read line by line.

**Decisions.**

1. The local coder path is retired. Nothing is sent to OpenCode; the
   `localcode` wrapper and the tuner's write-up stay in the homelab
   repo as a record, and the capability log stays in
   `home/data-scratch/`.
2. Small isolated items go to the Claude session that owns the area
   or to a Haiku session under the model floor table. Never a pasted
   prompt.
3. Codex stays as the outside reviewer only.
4. The lesson about what to measure holds: a coder is judged by the
   coordinator time it saves, not by its token price. A free model
   that needs its diff read is more expensive than a paid one that
   does not.

**Commits.** `getmaipai/.github`: this one.

## 2026-09-13 (afternoon): small isolated items go to the local coder, sent into the live window

**What happened.** Small, isolated items (a test fixture, a normalizer,
a doc page) were being handed to Jesse as prompts to paste into Codex
or OpenCode by hand, and he had to relay the reports back. He rejected
that, rejected a Claude subagent as the substitute (the local model is
the point: private, his hardware), and asked to keep watching the live
window. His `localcode` alias runs OpenCode against the household's
Qwen3-Coder-30B and serves an HTTP API; the coordinator can put a task
into the window's own input and read the transcript back. Two
lessons from the first attempts: a prompt sent by session id after he
restarted the alias ran headless where he could not see it, and a
Qwen session left to pick its own backlog item ran the full test
suite in the shared checkout beside two editing sessions.

**Decisions.**

1. Small isolated items go to the local coder through the live
   window's API; the coordinator sends, reads, and verifies by
   artifact. No pasted prompts, no relayed reports (CLAUDE.md Roles;
   the `coordinate` skill, section 1b).
2. Qwen3-Coder-30B is Sonnet-class for S items with no shared files
   and a mechanical gate; never the chat engine, memory, safety, or
   the supervisors.
3. A local-coder prompt names its files, forbids the full suite when
   the shared checkout is dirty, and fixes the report shape; a local
   coder never chooses its own item.
4. Codex stays as the outside reviewer (a second model's reading of a
   design or a block), launched the same way.

**Commits.** `getmaipai/.github` 565f2ca, 8868fb2, and this one.

## 2026-09-13: acceptance verifies the claim, not the work order

**What happened.** After a night of coordinated work on `home` (the
2026-09-12 chat block, ROUTE-01/02, CHAT-18/01/02, and Session B's
frontend lanes), an outside review by Codex read the whole diff
against its acceptance claims and found five defects in accepted
commits: the "one output safety boundary" skipped package error
fallbacks on two outlets (#86); the credential filter redacted history
rows but not existing summaries, and matched only a key's header line
(#89); the edit-branch exclusion covered the conversation window but
not episode recall or the memory judge (#88); the judge bench printed
"precision" and "recall" that were both a two-case pass rate (#87);
the Firefox service-worker passthrough gated one listener while the
precache library registered another (#90). Two of the coordinator's
own work orders rested on premises a grep would have refuted (a "spec
first" item for a record that is deliberately hub-internal; a
reconnection item that assumed a finished reply exists after a
disconnect that aborts generation). Every faulted item had passed its
own tests and met its written acceptance.

**Decisions.**

1. A universal claim ("every", "one boundary", "never enters") is
   accepted only with an enumeration of every producer or consumer it
   covers and a test per path, failure paths included. The acceptor
   reads the enumeration against the code (CLAUDE.md Verification;
   the `coordinate` skill, section 4).
2. A metric's name is checked against its computation before a number
   is accepted under that name.
3. A claim about a library's behavior is verified in the installed
   source, cited by line.
4. A work order states no premise about the code the coordinator has
   not read (skill, section 2).
5. An accepted exception opens its follow-up item in the same commit,
   and a `BACKLOG.md` tick states which of three things it means:
   verified at a commit, accepted exception with the ruling and the
   follow-up named, or verification outstanding.
6. A block ends with an independent review by a session that neither
   wrote nor accepted the work, triaged before the next block. The
   coordinator's acceptance is never the last review.
7. A waiting session goes idle and is woken by one message; it never
   polls, re-checks, or reports that nothing changed.

**Commits.** `getmaipai/.github` 5dea0f1, 32e78ac, and this one.

## 2026-09-12: the coordinator role, its skill, and the rules it changed

**What happened.** A Fable session reviewing `home`'s chat program
finished both concurrent Haiku tracks itself (benches, engine spawns,
fixes, gates) after the coder sessions stalled: a day of the most
expensive model on work whose value is the same whoever types it. That
evening the same session was set to manage two coder sessions instead.
Both sessions were labeled "sonnet" in the agent list and both were
Haiku; one ran out of context mid-item twice, the other closed an issue
on one of six defects fixed and "verified on all surfaces" with no
screenshot opened. A misdirected code review then read another
session's uncommitted diff because the review's forked subagent landed
in the main checkout instead of the worktree. Codex reviewed the first
cut of the resulting rules and found contradictions with the org
standard.

**Decisions.**

1. Two roles, coordinator and coder (CLAUDE.md "Roles"). Fable always
   coordinates and never codes, tests, benches, builds, or runs
   servers; Sonnet or Opus may coordinate when Jesse says so. The
   procedure is the maipai plugin skill `coordinate`.
2. Coordination is event-driven: ready, done, blocked, question, low
   context; a session starts only on the coordinator's start message
   after its ready report; idle-notice subscriptions replace polling.
3. One model-floor table, in CLAUDE.md. Haiku only for an S item with
   one clear change and a mechanical check; Sonnet for any M item,
   any verification loop, or anything that closes an issue; Opus for a
   classified reasoning failure, a live measurement plus judgment, or
   work spanning subsystems. The agent list's label and a co-author
   line are hints; the session's own report is the check.
4. Blockers are classified (environment, unclear requirement, context
   exhaustion, reasoning failure) and only a reasoning failure buys a
   stronger model; the strongest permitted model stalling means the
   item is re-scoped.
5. Evidence matches the item's acceptance (regression test, exercised
   flow plus opened screenshot, or measured numbers with a sanitized
   hardware description). Live numbers are required when the item
   names them, not for every item. The review hook proves only that a
   review was invoked; the completion report proves what was run and
   what was done with findings.
6. Each parallel block names one integrator that merges serially,
   reconciles shared docs into one text, verifies the combined `main`,
   and removes temporary branches and worktrees.
7. Coder sessions launch with `claude --dangerously-skip-permissions`;
   the isolation in the work order (worktree, ports, data directory,
   owned files) is what makes that safe.
8. Pushes need no approval: a verified item merged to `main` is a
   natural boundary, and a failed push is reported as blocked.
9. Doc-only commits need the standards core, not the full `check.sh`
   (stated under Verification).
10. A code review run from a worktree passes an explicit target and
    checks the reported path and branch before any finding is acted
    on; a mismatched review is discarded and its findings routed to
    the owner.
11. The handoff note for a lane is one canonical file whose path is
    shared; memory and messages point at it rather than copying it.

**Rejected or adjusted from the review.** "One M item per session"
became "a slice small enough to implement and verify with context to
spare", chunked before assignment. "Never re-read the work order"
became "re-read the acceptance list once before reporting done". A
bounded recovery check after a missed acknowledgment is allowed;
progress polling is not.

**Commits.** `getmaipai/.github` 36617a5, 7eb174a, b364172, 3906f14.

## 2026-09-20: Home follows the kit's design specification exactly, page by page

After the kit adoption the owner opened Home beside the approved
reference (`shared/ui/docs/reference/overview-dashboard.png`) and
found the shell bones and tokens present but the pages still
composed as before: no icon tiles, no panel headers, no page title
and subtitle in the header, no footer bar, an uppercase eyebrow and
an oversized greeting. His ruling: Home follows the specification's
look and feel exactly (colors, shading, icon tiles, sizing, layout,
weights, cards, the header, the footer, the pane headers), while its
own navigation, routes, records and actions fill those patterns; the
reference's menu items and pane contents were the Stack console's
and are not copied. The mapping of every Home route onto the
patterns, with a non-negotiable style block, is the "Home's pages
under the kit" section (`home/docs/design/home-pages-2026-09-20.md`,
appended to the kit spec); each page is one item, judged by a capture
placed beside the reference, and a page that reads as the old Home
page with new colors fails.

## 2026-09-20: budget mode until the plan resets

At the day's rate the Claude plan would run out by Wednesday, so the
owner set the routing for the rest of the week: the two token-free
lanes take M items and code, not only S docs (the local model had
landed the permission diff, the governor's queue drain and the
admission rewrite cleanly that day), Codex at low reasoning takes any
item whose brief names every file, rule, test and command, the Claude
sessions that implement run on Sonnet (Session A was restarted
on Sonnet from a handoff note after finishing its last Opus item),
Haiku takes verification reads and any S item the lanes cannot, and
only the coordinator stays on Opus. The Home side of the Stack
(client, event bridge, Engines API) went to the lanes in that order;
the judgment items (rewiring the turn engine, the Engines page's
design fit, the spec move) stayed with the Claude sessions.

## 2026-09-20: the libraries repo is public and named `commons`

The Catalog is public and its contributors and CI must read
`@maipai/spec` and the kit, so the libraries repo could not stay
private. Its history was scanned (gitleaks and the PII wordlist) and
came back clean before the switch. The owner also disliked `shared`
as a name, which reads as an adjective in every sentence, and chose
`commons`: the org's common libraries, `ui`, `core` and `spec`,
tagged on their own. The GitHub repo is `getmaipai/commons` (the old
address redirects); the package names `@maipai/ui`, `@maipai/core`
and `@maipai/spec` did not change, and the local folder, worktree
and environment-variable renames land as COMMONS-RENAME-01.

## 2026-09-20: the standards pin resolves through a per-tag worktree

Session B, closing SHARED-PIN-01, found the same mutable-checkout bug
under `@maipai/standards`: every repo's gate names `std-v0.2.0` but
runs the sibling `.github` checkout at whatever it has, which was
eight files past the tag, and one of those files is the prose lint
that then failed the catalog's CI on a rule the tag never carried.
The owner chose the mechanism over a fresh cut: `standards/bin/ensure-tag.sh`
resolves a tag to a read-only worktree under `../.github-tags/`, the
way commons's script does for `ui`, `core` and `spec`, and every
consumer's `check.sh` compares the worktree's `VERSION` to its pin.
One mechanism for every pin in the org; a tag cut is a release, not a
repair.

## 2026-09-20: std-v0.3.0 is cut because the drift was the fixes

Pinning the gates to std-v0.2.0 through the new worktree mechanism
failed on the bot's CLAUDE.md, which the tagged prose lint misread
(an HTML comment; the fix landed after the tag). The eight files of
drift were fixes a consumer wants, not rules it never agreed to, so the
tag moves up to them: std-v0.3.0 is cut from main and every
repo's `STD_TAG` bumps to it in its own commit. The mechanism stays;
this is the release it expects.

## 2026-09-20: Codex at low reasoning takes S items only

The standing lane check (a lane producing more fix-up rounds than clean lands reverts to Claude-floor routing for that class) fired the same afternoon budget mode sent M items to the lanes. Two M items in a row from Codex at low reasoning came back as fix-up rounds: the catalog model index with its schema stubbed to `{type:"object"}` and its code squashed to one-line statements, and Home's Engines API with every handler and schema typed `any`, three placeholder tests, and a commit made over a gate that never ran green. The local model landed its M items cleanly in the same hours (the Stack client, the settings page, the governor chain). So Codex at low takes S mechanical items only: a docs change, a rename, a pin bump, a rebase, a one-file fix-up whose brief names the exact lines; M items go to the local model or a Claude session at the floor. The owner can raise Codex to high for a design item, and the brief says so in its first line.

## 2026-09-21: no hand-built UI; the chat moves onto assistant-ui Elements as shipped

The owner looked at Home's chat, rebuilt by hand on assistant-ui's
runtime over the past week, and called it ugly and buggy; the library
it sits on ships Elements, a catalog of 144 interface pieces for every
state an assistant can be in (reasoning, messages, tool use,
knowledge, structured output, agents, observability, the composer,
voice, the thread, the runtime-connected surfaces, renderers,
primitives, generative UI), each used as source and wired to the same
runtime Home already runs. The rule from here, written into
CLAUDE.md's platform principle 6: no hand-built UI. Every surface is a
shipped component used exactly as it ships, styled only by the tokens
it reads, wrapped and composed by the kit, never edited or re-drawn.
The chat is the first program under the rule: the Elements installed
into the kit unmodified, Home's hand-built thread, composer, panes and
chips retired one by one behind a flag, the artifact experience
(artifact-card, canvas-split) wired to a new artifact record on the
turn engine, the old chat removed a release after the new one is
verified. The same rule retires hand-built pieces elsewhere as they
are touched.

## 2026-09-21: Home's shell and pages come from shadcndashboard, as shipped

Same evening, same reasoning extended from the chat to the whole
application: the owner chose `shadcndashboard` (WrapPixel's MIT
admin template on React 19, Vite, Tailwind v4 and shadcn/ui with
Base UI primitives, the same stack Home runs) as the one source of
Home's shell and pages, used exactly as it ships. Its sidebar and
header are the shell, its widgets, data tables, form layouts,
profile and settings pages are the pages, its auth pages are the
sign-in, and the tokens are the only thing Home changes about them.
The kit keeps the tokens, the two looks, the icons, and wraps the
vendored template and the assistant-ui Elements; its hand-built
shell, DetailPane, ThingsTable and blocks retire page by page. The
2026-09-20 design doc's numbers stay as the tokens' targets (spacing,
radii, the palette) but no longer describe components Home draws
itself. Known trades, accepted: the template is a clone, not a
registry, so upstream updates are manual merges of a vendored
snapshot; it uses shadcn's Base UI primitives while the kit's
vendored set was on Radix, so the kit moves to the template's
primitives rather than carrying two.

## 2026-09-21: one full-context coding lane is what the laptop's two cards hold

Three attempts to get a second free coding lane out of the llmhost's
3070 and 2070 all failed on measurement, not opinion. A ternary
27B (PrismML's Bonsai family) sat at 7.46 GiB on one card before
generating a token and looped the same planning block 39 times on the
fixture's task 6, and its second run, on the Bonsai 2 build of the
lane's own Qwen3.8 base, was not measured because a stale setup line in
the task prompt sent it hunting for a file that did not exist. Two
llama-server slots on the lane's own IQ3_XXS build at 65536 context
crashed with a CUDA out-of-memory on the first pair of concurrent
decodes, and two slots at 49152 would halve each slot to 24K, which
task 9 had already shown too small. So the lane stays one full-context
server at 49152 with one slot; a second lane needs more memory, not a
different flag. Two rules came out of the night:
every bench runbook names a per-task wall-clock cutoff (three times the
reference run's time) before it starts, and the lane is never aborted
mid-item for a test: its queue is held and the current item finishes
first, because the two aborts of 2026-09-20 cost the lane
its uncommitted rewrite of a four-hour item.
