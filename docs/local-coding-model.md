# The local coding model: what it is good for, and what it is not

## The setup

The model is Qwen3.8-27B, an open model released in August 2026. All 27
billion of its parameters work on every word it writes, which is what
separates it from the small "mixture" models we tried first, where only a
few billion are active at a time and the results showed it.

It runs on a laptop with one consumer graphics card through llama.cpp,
compressed to about 3.5 bits per weight (a 10 GB file; its makers'
tests show almost no loss at that size), with a working window of 48,000
tokens and speculative decoding on, which gives about 30 tokens a second.
An open coding agent drives it: it reads files, edits them, runs commands
and commits. Nothing leaves the house.

## How it compares to Claude Sonnet

We gave the model and Sonnet the same tasks, from the same starting point,
with the same written instructions, and read both results line by line.

| Task | Accuracy against Sonnet | Time against Sonnet |
|---|---|---|
| Small and precise: one or two files, the rules spelled out, the tests named, the commands given with their directory | Equal. The same code, the checks run as told, an honest report, a commit. | About 2.5 times longer (three minutes against one). |
| Medium: read four files, design one shared piece, change all four without altering behavior, write tests | Equal, after one wrong turn it caught itself from a failing test. | About 2 times longer (nineteen minutes against ten). |
| The same medium task with a 32,000-token window instead of 48,000 | Failed outright: it ran out of room reading before it wrote a line. | Not applicable. |

In short: Sonnet-quality output at about half Sonnet's speed, on work that
fits its window and is written down precisely.

## What it never did in two days

It never found a design flaw on its own. It never questioned an
instruction that was wrong. It never noticed two rules in the same file
interacting. When we gave it a task that needed exactly that, it looped
three times, each round fixing its own tests and breaking older ones,
until we stopped it. That is the boundary: it has Sonnet's hands and none
of a frontier model's judgment.

## How it slips

It drifts on the rules around the code rather than on the code itself:
its own commit message instead of the one it was given, a regeneration
step skipped, a type widened for convenience, a reach past its own
folder. Once, told plainly not to, it merged and pushed its branch. The
agent's permissions now deny every git command except commit, so that
cannot happen again. It also burns its step allowance reading a big file
when the brief names the file rather than the function and the line.

## What it gets, and what it does not

It gets small changes with a precise brief, mechanical refactors, schema
and fixture and test work, and follow-ups where a review has already named
the exact fix. It does not get anything that needs a decision, a diagnosis,
or an understanding of how parts of a system interact.

## The checks

Its own report is not evidence. A person or a Claude model reads the diff,
reruns the checks it named, and compares the commit message to the one
requested. On ten small tasks that reading took about two minutes each and
found a rule slip in three of them; it never found wrong code where the
brief had been precise.

## Why it pays on a paid Claude plan

A paid plan is a weekly budget of tokens, spent fastest when the expensive
model is used for typing. The local model costs nothing per token and
never runs out. The method that makes it work is one Claude model acting
as the manager: it cuts the work into pieces that fit the window, writes
each brief, sends it, reads what comes back, reruns the checks, and decides
what lands. The paid tokens go to thinking; the free ones go to typing. In
one evening that arrangement took ten small tasks off the queue while the
plan stayed available for the work only the paid model can do.

## Conclusion: local versus frontier

A local model on one graphics card now types as well as a frontier model
on well-defined work, at half the speed and at no cost per token. It does
not think as well: it cannot design, diagnose, or catch its own wrong
turns, and it slips on the rules around the code. So the right shape is
not local instead of frontier but local under frontier: a frontier model
plans, briefs and reviews; the local model does the typing it is briefed
for; every result is checked before it lands. Used that way, the local
model is a real second pair of hands, and the paid plan lasts the week.
