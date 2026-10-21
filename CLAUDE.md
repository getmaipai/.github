# MaiPai org standards

Applies to every repo in the `getmaipai` org. A repo's own CLAUDE.md holds only project specifics.
If a repo file contradicts this one, the repo file wins for that repo; flag the conflict.
Detail lives in `docs/`; each section names the doc to load before you act on it.

## How to talk to Jesse (owner's rules, 2026-10-15)

- **Concise and plain, no walls of text.** Every reply that started, finished, decided or needs something ends with exactly one line:
  `STATE: <active | waiting [what] | blocked [owner: what] | done> · <what> · YOU: <command or fact he must act on> | nothing`
  `waiting` or `blocked` on Jesse means `YOU:` names what he must do or supply; `YOU: nothing` is only valid with `active` or `done` (2026-10-21: a
  session wrote `waiting [Jesse: the error text]` then `YOU: nothing`, so the summary said nothing was needed while the app showed it blocked).
  The token cost is accepted; a buried ask costs more. Plan state changes go through `plan-set` and the republished plan page.
- **Reply style (adapted from i-have-adhd, MIT):** open with the answer or the next action, no preamble, recap or sign-off. Number
  multi-step work as short single-action steps. Offer tangents as a separate question, never inline. Cap lists at five, best first.
  Give time estimates in concrete units. Say what now works and how to see it. Report errors as cause plus fix, no alarm, but name a
  cause only when the evidence shows it (otherwise say what is unknown and the one check that decides). The STATE line is the one
  closer; it replaces "end with a next step". Exceptions: "explain" or "walk me through" gets full length with headers, still no
  preamble; confirm before destructive actions; after three "still broken" turns stop editing, name the assumption that may be
  wrong and ask one diagnostic question. Before sending, cut an opening that announces the work, a closing recap, "by the way"
  asides, empty hedges and idioms; the first and last lines alone must say what to do and what happened.
- **Every question or decision for Jesse goes through the AskUserQuestion wizard:** 1 to 4 short questions, plain words, recommended
  option first and marked "(Recommended)", one line per option on what happens. Never prose, never in `YOU:`. Decide what is not his
  (file names, process, lane choice) without asking.
- **Do what he asks, in the form he asked** (a command, a session, a setting). Deviate only by asking first; acting first and
  explaining later is a defect. If he corrects you, undo it unasked.
- Commands you hand him: one short command per line, never `&&`-chained, fully qualified paths, and name the machine it runs on.
- Never frame anything around the hour or stopping for the night.

## The products

MaiPai's promise: private, local AI that is actually yours. Nothing leaves the home. Every decision honors that.

| Repo | Product |
|---|---|
| `stack` | MaiPai Stack: headless engine behind Home; Home is its only caller. |
| `commons` | Libraries `ui`, `core`, `spec`; tagged on their own; public; imports no product. |
| `home` | MaiPai Home: self-hosted family AI hub; the platform and the household's master. |
| `catalog` | Public signed package catalog; hub and robot install from it; pins `spec`. |
| `go` | Apple TV and iPhone client rendering the UI schema natively; built last. |
| `bot` | Robot companion; pairs with the hub, complete alone. |
| `.github` | Org standards, `@maipai/standards`, the shared Claude plugin. |

Pitch copy is verbatim from `brand/COPY.md`; logos from `brand/`, never redrawn; repo descriptions are one sentence, at most 120
characters. Pre-rebuild code exists only as local mirrors (`legacy-backups/*-legacy.git`): copy hard-won logic, never feature scope.
Load `docs/PLATFORM.md` before product framing, repo descriptions, the UI rule below, or a record change.

## Platform principles

1. Simplify: one definition, implementation and store; a second copy is wrong even when faster.
2. The robot is complete without a hub.
3. No data debt: every record is the shared spec shape with id, provenance and clock stamp from first boot.
4. One definition, one place for every key, record type, config and shape.
5. Repos only for a different release cadence, committer audience or visibility.
6. Prebuilt over hand-built: assistant-ui Elements for chat, shipped kit primitives and `shadcndashboard` pages for the rest, restyled by tokens only, never forked.
7. Hub first, robot for parity, Go last.
8. Every feature is reviewed and rebuilt, never carried; record a one-line verdict first.

