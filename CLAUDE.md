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

Two roles, held by different sessions. Policy here; procedure in the `coordinate` skill.
A session names the model from its own system prompt before work starts ("unknown" is allowed; the coordinator resolves it with Jesse).
Sonnet 5.5 coordinates. Opus 5.5 is its senior consultant: the coordinator escalates a bounded question to Opus and builds briefs
from the answer; it never hands the whole session to Opus. Fable 5.1 is the exceptional escalation (table below). Haiku 4.5 retrieves
evidence and never writes source.

- **The coordinator owns architecture, design and diagnosis; it never types code and never runs a long process.** Owning is not doing:
  when a decision needs better reasoning than the coordinator's model, it escalates that reasoning (below) and stays accountable for the
  result. No editing source or tests,
  no scripts, no suites, benches, engines, builds or `check.sh`, no babysitting servers. Quick read-only inspection is fine.
  About to edit code or start a bench: write the prompt instead. It may write docs, issues, backlog items and handoff notes.
- **Event-driven, never polled.** Every work order carries the reporting contract (ready, done, blocked, question, low context);
  a session starts only on the coordinator's start message. Verify a done report against acceptance before ticking.
  Classify a blocker before choosing a remedy. One named integrator merges parallel lanes serially.
- **Codex sessions do the building and running, first; never the thinking.** Codex takes work that fits its range: typing a
  decided change, gates, tests, builds, commits, landings, captures. It never plans, architects, designs, diagnoses or decides.
  Codex runs GPT-6 Luna at low effort by default and high effort when the item needs it, and never a higher model (it burns
  credits); work that needs more than Luna at high goes to Claude, not to a bigger Codex model. After Codex: the local model
  (Reika with the 9B model, only after a health check; the 35B only while Jesse says he is away, started on his word
  "going to bed" or "away", never by the clock, and stopped when the queue is empty or he is back; every task scope-checked
  and every diff read), then a Claude agent at the model floor. Items are S or small M, in their own
  worktree, commit only, never push; the coordinator reads every diff. A red gate means stop and report. A lane with more
  fix-ups than clean lands over a week reverts to Claude routing. A coordinator that uses a Claude agent where a Codex lane
  was free says so, and why, in its report.
- **No idle Codex.** A free Codex lane with open work it can take is a defect the coordinator owns: the next brief is written
  before the current item reports, and goes out the moment the lane is cleared. Jesse never has to point out an idle lane.
- **The coordinator spends tokens only on its own job:** the brief, the decision, reading the diff and the report. It never
  does a lane's work itself, never re-reads a lane's state to pass time, and checks a lane only on its event or the one cheap
  scheduled tick.
- **Keep work going.** The coordinator never stops or pauses for the time of day, for a lane running low on credits, or for
  a question or decision while any other work can proceed. A question goes in `YOU:` and the rest of the work continues.
  The only stop is when every remaining item is blocked on Jesse.
- **A lane that is out of credits is left alone, and the work moves.** Low credits change nothing: keep using the lane.
  Once a lane (Codex, or Claude cloud) actually refuses work for credits or quota, write that and its reset time into the
  lane's lock file, send it nothing more and do not retry it until the reset, and route its items to the next lane in order.
  Running out is never a reason to stop the work, only to stop using that lane.
