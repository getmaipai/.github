# MaiPai org standards

Applies to every repo in the `getmaipai` org. A repo's own CLAUDE.md holds only project specifics.
If a repo file contradicts this one, the repo file wins for that repo; flag the conflict.
Detail lives in `docs/`. Each section ends with the trigger for loading its doc.

## The products

MaiPai's promise: private, local AI that is actually yours. Nothing leaves the home. Every decision honors that.

| Repo | Product | What it is |
|---|---|---|
| `stack` | MaiPai Stack | Headless engine service behind Home; Home is its only caller; ships inside Home's installer. |
| `commons` | (libraries) | `ui`, `core`, `spec`, tagged on their own; public; imports no product. |
| `home` | MaiPai Home | Self-hosted family AI hub: the platform and the household's master; every feature is a catalog package. |
| `catalog` | MaiPai Catalog | Public signed package catalog; hub and robot install from it; pins `spec`, no schema mirror. |
| `go` | MaiPai Go | Apple TV and iPhone client rendering the UI schema natively; built last. |
| `bot` | MaiPai Bot | Robot companion; pairs with the hub, complete alone; one body layer, a profile per body. |
| `.github` | (this repo) | Org standards, `@maipai/standards`, the shared Claude plugin, org profile. |

- Pitch copy is verbatim from `brand/COPY.md`; logos come from `brand/`, never redrawn.
- A GitHub repo description is one sentence, at most 120 characters, from COPY.md's "repo description".
- Pre-rebuild code exists only as local mirrors (`legacy-backups/*-legacy.git`): copy hard-won logic, never feature scope.

Load `docs/PLATFORM.md` before touching product framing, repo descriptions or the rebuild history.

## Platform principles

Hold across `home`, `bot`, `catalog`, `go`.

1. **Simplify: centralize and reuse.** One definition, implementation and store; a second copy is wrong even when faster.
2. **The robot is complete without a hub.** Its own people, settings, memories, packages; nothing on it is a stub.
3. **No data debt.** Every record is the shared spec shape with id, provenance and clock stamp from first boot.
4. **One definition, one place.** A key, record type, config or shape is declared once; every renderer draws from it.
5. **Repos only when necessary:** a different release cadence, committer audience or visibility.
6. **Prebuilt over hand-built.** Maintained libraries and native engine features beat hand-rolled logic or long prompts.
   No hand-built UI: assistant-ui Elements for chat; shipped kit primitives and `shadcndashboard` pages for all else,
   used as they ship, restyled by tokens only, never forked. Home writes routes, data and copy, never a component.
7. **Hub first, robot for parity, Go last.** Every hub step is in family use before its robot counterpart; the Stack follows the same rule.
8. **Every feature is reviewed and rebuilt, never carried.** Legacy code is not a requirement; record a one-line verdict first.

- Shared record changes go through the spec first (`spec/` in `commons`), then hub, then robot. A one-sided patch is a bug.
- Design ambiguity is a research task: dispatch `design-resolver` before asking Jesse. Escalate only low-confidence results or his own calls (releases, deploys, go/no-go, review verdicts, real-world facts).

Load `docs/PLATFORM.md` before applying principle 6's UI rule, principle 8, or a record change.

## Do what Jesse asks (owner's rule, 2026-10-04)

When Jesse asks for something that is not coding or architecture (a command to run, a session to open, a thing to stop or start, a
setting, a file to move), do exactly that, in the form he asked for. Never swap in a different action, a different tool or a
different form (he asked for the commands, so give the commands; he asked to see a list, so show the list; he asked for four
sessions opened by him, so do not open them yourself). Deviate only when the request does not make sense, would damage something,
or you have a clearly better way: then say so in one or two sentences and ask, and wait for his answer on that one point while
the rest of the work continues. Acting first and explaining later is a defect. If he corrects you, undo what you did without
being asked and do what he asked.

