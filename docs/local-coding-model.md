# The local coding model: what it is good for, and what it is not

## The model and what it needs to run

The model is Qwen3.8-27B, an open model released in August 2026. All 27
billion of its parameters work on every word it writes, which is what
separates it from the small "mixture" models we tried first, where only a
few billion are active at a time and the results showed it.

We run it through llama.cpp, compressed to about 3.5 bits per weight (a
10 to 12 GB file; its makers' tests show almost no loss at that size),
with speculative decoding on, the model's built-in "thinking" off for
agent work (on, it spends its whole output budget thinking before it
touches a file), and a working window of 48,000 tokens. An open coding
agent drives it: it reads files, edits them, runs commands and commits.
Nothing leaves the house.

What it needs: a graphics card with 16 GB of memory for the model plus a
64,000-token window, or two 8 GB cards with the model split across them
(the split costs about a tenth of the speed and caps the window at
48,000). A 24 GB card runs the 4-bit version with a full window and room
beside it. The card's memory bandwidth sets the speed: about 450 GB/s
gives 30 tokens a second with speculative decoding, 900 GB/s roughly
twice that.

## Hardware limits versus model limits

Better hardware buys two things and only two: speed (bandwidth) and
window (memory). Both matter: with a 32,000-token window the medium task
below failed outright, and with 48,000 it passed, so a card that allows
64,000 turns more tasks from "fails" into "passes". What better hardware
does not buy is judgment. The model's inability to design, diagnose, or
catch its own wrong turns is the model's, and only a stronger model
changes it.

## How it compares to Claude Sonnet, and to Haiku

We gave the model and Sonnet the same tasks, from the same starting point,
with the same written instructions, and read both results line by line.

| Task | Accuracy against Sonnet | Speed against Sonnet |
|---|---|---|
| Small and precise: one or two files, the rules spelled out, the tests named, the commands given with their directory | Equal: the same code, the checks run as told, an honest report, a commit | Two and a half times slower (three minutes against one) |
| Medium: read four files, design one shared piece, change all four without altering behavior, write tests | Equal, after one wrong turn it caught from a failing test | Twice as slow (nineteen minutes against ten) |
| The same medium task with a 32,000-token window | Failed: it ran out of room reading before it wrote a line | Not applicable |

Against Haiku we have no side-by-side run, only the tiers we already use
each for: Haiku takes one clear change with a mechanical check and nothing
larger. On that scale the local model sits above Haiku and below Sonnet:
it handles the multi-file, test-writing work Haiku is not trusted with,
and lacks the judgment Sonnet brings to an ambiguous brief. Its typing is
Sonnet's; its judgment is nearer Haiku's.

## What it never did in two days

It never found a design flaw on its own. It never questioned an
instruction that was wrong. It never noticed two rules in the same file
interacting. Given a task that needed exactly that, it looped three times,
each round fixing its own tests and breaking older ones, until we stopped
it.

## How it slips

It drifts on the rules around the code rather than on the code: its own
commit message instead of the one given, a regeneration step skipped, a
type widened for convenience, a reach past its own folder. Once, told
plainly not to, it merged and pushed its branch. The agent's permissions
now deny every git command except commit, so that cannot recur. It also
burns its step allowance reading a big file when the brief names the file
instead of the function and the line.

## The settings that matter

- Step cap 100 per brief. The default of 40 is too low for anything
  beyond a one-file change: Sonnet itself used 86 tool calls on the
  medium task. A loop guard stays on so a stuck model stops rather than
  repeats.
- Window 48,000 tokens or more, set from the server, with the cache kept
  at 8-bit; a 4-bit cache saves memory and costs accuracy on long tool
  loops.
- Output cap 8,000 tokens, thinking off.
- One brief per fresh session. A session that carries the history of
  earlier briefs fills the window and the model starts compacting away
  the instructions it needs most, which is how commit steps get lost.
- Git limited to commit; the manager does every merge, rebase and push.

## What it gets, and what it does not

It gets small changes with a precise brief, mechanical refactors, schema
and fixture and test work, and follow-ups where a review has already named
the exact fix. It does not get anything that needs a decision, a
diagnosis, or an understanding of how parts of a system interact.

## A brief that works

The shape below produced the "equal to Sonnet" results. Everything the
model would otherwise have to decide is decided for it.

> Task: one sentence saying what is wrong and what right looks like.
> You are in this folder on this branch; every command runs from there.
> Files you touch, exactly these: the list.
> The change: numbered rules, each naming the function and the line it
> touches and what the new behavior is.
> Tests: the file to add to, the existing test to mirror, the cases by
> behavior.
> Verify, in this order, from this directory: the exact commands.
> Commit only if every check passes, with this exact message: the text.
> Do not push. Do not ask questions; state an assumption in one line
> and continue.
> Report at the end: the files, the check results with counts, the hash.

What breaks it: "look at the module and fix the routing" (no file, no
rule), a brief that spans two subsystems, or one that asks it to decide
between approaches.

## The checks

Its own report is not evidence. The manager reads the diff, reruns the
checks it named, and compares the commit message to the one requested. On
ten small tasks that took about two minutes each and found a rule slip in
three; never wrong code where the brief had been precise.

## Why it pays on a paid Claude plan, and which model manages it

A paid plan is a weekly budget of tokens, spent fastest when the
expensive model is used for typing. The local model costs nothing per
token and never runs out. The arrangement: a top-tier Claude model, Opus
5, is the manager. It reads the design, cuts the work into pieces that fit
the window, writes each brief in the shape above, sends it, reads what
comes back, reruns the checks, reviews the batch before it lands, and
decides what goes back. Sonnet can review a small piece; the design
reading and the cutting are Opus work, because a wrong cut wastes the
local model's whole run. The paid tokens go to thinking; the free ones
go to typing. In one evening that took ten small tasks off the queue
while the plan stayed available for the work only the paid model can do.

## Conclusion: local versus frontier

A local model on one graphics card now types as well as a frontier model
on well-defined work, at half the speed, at no cost per token, and better
hardware makes it faster and lets it hold bigger tasks but not smarter.
It cannot design, diagnose, or catch its own wrong turns, and it slips on
the rules around the code. So the right shape is not local instead of
frontier but local under frontier: Opus plans, briefs and reviews; the
local model does the typing it was briefed for; every result is checked
before it lands. Used that way it is a real second pair of hands, and the
paid plan lasts the week.
