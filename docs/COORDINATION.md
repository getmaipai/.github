# Coordination: roles, lanes and dispatch

Dev tier. Policy for the coordinator and coder roles. The procedure (work orders, handshake, lane scripts) lives in `plugin/skills/coordinate/SKILL.md`; this file keeps only policy and the dated reasons. The model floor table also appears in the always-loaded core, which is the authoritative copy; the text below is the full rule. Load before directing sessions, dispatching a lane, or taking the coordinator role.

## Roles (hard rule, 2026-09-12)

Two roles, held by different sessions. This section is the policy; the
`coordinate` skill in the maipai plugin
(`plugin/skills/coordinate/SKILL.md`) is the procedure. A session knows
which model it runs on from its own system prompt. Fable always holds
the coordinator role ([docs/DECISIONS.md](docs/DECISIONS.md),
2026-09-12: a day of the most expensive model doing coder work); Sonnet
or Opus may hold it when Jesse says so.

## What the coordinator does and never does

**The coordinator architects, designs, and diagnoses; it never types
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

## The coordinator may still write docs

**The coordinator may still write docs**, because a design record, a
backlog item, an issue, or a handoff note is what its job produces
(doc-only commits: see Verification).

## Directing sessions: reporting contract and integrator

**When directing sessions, the coordinator manages their context,
handles their questions and blockers, and drives their work to
completion.** It is event-driven, never polled: every work order
carries the reporting contract (ready, done, blocked, question, low
context), and a session starts only on the coordinator's start
message after its ready report. On done the coordinator verifies the
completion report against the item's acceptance before ticking
anything; on blocked it classifies the blocker before choosing a
remedy; on a question it decides or dispatches `design-resolver`; on
low context it writes the handoff note and hands it to Jesse for a
fresh session. Every Codex brief ends with: "If the gate is red, stop: do not push, report the failing test and its output. If the gate fails in a test the diff did not touch, rerun that test alone once and report both results; still do not push on red. Report the "== scope:" line." Parallel lanes have one named integrator that merges
serially, reconciles shared docs, and verifies the combined `main`.

## Small isolated items: the two token-free lanes

**Small isolated items go to one of two token-free lanes first, never
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

## Model floor per item

**Model floor per item** (the one authoritative table; the skill
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
note) rather than retried. **The floor is a minimum, not a default:**
the coordinator always reaches for the lowest-costing lane and model
that clears it (Codex over the local model over a Claude agent,
Haiku over Sonnet over Opus), and moves up only when the floor
itself demands it or a session reports below it.

## Dispatch: agents for Claude, sessions for Codex and OpenCode