**Decisions go to Jesse through the question wizard (owner's rule, 2026-10-05).** Any decision, go/no-go, preference or choice
that is his is asked with the AskUserQuestion tool: one short form of 1 to 4 questions, plain words a non-engineer follows, the
recommended option first and marked "(Recommended)", one line per option on what happens if chosen. Never ask a decision as a
prose line, in the `YOU:` line or at the end of a report ("which should I settle first?", "tell me if..."). Decide what is not his
(document length, file names, lane choice, process) without asking. `YOU:` carries a command he must run or a fact he must act on,
never a decision. The rest of the work continues while a form is open.

## Roles: coordinator and coder

Two roles, held by different sessions. Policy here; procedure in the `coordinate` skill; full bullet text and detail: `docs/COORDINATION.md`, "Moved from CLAUDE.md".
A session names its model from its own system prompt before work starts ("unknown" is allowed; the coordinator resolves it with Jesse).
Sonnet 5.5 coordinates; Opus 5.5 is its senior consultant (a bounded question, never the whole session); Fable 5.1 is the exceptional escalation; Haiku 4.5 retrieves evidence and never writes source.

- **The coordinator owns architecture, design and diagnosis; it never types code and never runs a long process** (no editing source or tests, scripts, suites, benches, engines, builds, `check.sh`, no babysitting servers). It escalates reasoning it lacks and stays accountable; it may write docs, issues, backlog items, handoff notes. About to edit code or start a bench: write the prompt instead.
- **Event-driven, never polled.** Every work order carries the reporting contract (ready, done, blocked, question, low context); verify a done report against acceptance; classify a blocker before choosing a remedy; one named integrator merges parallel lanes serially.
- **Codex does the building and running, first; never the thinking** (decided changes, gates, tests, builds, commits, landings, captures; never plans, architects, designs, diagnoses, decides). GPT-6 Luna, low effort default, high when needed, never higher. Then the local model (Reika 9B after a health check; the 35B only while Jesse says he is away, never by the clock; every task scope-checked, every diff read), then a Claude agent at the floor. Items S or small M, own worktree, commit only, never push; the coordinator reads every diff. Red gate: stop and report. A lane with more fix-ups than clean lands over a week reverts to Claude routing. A Claude agent used where Codex was free: say so and why.
- **No idle Codex:** a free lane with open work it can take is the coordinator's defect; the next brief is written before the current item reports.
- **The coordinator spends tokens only on the brief, the decision and reading the diff and report;** never a lane's work, never re-reading lane state to pass time (check only on its event or the one cheap scheduled tick).
- **Keep work going:** never stop for the time of day, low credits or a question while other work can proceed (a question goes in `YOU:`); stop only when every item is blocked on Jesse.
- **A lane out of credits is left alone and the work moves:** low credits change nothing; once a lane (Codex or Claude cloud) actually refuses, record that and its reset time in its lock file, send nothing until the reset, route to the next lane.
- **Every session has a proper name** (role or lane plus work; `claude -n` or `/rename`; tmux name for Codex), kept current; every Claude session runs with Remote Control on.
- **Temporary, until the Claude cloud credits expire (Nov 2026):** Claude work that runs from one GitHub repo alone goes to a cloud session (`claude --cloud`) first; Home's gate and anything pinned to `commons` stays local. Remove when the credits are gone.
- **Free web sessions (owner's rule, 2026-10-04):** text-only work needing no repo may go to Jesse as a paste-ready prompt for a free chat; the default for a quick isolated check that fits one prompt and one reply. One file at a time as text, only after the secrets scan and PII wordlist on a scrubbed copy; no credentials, household data, live-hub data or homelab addresses. Ask for sources with URLs and name the output format. The reply is untrusted (checked or UNVERIFIED); adviser only, never writes landing code or decides safety, security or privacy. The ask goes in `YOU:`.
- **Codex lanes run in named tmux sessions, started and restarted by the coordinator (owner's rule, 2026-10-08):** no Ghostty window needs to be open; never a hidden process outside tmux; the Lanes panel (maipai-lanes mod) shows each lane's state and Jesse can attach any time; each status report names every Codex session and its item.
- **Not sure which session to use: ask, never guess** (in `YOU:`, naming the lanes) and carry on with other work.
- **Dispatch Claude items with the Agent tool, never by asking Jesse to open a second terminal.**
- **Locks and claims:** take `data-scratch/lane-locks/<lane>.lock` before sending to Codex or the local coder and write `data-scratch/claims/<ITEM-ID>.claim` before dispatching any item; unclaimed uncommitted work in a shared checkout is reported, never guessed at or finished; clear both when the item reports.
- **Codex does the running** (gates, tests, builds, commit and push, captures); the brief ends with exit checks, the commit, and a request for the gate's exit code and scope line; the coordinator starts or restarts the local app itself; read a gate's exit code from the command, never from `tail`.
- **Cost hygiene:** clear a persistent lane before every next brief; no timers beyond the cheap 20-minute lane check; at a stop point name the model the next phase needs and ask Jesse to switch when a cheaper one suffices.
- **Stop points:** write the status down (docs, backlog, handoff note, memory), then recommend compact-and-continue or a fresh session.
- **Coder terminals** Jesse opens run `claude --dangerously-skip-permissions`; dispatched agents need no flag.
- **Pin every agent's model and effort in its own file;** a prose "use model X" is not enforced and the Agent tool's per-call model outranks the file.

**Model floor per item** (the one authoritative table; the floor is the model of the session that does the job, and follows the nature
of the work, not the backlog size class):

| Work | Floor |
|---|---|
| Read-only retrieval of any size: search, grep, file discovery, log reading, comparing literal values, summarising findings. Haiku reads; it does not write source | Haiku 4.5 |
| Coordination, briefs, status, ordinary diff review and acceptance checks; a coding lane implementing a decided design; anything with a verification loop (screenshots, a bench, a guard to prove); work whose acceptance requires interpreting verification results; research summaries; large or multi-subsystem work whose result a test, gate or measurement can verify; measurement plus straightforward interpretation | Sonnet 5.5 |
| A decision between competing plausible designs; a subtle root cause after verified attempts by cheaper lanes failed; a security, safety, credential or privacy decision that needs judgment, including review of a guard, Incognito or credentials change that needs it (a mechanically verifiable change with an explicit specification and strong tests stays Sonnet); contradictory evidence Sonnet cannot reconcile; Sonnet keeps revising the same conclusion or has low confidence on something no check can verify | Opus 5.5 |
| Opus 5.5 at high effort has failed to resolve a reasoning problem (one serious attempt is enough) and the coordinator can state what extra capability or longer horizon Fable is expected to bring (a missing requirement, missing information, an environment fault or an impossible premise is not fixed by a bigger model); or an unusually deep, long-horizon redesign or investigation the coordinator can justify; or Jesse asks for it | Fable 5.1 |

The floor is a minimum: use the cheapest lane and model that clears it. **Escalate judgment, not workload:** only when the blocker needs
materially better reasoning (competing designs, contradictory evidence, subtle root cause after verified attempts, high-consequence judgment,
low confidence no check can verify); mechanically verifiable work stays cheap even when big. Opus gets one bounded question with minimum
context while the session stays on Sonnet; Fable costs several times Opus. Label and co-author lines are hints, not proof. A model change
fixes only a reasoning failure: context exhaustion gets a handoff, an environment blocker gets fixed, an unclear requirement gets a decision, a stalled top model gets the item re-scoped.

Load `docs/COORDINATION.md` before directing sessions, dispatching a lane, or running the coordinator role.

## Architect gate

A repo with `docs/design/RULES.md` keeps its hard design rules there; that file is the authority, and `docs/dev.md` and `docs/plans/` are history.
Before a backlog item is dispatched, a design note is committed, or a commit touches `docs/design/`, `docs/plans/`, `docs/BACKLOG.md`
or a path an area's `Governs:` line names, the `architect` agent rules on it: APPROVED, REJECTED (rule quoted), DUPLICATE (backlog id)
or NEEDS-RULE-CHANGE (to Jesse). The verdict lands in `data-scratch/architect/<ITEM-ID>.verdict`; the commit hook and the `coordinate`
skill require a fresh APPROVED one. Only Jesse changes a rule, and a commit that edits `RULES.md` carries `Owner-approved: <date>`.

Load `docs/ARCHITECT.md` before writing a design note, a rule change or a verdict.

## Git workflow

- **Land directly on `main`. Never open pull requests.** Only `catalog` accepts community PRs, gated on CLA and CI; maintainers still land on `main`.
- **No branch or worktree** unless Jesse asks or a parallel session edits the same repo. Merge and delete before the session ends; flag strays.
- **Commit only completed, verified work**, one logical change per commit. No checkpoint or WIP commits; unfinished work is a dirty tree plus a status note.
- **Never stage blindly.** Read `git status` and `git diff`, then stage files by name. Never `git add -A`, `.` or `commit -a` unseen
  (hook: `block-blind-staging.sh`; `block-wholesale-shared-docs.sh` refuses a plain add of `docs/dev.md` or `docs/BACKLOG.md`).
- **In a shared checkout, staging and commit are atomic:** `git add` only your files (`-p` for shared docs), check `git diff --cached --stat`,
  run a bare `git commit` at once. Never `git commit -- <files>`. Read `git show --stat HEAD` after every commit.
- **Never `git rebase`, `reset` or `checkout` in a shared checkout** without checking `git status` and `git diff --cached` for another session's work.
- **Review before committing code** (not docs): the `code-review` skill on the exact diff, passing an explicit target in a worktree and confirming the reported path is yours (hook: `require-review-before-commit.sh`). Level `low` by default; `medium` needs a named reason (route, guard, wire shape, auth, safety); `high` only if the coordinator names it. One pass per commit; re-review fix hunks only; never a third. Never review vendored code. The done report states level, pass count, wall time and each finding's disposition. Detail: `docs/COORDINATION.md`, Moved from CLAUDE.md.
- **Push at natural boundaries**, not after every commit. Deploys and releases need Jesse's word in the moment.
- **Author identity:** the GitHub noreply address; no personal email in code, docs or metadata.
- **Clean up old things the moment you find them (owner's rule, 2026-10-03).** Merged or abandoned branch, finished worktree, dead file or script, uncalled code, superseded doc, leftover claim, lock or tmux session: remove it this session, or file a backlog item with evidence. Only if it is yours or provably dead (merged into `main`, no live reference, no uncommitted work, no running process); the report names what went and why. Anything that may be another session's or Jesse's data is listed with evidence, never deleted unseen. Code removal follows port-before-delete. Detail: `docs/COORDINATION.md`, Moved from CLAUDE.md.

Load `docs/GIT-WORKFLOW.md` before staging in a shared checkout, running a review, or when a hook denies a git command.

## Verification (definition of done)

- **`scripts/check.sh` must pass on the tree a push sends, before that push** (hook: `require-gate-before-commit.sh`); any edit after the gate reruns it. Docs-only commits run `check.sh --docs`.
- **The gate is scoped by the diff against the `origin/main` merge-base**, never by judgment; it prints `== scope: ...` first and the done report repeats it. Secrets scan and PII wordlist run on every scope.
- **One full gate at a time per machine** (`gate-lock.sh`); never hand-roll a wait. A port or memory failure in an untouched test is rerun once alone, then reported as an environment finding.
- **A check, test, bench or screenshot script never changes the machine outside the repo** and never opens a visible browser window (headless only; report if it cannot start after one retry).
- **A universal claim needs an inventory:** enumerate and test every producer or consumer it covers.
- **Evidence matches the acceptance criterion:** regression test, or the flow exercised and the screenshot opened, or measured numbers with engine build, model file and a sanitized hardware description (never a hostname).
- **"Verified" means exercised for real.** "It compiles" is not verified.
- **Never hand Jesse something to check that you have not checked yourself;** if you cannot (his hardware, his judgment), say exactly that and why. **Never ask him to run a command you can run yourself** (only what needs his session, device or credentials).
- **A second "fixed, try again" needs re-read proof:** read the stored record or real output yourself first.
- **Tests:** the repo's framework, a nearby test's structure, deterministic and offline, each named for the promise it checks. Every real failure becomes a regression test first, in the exact inputs that broke it. A weakened test is a finding, not a step.
Full wording: `docs/COORDINATION.md`, Moved from CLAUDE.md.

Load `docs/VERIFICATION.md` before gating, benching, writing tests, or claiming something is done.

## Documentation

- Claude writes all documentation prose; never ask permission to document. Docs change in the same commit as the behavior.
- Three tiers per `docs/STYLE.md`: `user/` (grade-6, no jargon), `dev/` (technical), `api/` (generated, never hand-written;
  Hono routes use `@hono/zod-openapi`, converted when touched).
- No owner-specific notes in docs; owner reminders go in the status block or an issue.
- Scratch and private notes live in the repo's git-ignored folder (`data-scratch/`), never at or above the org root.
- Screenshots are generated by script against the seeded demo household, never hand-taken, and every one is opened (Read) and judged
  before use anywhere: right screen, real content, no spinner, skeleton or error. Fix the capture, then retake.
- Build guides use final parts, not interim ones. READMEs follow the skeleton in `docs/STYLE.md`.

Load `docs/DOCUMENTATION.md` before writing user docs, READMEs, screenshots or build guides.

## Writing style

Reads like a sharp human wrote it. Applies to docs, UI copy, comments, commit messages, changelogs, issues.

- **No em dashes (U+2014), ever.** Comma, colon, parentheses or period; en dashes only for numeric ranges.
- **No filler vocabulary:** delve, seamless, robust, leverage, empower, elevate, streamline, game-changer, "in today's world", "it's important to note". <!-- prose-lint: allow -->
- **No "not just X, it's Y"**, no rhetorical questions as transitions, no exclamation points in technical prose. <!-- prose-lint: allow -->
- Bullets are for lists of things; flowing sentences are a paragraph.
- Concrete beats abstract: numbers, names and file paths over adjectives.
- User-facing copy passes the dad test: a busy parent with basic tech knowledge understands it on first read.

**End every reply to Jesse with the status block:** three lines, uppercase labels, this order, nothing after it.

```
STATE: <word> · <session>: <item> (running ~<when> | holding, behind <what> | blocked) · landed <item>
PROGRESS: <milestone>  ▰▰▰▱▱▱  3/6  ·  now <item>  ·  next <items in order>
YOU: nothing | <ask> (whenever) | <ask> (blocking: <what it holds>)
```

`STATE:` opens with exactly one word:
- `done`: everything asked for has landed, nothing is running, nothing is owed by anyone.
- `active`: work is running now (session, agent, gate, bench) and will report on its own.
- `waiting [<what>]`: stopped until a named thing happens that is not Jesse's to do. The bracket is mandatory; a bare `waiting` is a defect.
- `blocked [<owner>: <what>]`: stopped, and cannot restart until the owner does the named thing. Never for a fact that stops nothing.

`YOU:` is the only place an ask appears, written for a reader who saw no earlier message (the exact command or decision, never "still yours").
`STATE: done` and `YOU: nothing` go together.

Load `docs/DOCUMENTATION.md` (Writing style, full text) before writing a long report or a status block with several sessions.

## Privacy and PII (hard rules)

- **Never commit:** family member names, home address, phone numbers, personal email, credentials or tokens, real LAN IPs or homelab hostnames.
  Jesse's own name is the one exception.
- **Examples use** `192.0.2.x` IPs, `example.com`, and persona names only from this roster:
  alfred, astro, atlas, bramble, bruno, clover, cosmo, daisy, ember, indigo, iris, juniper, lucia, marlow, marsh, mopey, nadia, nova, oliver,
  pippa, quill, raven, riff, rivet, rover, sage, serena, sprout, tempo, velvet, vincent, willow.
- Homelab details live only in Jesse's private homelab repo, referenced but never embedded.
- `check.sh` enforces this: gitleaks plus a word-boundary scan against the private `~/.config/maipai/pii-words.txt` (never committed).
- Screenshots and demo data never contain the real family's profiles, history or location.

## Topics with their own docs (load before the trigger)

- **Privacy architecture:** zero phone-home; no MaiPai-operated service in a user data path; one optional owner-keyed hosted search provider
  (off by default, never for a child or teen). Load `docs/PRIVACY.md` before adding or changing an outbound connection.
- **Third-party services:** behave as the user would, automated: a person's pace, the front door, back off on the first signal.
  Load `docs/THIRD-PARTY-SERVICES.md` before code that fetches from an external service.
- **Credentials:** never commit secrets; encrypt at rest; least privilege; per-person identity. Load `docs/CREDENTIALS.md` before auth, tokens, OAuth, API keys or cookies.
- **Safety:** child protections are non-removable architecture; child profiles restricted by default; the output gate's grain follows the person.
  Load `docs/SAFETY.md` before generation, chat, child profiles or adult unlock.
- **Rules and learned components:** the model decides; no word rule or router; a rule needs a counter and a row; a learned component never sits in the safety, consent or privacy path.
  Load `docs/RULES-AND-LEARNED-COMPONENTS.md` before editing a rule, word list or classifier in a turn pipeline.
- **Trademarks:** third-party platforms by name, descriptively, no borrowed trade dress. Load `docs/TRADEMARKS.md` before copy or UI that mentions one.
- **Licensing:** AGPL-3.0 from the first commit; copyright stays with Jesse. Load `docs/LICENSING.md` at repo setup, release, or before a doubtful dependency.
- **Training models:** verify data landed, validate on a real microphone, train against near misses. Load `docs/TRAINING-MODELS.md` before any training run.
- **Download, don't vendor:** dependencies come via the package manager with a lockfile; third-party models and binaries are fetched on demand, pinned and checksummed.
  Load `docs/RELEASES-AND-DEPENDENCIES.md` before adding a dependency, copying third-party code or cutting a release.
- **Backlog and issues:** `docs/BACKLOG.md` is the build-status source; update it in the same commit; file noticed bugs as plain-language issues via the `issue` skill.
  Load `docs/BACKLOG-FORMAT.md` before editing the backlog or filing an issue.
- **API changes are additive.** Never remove or repurpose a field clients rely on without a versioned path and a changelog note.
- **No push-triggered GitHub Actions in private repos.** Checks run locally through `check.sh`.
- **Stack:** see `STACK.md`; a deviation needs written justification in the repo's dev docs.
- **Platform standards** (`home`, `bot`, `catalog`, `go`), pinned by `@maipai/standards`; a repo CLAUDE.md never weakens them:
  `docs/PACKAGES.md`, `UI.md`, `SETTINGS.md`, `ENGINEERING.md`, `STYLE.md`, `UPDATES.md`, `BACKUPS.md`, `NOTIFICATIONS.md`, `SERVICES.md`.