Shared record changes go spec first (`commons/spec`), then hub, then robot. Design ambiguity is a research task: dispatch
`design-resolver` before asking Jesse. Find the best design on merit before checking it against a rule; a conflicting best design is
measured and reported with the rule named, never dropped (full text and the delegation: `docs/PLATFORM.md`).

## Working mode

- **Do the work end to end in your own worktree.** One session, one worktree on a short-lived branch, landed fast-forward onto `main`,
  then removed. Never edit another session's worktree, and never `git rebase`, `reset` or `checkout` in a checkout you do not own.
  Use `scripts/wt.sh` (start, run, wait, check, land, done, reap), never hand-run `git worktree` commands. If `scripts/wt.sh` is
  missing the checkout is stale: `git fetch`, fast-forward `main`, then `wt.sh start` / `wt.sh run`. Never run `codex exec` directly
  (a user-level hook and deny rule block it).
- **tmux sessions are disposable and owned.** Create one with a unique plain name (`<repo>-<worktree-name>-<purpose>`), touch only your
  own, tear it down when done.
- **No pull requests** (only `catalog` takes community PRs). Land directly on `main`; push at natural boundaries; deploys and releases
  need Jesse's word in the moment. Commit only completed, verified work, one logical change per commit, by file name, never
  `git add -A` or `.`. Author identity is the GitHub noreply address.
- **Parallel work, in this order (Jesse, 2026-10-19):** (1) Codex first for decided, verifiable work (GPT-6 Luna, low effort, high when needed); (2) the
  local lane second for small and medium decided tasks (one to about six files, a test that can fail) and whenever Codex is limited: OpenCode against the
  household's own coding model through `local-lane dispatch` (`~/.local/bin/local-lane`, setup in `data-scratch/reports/opencode-local-setup.md`; guardrails
  and receipts built in; Studio only; files the hub's safety floor refuses are skipped); (3) Claude subagents and this session for what needs judgment or
  design. Sonnet is the default, Opus gets one bounded question, Haiku gathers evidence, Fable only when Jesse says. Dispatching: use the `dispatch` skill
  (`scripts/wt.sh run codex` then `wait`, or `local-lane dispatch ... --detach` then `local-lane wait`); the dispatcher always reads the diff, runs the
  tests and the gate and commits by file name. `docs/COORDINATION.md` is history plus role policy.
- **Clean up on sight:** a merged or abandoned branch, finished worktree, dead file, leftover claim, lock or tmux session you own or
  can prove dead is removed this session; anything that may be another session's or Jesse's data is listed with evidence.
- Load `docs/GIT-WORKFLOW.md` when a hook denies a git command or before a review. Before reporting a force-push or missing history, run `git remote -v` and `git reflog show origin/main`: a wrong `origin` URL looks like a rewrite (`standards/bin/origin-guard.sh`).

## Checks before landing (definition of done)

| Change | Before landing |
|---|---|
| Docs only | `scripts/check.sh --docs` (secrets, PII, prose) |
| Ordinary code | `scripts/check.sh --pre` plus the tests beside the changed files; read your own diff once |
| Risky surface (auth, credentials, consent, child and teen gates, migrations, `RULES.md`, `check.sh`, `wt.sh`) | full `check.sh` under the machine lock, `code-review` at medium, architect verdict when the design changes |

Everything else, the turn pipeline, wire shapes, spec records and pins included, is ordinary code (GATE-FAST-01, 2026-10-16). Tests that need
the real network or wall-clock timing live in the bench lane (`check.sh --bench`, on demand), never in the gate. A gate stamp is good for 4 hours.

Secrets scan and PII wordlist run on every change. Rollout: until the hooks follow this table, the hooks' stricter checks apply.
"Verified" means exercised for real, not "it compiles". Never hand Jesse something you have not checked, and never ask him to run
what you can run. Every real failure becomes a regression test first. Evidence matches the claim: the flow exercised and the
screenshot opened, or measured numbers. Load `docs/VERIFICATION.md` before gating, benching, writing tests or claiming done.

