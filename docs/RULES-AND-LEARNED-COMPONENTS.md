# Rules, word lists and learned components (2026-09-16)

Referenced from `CLAUDE.md`'s "Rules, word lists and learned components
(2026-09-16)" section. Load this whenever a session
adds or edits a deterministic rule (a regex family, a cue list, a word list)
in a chat or turn pipeline, or is deciding whether something needs a
classifier instead.

From the chat architecture review (`home/docs/plans/
chat-architecture-review-2026-09-16.md`): decisions live in code and
the model writes, and that is right (for whether a turn needs a search
or a tool, the model decides outright: see the 2026-10-02 section
below); the failure mode is a word list
that grows forever and a rule nobody can prove ever fires.

- **No rule without a counter and a row.** A deterministic rule that
  reads the household's words (a regex family, a cue list, a shape) is
  added with a hit counter on the turn's log line and a corpus row that
  fires it. A rule with zero hits over the weekly report is retired in
that week's docs commit, not kept in case.
The first real weekly report (Home, 2026-09-21) had 47 labelled turns
and 55 zero-hit rules, most of them guards for situations that did not
occur that week, so "zero hits" alone is not a retire signal: a rule is
retire-eligible only after consecutive zero-hit weeks past a cumulative
floor of labelled turns (Home's RVW-1b sets both numbers in one place;
until it lands, nothing retires on a single week).
- **Three phrasings in a week is a classifier, not a fourth regex.**
  When a fix adds a third phrasing to the same open-class list
  (emotion, stance, hedges, the lookup field classes) within a week,
  the item is filed as a classifier candidate with the phrasings as
  its first labels; the fourth regex is refused.
- **Labels for a classifier come from people, or from a frontier model
  over roster-based synthetic data only, never over household
  transcripts (egress; owner's ruling 2026-09-22), and never from a
  small local model.** A frontier-labeled set reports its
  disagreement rate against a human-labeled sample; a set labeled by
  the household's own small model is not training data (the ACT-02
  lesson: 4B-labeled acts scored near chance).
- **A learned component never sits in the safety path, the consent
  path or the privacy path.** Those stay deterministic and identical in
  every house; a learned check may run beside them in shadow mode and
  is adopted only when its measured false-positive rate beats the
  rule's.
- **A model judge is a trend line, never a gate.** The persona judge
  and any LLM-as-judge score a bench or a nightly review; none decides
  a live turn.
## No hacky rules: a bad chat is fixed at its root (owner's rule, 2026-09-22)

Why: on 2026-09-22 a day of live chat failures was "fixed" one phrasing
at a time (a capital-letter rule, a pronoun list, a "search *" pattern, a
role-of-place regex), and each fix broke a phrasing nobody tested; the
owner stopped the work and the chat was rebuilt on the accepted design
(`home/docs/plans/simple-turn-pipeline-2026-09-22.md`). These rules keep
the rebuild clean and apply to every product's turn pipeline.

- **Understanding language is the model's job, never a word rule's.**
  No regex, word list or phrase pattern decides what a person means:
  their intent, whether a turn needs a lookup, what to search for, who
  "he" or "it" is, whether an answer repeats one. Code decides only
  closed, exact things: exact commands (matched whole or not at all),
  the safety, consent and privacy floors (deterministic on purpose,
  above), and a counted closed-vocabulary property only when an
  accepted design record names it (superseded in part by the
  2026-10-02 section below, which lists what stays deterministic for a
  chat turn).
- **A failed chat is a replay row and a trace, never a patch.** In
  order: the turn joins the replay set in the owner's exact words and
  fails; the trace names the layer that owns the wrong decision, with
  file and line; the fix changes that layer's design. A change whose
  only effect is to make one phrasing pass is refused in review, by the
  coordinator, and by the gate.
- **Enforced by the gate, not by memory.** The rule-budget lint (U0b)
  counts regex literals and word lists per turn-path file against a
  baseline that only goes down, and drops with each stage of the thin
  chat path that retires a rule; a new rule outside the protected
  modules fails the gate unless its marker names the design record that
  accepted it. The rebuilt default path (`turnMachine/`) starts at zero.
- **Once a design is accepted, the part it replaces is frozen the same
  day.** No patch lands in a pipeline that an accepted design is
  replacing, except a safety defect; everything else waits for, or is
  built into, the new path. The coordinator stops routing such patches
  the day the design is accepted. The accepted design for this rule is
  `home/docs/plans/chat-thin-path-2026-10-02.md`, so its stages may
  change the default path (`turnMachine/`); the path it replaces is
  `turnEngine.ts`, deleted when the new one is ported.
- **Tone is set by the plan line, the companion's own example lines
  and a measured style adapter per companion, not by prose.** A
  paragraph of personality instructions is the weakest lever on a small
  model (the prebuilt-over-hand-built rule, applied to voice).

## The model decides whether a turn needs a search or a tool (owner's rule, 2026-10-02)

No learned lookup head, router or classifier decides whether a turn
needs a search or a tool, any more than a word rule does. Tools are
offered with `tool_choice: "auto"` and the model decides. What stays
deterministic: the safety floor on input and output, the credential
catch, consent words, the household-name gate on search arguments, the
crisis, temporary-mode and grounding refusals, and exact commands,
forget among them. The turn signal is kept for the plan line,
memory-judge eligibility, the wire `signal` event and spoken-cue
suppression; it no longer decides a search. The first rule above ("three
phrasings is a classifier") does not reopen this. Why: a head trained on
phrasings misses the ones nobody labelled, the model reads the whole
message, and a wrong "no search" is silent. The record is
`home/docs/plans/chat-thin-path-2026-10-02.md`; the rules are in
`home/docs/design/RULES.md`.