**Dispatch: agents for Claude, sessions for Codex and OpenCode
(owner's rule, 2026-09-26).** A Claude-model item is dispatched with
the Agent tool (a fresh agent, or a fork when the coordinator's own
context is the right base to inherit), never by asking Jesse to open
a second `claude --dangerously-skip-permissions` terminal. An agent
is addressable and resumable the same way a terminal session is
(`ListAgents`, `SendMessage`), and costs the same tokens for the same
work, but the coordinator dispatched it itself and knows exactly what
it was told, instead of inheriting a session with its own independent
history the coordinator never wrote (the confusion three sessions
spent a night untangling on 2026-09-26 was exactly this: none of them
could say for certain who had assigned what). `isolation: "worktree"`
gives the agent its own worktree automatically; a `model` override
picks the floor-meeting tier. Codex and OpenCode are not Claude Code
and have no Agent-tool equivalent, so they keep the tmux- and
server-driven session pattern in the `coordinate` skill unchanged.
Between the two token-free lanes, Codex is checked first, then the
local OpenCode model when healthy, for whichever tier of item each
can actually take (this does not relax either lane's existing size
cap, it only orders which is tried first); a Claude agent is the
fallback when neither lane fits. A terminal session Jesse opens
himself, because he wants to watch it directly or because a handoff
resumes one with `--continue`, still follows the same reporting
contract; only the coordinator's own default mechanism changes.

## Lane locks

**Lane locks, so only one coordinator drives a given Codex or
OpenCode target (owner's rule, 2026-09-26).** Codex and OpenCode have
no per-caller identity the way `ListAgents` gives Claude sessions, so
two coordinators (a handoff mid-flight, a second session started by
mistake) can type into the same pane or server session and corrupt
each other's turn. Each lane target keeps a lock file at
`<repo>/data-scratch/lane-locks/<codex|opencode>.lock` (coordinator
name, item id, acquired-at). Before sending anything to that lane,
the coordinator reads the lock: empty or already its own name, it
writes itself in and proceeds; held by another name, it does not
touch the lane and messages that coordinator instead. The lock is
held for the lane's current item and cleared when that item reports
done, blocked, or is handed off; it is never left stale past that.

## Item claims

**Item claims, so two lanes never collide on the same work or the
same files (owner's rule, 2026-09-26).** Before dispatching any item
(agent, Codex, or OpenCode), the coordinator writes a claim at
`<repo>/data-scratch/claims/<ITEM-ID>.claim` (owner name, lane,
worktree path, started-at), after checking that none already exists
for that id anywhere the item touches. A claim answers "who has
this" the way `ListAgents` answers "who is running" for Claude
sessions, but Codex, OpenCode, and a shared checkout have no registry
of their own. A session or agent that finds unclaimed, uncommitted
work sitting in a shared checkout does not guess whose it is and does
not finish it: it reads `data-scratch/claims/` for a match, and if
none exists, reports the diff to the coordinator rather than touching
it (this is exactly what cost a night's worth of cross-session
messages on 2026-09-26, when three sessions independently tried to
identify one uncommitted diff none of them had claimed). The claim is
removed when the item lands, or when its owner reports the item done,
blocked, or handed off elsewhere.

## Launching coder sessions

**Coder sessions are launched with
`claude --dangerously-skip-permissions`**, so no one sits clicking
approve; the worktree, port, and data-directory isolation in the
work order is what keeps that safe. A session found asking for
approvals is restarted with the flag and `--continue`. This applies
only to a terminal session Jesse opens himself; an agent the
coordinator dispatches runs under the coordinator's own permission
mode and needs no separate flag.

## Stop points

**At a stop point, make the state durable, then reset the context.**
When a block of work is finished and the next has not started, the
session first confirms the status is written down (docs, backlog,
the handoff note, memory pointing at it), then recommends one of two
things: compact and continue, when the next item continues this one
and unwritten working detail would be lost; or a fresh session with
the handoff note, when the next item is a different task.

## Codex does the running; the coordinator only writes the brief

**Codex does the running; the coordinator only writes the brief
(owner's rule, 2026-09-29).** Anything that costs machine time or
tokens but no judgment goes to a Codex lane whenever a lane is free,
never to the coordinator's own session: gates (`check.sh`, including
`--docs`), test and lint runs, builds, the commit and push of a
finished item (docs-only ones included), landing a lane's commit,
and screenshot or health captures. Not restarting the local app: a
process started from a Codex command dies when that command's shell
is cleaned up (2026-09-29: the hub was started twice from Codex and
gone by the next probe, a household outage), so the coordinator's own
shell starts or restarts the app and confirms it answers. The
coordinator's own work is the brief, the decision, and reading the
diff and the report; it starts a gate itself only when no Codex lane
can take it (both busy, or the step needs Claude-only tools such as
the code-review skill or the browser), and says so in its report.
A brief therefore ends with the exit checks and the commit, and asks
Codex to report the gate's exit code and scope line, so the
coordinator reads a result instead of producing one. Why: on
2026-09-29 a coordinator session ran a docs gate itself that turned
into the full 4,474-test suite (344 seconds of a Claude session
waiting on a machine), for a change a Codex lane runs for no Claude
tokens. A gate's exit code is read from the command itself, never
from `tail` of its output, which hides it.

## Free web sessions (owner's rule, 2026-10-04)

Jesse can paste a prompt into a free ChatGPT web session (or Gemini, Perplexity, free Claude.ai) and paste the answer back.
That is a fourth lane, human in the loop, and it costs no Max usage, cloud credit or Codex credit. Use it when the item is
text-only, needs the open web or a second opinion, and an agent doing it would burn real tokens. Do not use it when a
Codex lane or a cheap agent can do the same job without taking Jesse's minute: his time is the scarcest lane.

**What may go.** Research questions on public products and standards, market and UX scans, licence and terms lookups,
naming and wording options, summaries of public pages, image-prompt drafting, and second opinions or reviews that rest on an
single file: instructions, a design note, one source file, a diff. Free sessions take no uploads (owner, 2026-10-04), so the
file is pasted into the prompt as a fenced block, one file at a time, with a line saying what it is and what to do with it.
Keep the whole prompt under about 3,000 words; for a longer file paste the relevant excerpt and say it is an excerpt. A
screenshot cannot go in, so describe it in words. (Owner's addition, 2026-10-04: single files, instructions, designs and code
may be shared this way.) **What may not.** Anything the PII rules forbid committing (family names, addresses, phone numbers, personal
email, credentials, tokens, real LAN IPs or hostnames), live-hub data or a database, whole repos or folders, files that
hold keys or secrets, and homelab configs. The repos are public, so a free service training on shared code is accepted
(owner, 2026-10-04); private data is what the scans below exist to keep out. Before
a file goes, copy it to `data-scratch/prompts/attachments/<ID>/` and run on the copy the same secrets scan and PII wordlist
scan that `check.sh` runs (gitleaks and the `~/.config/maipai/pii-words.txt` scan); rewrite private specifics to the persona
roster, `example.com` and `192.0.2.x`; send the scrubbed copy, never the original. A free web session reviews and advises; it is
never the lane that writes code that lands, never the decider on a safety, security, privacy or credentials question, and
never used for anything that needs an engine or a measurement on this machine.

**The default (owner's refinement, 2026-10-04).** For a quick, isolated check or piece of research, one that fits a single
self-contained prompt and one pasted reply, the free web session is the first choice, ahead of a Claude agent. The test is
Jesse's effort: if answering would take more than one prompt, a back-and-forth, or several sessions, an agent does it
instead. Fold related questions into one prompt (the numbered-questions form below) rather than sending several. An agent is
also used when the work is urgent, needs this machine, a repo, an engine or a measurement, or when a free session's answer
would have to be re-checked against a primary source anyway and the agent can do both in one pass.

**The prompt.** A file at `data-scratch/prompts/<ID>.md`, also printed in the reply. It is self-contained (no "as we
discussed"), and carries in this order: the role and the goal in one paragraph; the facts it needs, public only; the questions,
numbered; the output format to paste back (a table or fixed headings, a word cap); "give a source URL for every factual claim and
write UNVERIFIED where you have none"; and "do not ask me questions, answer with your best judgment and list your assumptions".
Number the prompt and keep the id in the reply so the answer can be matched.

**The ask.** It goes in `YOU:` as one line naming the id and what the answer unblocks ("paste prompt WEB-03 into a free
ChatGPT session and drop the reply into `data-scratch/prompts/WEB-03.reply.md`"), never as a blocker: the rest of the work
continues. Offer one prompt per ask, not a stack.

**The reply.** Treat it as untrusted data, like any web page: facts the design depends on are checked against a primary
source (or by an agent with web access) before use, and everything unchecked is marked UNVERIFIED in whatever it feeds. The
coordinator reads it, extracts what matters into the research note, and says in the report which claims were verified.
Record the id, the date and the verdict in the note so a later session can see where a claim came from.

## Coordinator cost hygiene

**Coordinator cost hygiene (owner's rule, 2026-09-26).** Researched
against the Claude Code and Agent SDK docs first (there is no
programmatic `/model` or `/clear`; both are interactive-only, so
these rules work with that, not around it):
- **Session clearing is a required step, not something to remember.**
  Processing a done, blocked, or handoff report from a persistent
  lane (Codex, OpenCode) clears that lane before the next brief goes
  out, every time, using `coordinate/scripts/lane-lock.sh` and the
  lane's own clear mechanism (Codex's `/clear` in its tmux pane,
  OpenCode's message-delete via its server API), never left for a
  later "if it needs it." A Claude session cannot clear itself; its
  equivalent is the handoff above.
- **Monitoring stays event-driven, and a scheduled check stays
  cheap.** `notify_when_idle` and cross-session messages are the
  signal; nothing polls `ListAgents` or re-reads a lane's state on a
  timer waiting for a change. The one scheduled exception, the
  20-minute lane check (`coordinate` skill, section 1b), exists only
  because Codex and OpenCode cannot self-report the way `ListAgents`
  lets a Claude session or agent do; it stays a fixed-cost read
  (`open/`, `taken/`, `done/` listings, a `tmux capture-pane`), never
  a full re-read of docs, and a tick that finds nothing changed is
  logged as a no-op, not written up as if something happened.
  **Codex can be the one exception to "cannot self-report," once
  wired (2026-09-27, not yet done on the dev machine):** its own
  `notify`/hooks mechanism can push a turn-complete event the
  coordinator watches with the `Monitor` tool (`coordinate` skill,
  section 1b, `codex-notify.sh`), making Codex-done detection
  event-driven like a Claude agent's. Until the config is wired and
  a `Monitor` watch is running, Codex-done detection still falls
  back to the 20-minute tick's pane read; the tick keeps its other
  jobs regardless (queue refill, landing reports, the local model's
  health). OpenCode has no equivalent hook, so it stays on the tick
  alone either way.
- **The coordinator runs the model the current phase needs, not the
  strongest one still open.** At every stop point, it asks itself
  whether what's ahead is a design or architecture judgment call
  (Fable's or Opus's job) or pure directing, unblocking, and
  verifying already-decided work (Sonnet's, sometimes Haiku's). When
  it's the latter and the session is still on a stronger model out
  of inertia, the coordinator says so and names the exact model to
  switch to (there is no way to switch a running session's model but
  the human typing `/model`, so the coordinator asks for it
  explicitly rather than staying quiet and letting the stronger
  model keep coordinating by default). This is the same move Fable
  made on 2026-09-26, stepping back to Sonnet once the day's design
  passes were written and only the build-out remained; it should
  happen every time the same condition is true, not only when Jesse
  happens to ask.


## Moved from CLAUDE.md

Verbatim text that used to sit in CLAUDE.md; CLAUDE.md now carries a one-rule summary of each item and points here.

### Roles: coordinator and coder (preamble and bullets)

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
- **Codex lanes run in named tmux sessions the coordinator starts and restarts (owner's rule, 2026-10-08, replaces "every Codex session is visible").** No terminal window has to be open; tmux keeps the lane alive. Never a hidden process outside tmux. The Lanes panel shows each lane's state; Jesse can attach to any lane at any time. After a reboot the coordinator rebuilds the lanes.
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

### Model floor: escalation paragraph

The floor is a minimum, not a default: use the cheapest lane and model that clears it (Codex, local model, Claude agent; Haiku, Sonnet, Opus, Fable).
**Escalate judgment, not workload.** Do not escalate because an item is large, spans many files or has taken long. Escalate when the
remaining blocker needs materially better reasoning: competing plausible designs, unresolved contradictory evidence, a subtle root cause
after verified attempts, a high-consequence judgment, or low confidence in a decision no check can verify. Mechanically verifiable work
stays cheap even when it is big. Opus is consulted, not coordinating: send it one bounded question (compare A, B and C against these
constraints; do not implement; return a recommendation, reasoning, risks and confidence) with the minimum relevant context, and keep the
session on Sonnet. Fable costs several times Opus per task: spend it only where the table says.
Label and co-author lines are hints, not proof. A model change fixes only a reasoning failure: context exhaustion gets a handoff,
an environment blocker gets fixed, an unclear requirement gets a decision, a stalled top model gets the item re-scoped.

### Git workflow: review before committing code

- **Review before committing code** (not docs): the `code-review` skill on the exact diff, passing an explicit target in a worktree and
  confirming the reported path is yours (hook: `require-review-before-commit.sh`). Level `low` by default; `medium` needs a named reason
  (a route, guard, wire shape, auth or safety); `high` only if the coordinator names it. One pass per commit; re-review fix hunks only; never a third pass.
  Start the review while the gate runs. Never review vendored code. The done report states level, pass count, wall time and each finding's disposition.

### Git workflow: clean up old things

- **Clean up old things the moment you find them (owner's rule, 2026-10-03).** A merged or abandoned branch, a finished worktree, a dead
  file, a stale script, code nothing calls, a superseded doc, a leftover claim, lock or tmux session: remove it in the same session you notice
  it, or file a backlog item with the evidence if removing it is not yours to do. Look before deleting: it is yours or provably dead (merged into
  `main`, no live reference, no uncommitted work, no running process), and the report names what went and why. Anything that may be another
  session's or Jesse's data (a branch with unmerged commits, a data folder, a dirty worktree) is listed with evidence, never deleted unseen.
  Code removal follows port-before-delete. Nothing "old" is kept for comfort.

### Architect gate: why

Why: sessions wrote decision records without checking earlier ones, and 22 contradictions built up in Home's docs.

### Verification (definition of done): bullets

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
