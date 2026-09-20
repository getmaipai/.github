# Rules, word lists and learned components (2026-09-16)

Referenced from `CLAUDE.md`'s "Rules, word lists and learned components
(2026-09-16)" section. Load this whenever a session
adds or edits a deterministic rule (a regex family, a cue list, a word list)
in a chat or turn pipeline, or is deciding whether something needs a
classifier instead.

From the chat architecture review (`home/docs/plans/
chat-architecture-review-2026-09-16.md`): decisions live in code and
the model writes, and that is right; the failure mode is a word list
that grows forever and a rule nobody can prove ever fires.

- **No rule without a counter and a row.** A deterministic rule that
  reads the household's words (a regex family, a cue list, a shape) is
  added with a hit counter on the turn's log line and a corpus row that
  fires it. A rule with zero hits over the weekly report is retired in
  that week's docs commit, not kept in case.
- **Three phrasings in a week is a classifier, not a fourth regex.**
  When a fix adds a third phrasing to the same open-class list
  (emotion, stance, hedges, the lookup field classes) within a week,
  the item is filed as a classifier candidate with the phrasings as
  its first labels; the fourth regex is refused.
- **Labels for a classifier come from people or a frontier model,
  never from a small local model.** A frontier-labeled set reports its
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
- **Tone is set by the plan line, the companion's own example lines
  and a measured steering vector per dial, not by prose.** A paragraph
  of personality instructions is the weakest lever on a small model
  (the prebuilt-over-hand-built rule, applied to voice).