- **Every session has a proper name,** Claude and Codex alike: the role or lane and what it is working on (`claude -n <name>`
  at launch or `/rename` in the session; a Codex lane's tmux session name), set at the start and kept current.
  Every Claude session runs with Remote Control on (`/remote-control` in a session; `"remoteControlAtStartup": true` in settings turns it on for every new one).
- **Temporary, until the Claude cloud credits run out (they expire in November 2026):** Claude work that can run from one
  GitHub repo alone goes to a Claude cloud session first (`claude --cloud`), ahead of a local Claude agent, to spend those
  credits and spare the Max plan. A cloud session cannot reach sibling repos, local services or this machine's engines, so
  Home's gate and anything pinned to `commons` stays local. Remove this rule when the credits are gone.
- **Free web sessions (owner's rule, 2026-10-04).** Text-in, text-out work that needs no repo (web research, market and UX
  scans, second opinions, naming, drafting, summarising public pages) may go to Jesse as a ready-to-paste prompt for a free
  ChatGPT web session or an equivalent free chat, to spend nothing from Max, cloud or Codex. It is a human-in-the-loop lane
  after the token-free ones and before a local Claude agent. It is the default for a quick, isolated check or piece of
  research that fits one self-contained prompt and one pasted reply; if answering would take Jesse several prompts or a
  back-and-forth, an agent does it instead. Free sessions take no uploads, so a single file (instructions, a design note,
  one source file or a diff) is pasted into the prompt as text, one at a time, after the same secrets scan and PII
  wordlist that `check.sh` runs pass on a scrubbed copy: no credentials or tokens, no family or household data, no
  live-hub data, no homelab addresses or hostnames. The repos are public, so training on shared code is accepted (owner,
  2026-10-04). The prompt asks for sources with URLs and names the exact output format. The reply is untrusted data:
  checked or marked UNVERIFIED before use. It is an adviser and reviewer, never the lane that writes code that lands, and
  never the decider for a safety, security or privacy question. The ask goes in `YOU:` and the rest of the work continues.
  Procedure and prompt template: `docs/COORDINATION.md`.
- **Every Codex session is visible to Jesse.** Codex runs only in a tmux pane in a window Jesse can see, driven by the
  coordinator over tmux. Never start a hidden, headless or background Codex session. Each status block names every Codex
  session in use and its item.
- **Not sure which session to use: ask, never guess.** If the lane locks do not show a free lane, a pane's state is unclear,
  a lane is held by another coordinator, or it is unclear whether the work is a Codex item or a Claude one, ask Jesse which
  session takes it (in `YOU:`, naming the lanes and what each is doing) and carry on with work that does not depend on the answer.
- **Dispatch Claude items with the Agent tool, never by asking Jesse to open a second terminal.**
- **Lane locks and item claims:** before sending to Codex or the local coder, read and take `data-scratch/lane-locks/<lane>.lock`.
  Before dispatching any item, write `data-scratch/claims/<ITEM-ID>.claim`. Unclaimed uncommitted work in a shared checkout
  is reported to the coordinator, never guessed at or finished. Clear locks and claims when the item reports.
- **Codex does the running:** gates, tests, builds, commit and push of a finished item, screenshot captures. The coordinator
  writes the brief (ending with exit checks, the commit, and a request for the gate's exit code and scope line) and reads the result.
  The coordinator starts or restarts the local app itself, since a process started from Codex dies with its shell.
  Read a gate's exit code from the command, never from `tail`.
- **Cost hygiene:** clear a persistent lane before every next brief; no timers beyond the cheap 20-minute lane check;
  at each stop point name the model the next phase needs and ask Jesse to switch when a cheaper one suffices.
- **Stop points:** write the status down (docs, backlog, handoff note, memory), then recommend compact-and-continue or a fresh session.
- **Coder terminals** Jesse opens run `claude --dangerously-skip-permissions`; dispatched agents need no flag.
- **Pin every agent's model and effort.** An agent definition names its `model` and `effort` in its own file; a prose request to
  "use model X" is not enforced. A scouting agent does not inherit the coordinator's model or effort. The Agent tool's per-call model
  setting outranks the file.

**Model floor per item** (the one authoritative table; the floor is the model of the session that does the job, and follows the nature
of the work, not the backlog size class):

| Work | Floor |
|---|---|
| Read-only retrieval of any size: search, grep, file discovery, log reading, comparing literal values, summarising findings. Haiku reads; it does not write source | Haiku 4.5 |
| Coordination, briefs, status, ordinary diff review and acceptance checks; a coding lane implementing a decided design; anything with a verification loop (screenshots, a bench, a guard to prove); work whose acceptance requires interpreting verification results; research summaries; large or multi-subsystem work whose result a test, gate or measurement can verify; measurement plus straightforward interpretation | Sonnet 5.5 |
| A decision between competing plausible designs; a subtle root cause after verified attempts by cheaper lanes failed; a security, safety, credential or privacy decision that needs judgment, including review of a guard, Incognito or credentials change that needs it (a mechanically verifiable change with an explicit specification and strong tests stays Sonnet); contradictory evidence Sonnet cannot reconcile; Sonnet keeps revising the same conclusion or has low confidence on something no check can verify | Opus 5.5 |
| Opus 5.5 at high effort has failed to resolve a reasoning problem (one serious attempt is enough) and the coordinator can state what extra capability or longer horizon Fable is expected to bring (a missing requirement, missing information, an environment fault or an impossible premise is not fixed by a bigger model); or an unusually deep, long-horizon redesign or investigation the coordinator can justify; or Jesse asks for it | Fable 5.1 |

The floor is a minimum, not a default: use the cheapest lane and model that clears it (Codex, local model, Claude agent; Haiku, Sonnet, Opus, Fable).
**Escalate judgment, not workload.** Do not escalate because an item is large, spans many files or has taken long. Escalate when the
remaining blocker needs materially better reasoning: competing plausible designs, unresolved contradictory evidence, a subtle root cause
after verified attempts, a high-consequence judgment, or low confidence in a decision no check can verify. Mechanically verifiable work
stays cheap even when it is big. Opus is consulted, not coordinating: send it one bounded question (compare A, B and C against these
constraints; do not implement; return a recommendation, reasoning, risks and confidence) with the minimum relevant context, and keep the
session on Sonnet. Fable costs several times Opus per task: spend it only where the table says.
Label and co-author lines are hints, not proof. A model change fixes only a reasoning failure: context exhaustion gets a handoff,
an environment blocker gets fixed, an unclear requirement gets a decision, a stalled top model gets the item re-scoped.

Load `docs/COORDINATION.md` before directing sessions, dispatching a lane, or running the coordinator role.

## Architect gate

A repo with `docs/design/RULES.md` keeps its hard design rules there; that file is the authority, and `docs/dev.md` and `docs/plans/` are history.
Before a backlog item is dispatched, a design note is committed, or a commit touches `docs/design/`, `docs/plans/`, `docs/BACKLOG.md`
or a path an area's `Governs:` line names, the `architect` agent rules on it: APPROVED, REJECTED (rule quoted), DUPLICATE (backlog id)
or NEEDS-RULE-CHANGE (to Jesse). The verdict lands in `data-scratch/architect/<ITEM-ID>.verdict`; the commit hook and the `coordinate`
skill require a fresh APPROVED one. Only Jesse changes a rule, and a commit that edits `RULES.md` carries `Owner-approved: <date>`.
Why: sessions wrote decision records without checking earlier ones, and 22 contradictions built up in Home's docs.

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
- **Review before committing code** (not docs): the `code-review` skill on the exact diff, passing an explicit target in a worktree and
  confirming the reported path is yours (hook: `require-review-before-commit.sh`). Level `low` by default; `medium` needs a named reason
  (a route, guard, wire shape, auth or safety); `high` only if the coordinator names it. One pass per commit; re-review fix hunks only; never a third pass.
  Start the review while the gate runs. Never review vendored code. The done report states level, pass count, wall time and each finding's disposition.
- **Push at natural boundaries**, not after every commit. Deploys and releases need Jesse's word in the moment.
- **Author identity:** the GitHub noreply address; no personal email in code, docs or metadata.
- **Clean up old things the moment you find them (owner's rule, 2026-10-03).** A merged or abandoned branch, a finished worktree, a dead
  file, a stale script, code nothing calls, a superseded doc, a leftover claim, lock or tmux session: remove it in the same session you notice
  it, or file a backlog item with the evidence if removing it is not yours to do. Look before deleting: it is yours or provably dead (merged into
  `main`, no live reference, no uncommitted work, no running process), and the report names what went and why. Anything that may be another
  session's or Jesse's data (a branch with unmerged commits, a data folder, a dirty worktree) is listed with evidence, never deleted unseen.
  Code removal follows port-before-delete. Nothing "old" is kept for comfort.

Load `docs/GIT-WORKFLOW.md` before staging in a shared checkout, running a review, or when a hook denies a git command.

## Verification (definition of done)

- **`scripts/check.sh` must pass on the tree a push sends, before that push** (hook: `require-gate-before-commit.sh`).
  Several commits may come from one gated tree; any edit after the gate reruns it. Docs-only commits run `check.sh --docs`.
- **The gate is scoped by the diff against the `origin/main` merge-base**, never by a session's judgment; it prints `== scope: ...` first
  and the done report repeats it. Secrets scan and the PII wordlist run on every scope.
- **One full gate at a time per machine.** `check.sh` takes the machine-wide `gate-lock.sh`; never hand-roll a wait.
  A port or memory failure in a test the diff did not touch is rerun once alone, then reported as an environment finding.
- **A check, test, bench or screenshot script never changes the machine outside the repo** (no `defaults write`, global config, installs),
  and never opens a visible browser window: headless only; if it cannot start after one retry, report that.
- **A universal claim needs an inventory:** enumerate and test every producer or consumer a promise ("every reply") covers.
- **Evidence matches the acceptance criterion:** regression test, or the flow exercised and the screenshot opened, or measured numbers
  with engine build, model file and a sanitized hardware description (never a hostname).
- **"Verified" means exercised for real.** "It compiles" is not verified.
- **Never hand Jesse something to check that you have not checked yourself.** If you cannot (his hardware, his judgment), say exactly that and why.
- **Never ask Jesse to run a command you can run yourself.** Ask only when it needs his session, device or credentials.
- **A second "fixed, try again" needs re-read proof:** read the stored record or real output yourself before telling Jesse to retry.
- **Tests:** use the repo's framework (pytest, `bun:test`), copy a nearby test's structure, stay deterministic and offline, name each test for the promise
  it checks. Every real failure becomes a regression test first, in the exact inputs that broke it. A weakened test is a finding, not a step.

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