## Architect gate

A repo with `docs/design/RULES.md` keeps its hard design rules there; that file is the authority. The `architect` agent rules
(APPROVED, REJECTED, DUPLICATE, NEEDS-RULE-CHANGE) on a new design note, plan, new backlog item on a governed path, or a `RULES.md`
edit; not on a status-row edit. Only Jesse changes a rule; such a commit carries `Owner-approved: <date>`. Load `docs/ARCHITECT.md`.

## Documentation and writing style

- Claude writes all documentation; docs change in the same commit as the behavior; no owner-specific notes in docs. Three tiers
  per `docs/STYLE.md`: `user/` (grade 6), `dev/`, `api/` (generated). Screenshots are generated by script against the seeded demo
  household and opened and judged before use. Load `docs/DOCUMENTATION.md` for user docs, READMEs, screenshots, build guides.
- **No em dashes (U+2014), ever.** No filler vocabulary (delve, seamless, robust, leverage, empower, streamline, game-changer) or "not just X, it's Y"; no rhetorical-question transitions or exclamation points in technical prose. <!-- prose-lint: allow -->
- Concrete beats abstract: numbers, names, paths. User-facing copy passes the dad test.
- **Every error message says what went wrong and what to do about it** (the problem in terms the person sees, then the next step). Detail: `docs/STYLE.md`.

## Privacy and PII (hard rules)

- **Never commit:** family member names, home address, phone numbers, personal email, credentials or tokens, real LAN IPs or homelab hostnames. Jesse's own name is the one exception.
- **Examples use** `192.0.2.x` IPs, `example.com`, and persona names only from this roster: alfred, astro, atlas, bramble, bruno, clover,
  cosmo, daisy, ember, indigo, iris, juniper, lucia, marlow, marsh, mopey, nadia, nova, oliver, pippa, quill, raven, riff, rivet, rover,
  sage, serena, sprout, tempo, velvet, vincent, willow.
- Homelab details live only in Jesse's private homelab repo. Scratch and private notes live in the git-ignored `data-scratch/`.
- `check.sh` enforces this (gitleaks plus the private `~/.config/maipai/pii-words.txt`). Screenshots and demo data never contain the real family.

## Load the doc before the trigger

- **Privacy architecture** (`docs/PRIVACY.md`): zero phone-home; load before adding an outbound connection.
- **Third-party services** (`docs/THIRD-PARTY-SERVICES.md`): behave as the user would; before code that fetches from one.
- **Credentials** (`docs/CREDENTIALS.md`): before auth, tokens, OAuth, API keys, cookies.
- **Safety** (`docs/SAFETY.md`): child protections are non-removable; before generation, chat, child profiles or adult unlock.
- **Rules and learned components** (`docs/RULES-AND-LEARNED-COMPONENTS.md`): before editing a rule, word list or classifier in a turn pipeline.
- **Trademarks** (`docs/TRADEMARKS.md`), **Licensing** (`docs/LICENSING.md`, AGPL-3.0), **Training models** (`docs/TRAINING-MODELS.md`).
- **Dependencies and releases** (`docs/RELEASES-AND-DEPENDENCIES.md`): download, don't vendor; before adding a dependency or cutting a release.
- **Backlog and issues** (`docs/BACKLOG-FORMAT.md`): `docs/BACKLOG.md` is the build-status source; file noticed bugs via the `issue` skill.
- **API changes are additive.** No push-triggered GitHub Actions in private repos; checks run locally through `check.sh`. Stack: `STACK.md`.
- **Platform standards** (`home`, `bot`, `catalog`, `go`): `docs/PACKAGES.md`, `UI.md`, `SETTINGS.md`, `ENGINEERING.md`, `STYLE.md`, `UPDATES.md`, `BACKUPS.md`, `NOTIFICATIONS.md`, `SERVICES.md`.
