# The local coding model: what it is good for, and what it is not

**What it is.** Qwen3.8-27B, an open model from August 2026, compressed
to about three and a half bits so it fits one consumer graphics card on a
laptop, with a 48,000-word working window. It runs through an open coding
agent that reads, edits, runs commands and commits.

**What we measured.** The same tasks, from the same starting point, with
the same written instructions, to it and to Claude Sonnet, read line by
line afterward.

- A small, precise task (one or two files, the rules spelled out, the
  tests named, the commands given with their directory): the same code
  Sonnet wrote, the checks run as told, an honest report, a commit.
  Equal accuracy, about two and a half times the time (three minutes
  against one).
- A medium task (read four files, design one shared piece, change all
  four without altering behavior, write tests): the same output as
  Sonnet, after one wrong turn it caught from a failing test. Nineteen
  minutes against ten. With a smaller working window the same task
  failed outright: it ran out of room before writing a line.

**What it never did in two days.** It never found a design flaw on its
own, never questioned a wrong instruction, never noticed two rules in one
file interacting. Given a task that needed exactly that, it looped three
times, fixing its own tests and breaking older ones, until we stopped it.

**How it slips.** It drifts on the rules around the code: its own commit
message instead of the one given, a regeneration step skipped, a type
widened for convenience, a reach past its own folder. Once, told plainly
not to, it merged and pushed. The agent's permissions now deny every git
command except commit, so that cannot recur. It also spends its step
allowance reading a large file when the brief names the file instead of
the line.

**So: what it gets.** Small changes with a precise brief; mechanical
refactors; schema, fixture and test work; a review's follow-ups where the
exact fix is already named. **What it does not get:** anything that needs
a decision, a diagnosis, or an understanding of how parts interact.

**The checks.** Its report is not evidence. A person or a Claude model
reads the diff, reruns the checks, compares the commit message to the one
asked for. On ten small tasks that cost about two minutes each and found a
rule slip in three; never wrong code where the brief was precise.

**Why it pays on a paid Claude plan.** A plan is a weekly budget, spent
fastest when the expensive model types. The local model costs nothing per
token and never runs out. One Claude model acts as the manager: it cuts the
work into pieces that fit the window, writes each brief, reads what comes
back, reruns the checks, decides what lands. The paid tokens go to
thinking; the free ones go to typing. In one evening that took ten small
tasks off the queue while the plan stayed usable for what only the paid
model can do.
