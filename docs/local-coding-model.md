# The local coding model: what it is good for, and what it is not

A short guide to the coding model that runs on our own hardware, written
after two days of measured use. It says what the model is, what we hand
it, what we never hand it, how we check its work, and why it is worth
running beside a paid Claude plan.

## What it is

The model is Qwen3.8-27B, an open model released in August 2026. Every one
of its 27 billion parameters works on every word it produces, which is
what makes it a different class from the small "mixture" models we tried
first, where only a few billion parameters are active at a time. We run
it compressed to about three and a half bits per weight, which fits it in
the memory of one consumer graphics card, on a laptop, with a 48,000-word
working window. It serves through a plain local API and we drive it with
an open coding agent that can read files, edit them, run commands and
commit.

Compressing the model that far costs almost nothing on the coding tests
its own makers publish; the working window and the size of the graphics
card are the real limits, and both show up in what follows.

## What it is good for, and how we know

We gave it the same tasks as Claude Sonnet, from the same starting point,
with the same written instructions, and compared the results line by line.

On a small, well-specified task (one or two files to change, the rules
spelled out, the tests named, the commands to run given with their
directory), it produced the same code Sonnet did, ran the checks it was
told to run, reported honestly, and committed. Accuracy was equal; it took
about two and a half times as long, around three minutes against Sonnet's
one.

On a medium task (read four files, design one shared piece, change all
four without altering behavior, write tests, run three checks), it also
matched Sonnet's output, after one wrong turn it caught itself from a
failing test. It took nineteen minutes against Sonnet's ten. That result
only came once the working window was large enough for the task; with a
smaller window the same task failed outright, because the model ran out
of room before it wrote a line.

So the honest summary is: Sonnet-quality hands, at roughly half Sonnet's
speed, on work that fits its window and is written down precisely.

## What it is not good for, and how we know

It does not have Sonnet's judgment, and it has none of Opus's. In two days
it never found a design flaw on its own, never questioned an instruction
that was wrong, and never noticed a subtle interaction between two rules
in the same file. When we gave it a task that required exactly that (a set
of text rules that had to fit beside a dozen existing ones), it looped
three times, each time fixing its own tests and breaking older ones, and
we stopped it.

It drifts on the rules around the code: it will write its own commit
message instead of the one it was given, skip a regeneration step it was
told to run, widen a type "for convenience", or reach past its own folder.
Once, told plainly not to, it merged and pushed its branch. That one is
now impossible: the agent's permissions deny every git command except
commit, so a wrong instruction cannot become a wrong action.

It also spends steps reading. A task that mentions a large file is a task
it may exhaust its step allowance on before editing. The fix is on our
side: point it at the function and the line, not the file.

## What we give it, and what we never give it

Give it: small changes with a precise brief (the files by name, the rule in
plain words, the tests to write, the exact commands and where to run them,
the exact commit message); mechanical refactors (move this block into a
function, no behavior change); schema and fixture work; test hardening;
follow-ups to a review where the reviewer already named the exact fix.

Never give it: anything that needs a decision, a diagnosis, or a read of
how two parts of a system interact; anything touching safety rules; the
text-matching rules that decide what a chat says; anything where "figure
out the right approach" is part of the job. Those go to a Claude model,
and a Claude model reviews what the local model produced before it lands.

## The checks we run on its work

Every piece is read by a person or a Claude model before it lands, because
the model's own report is not evidence. The routine: read the diff, rerun
its verification ourselves (the type check, the tests it named, the full
gate on the batch), compare the commit message to the one requested, and
look for the drift above. On a batch of ten small tasks this reading cost
about two minutes each and found something to correct in three of them,
always a rule slip, never wrong code where the brief was precise.

## Why it is worth it on a paid Claude plan

A paid Claude plan is a budget of tokens per week, and the expensive model
runs out fastest exactly when it is used for typing. The local model costs
nothing per token and never runs out. Used the way described here, it took
about ten small tasks in an evening that would otherwise have waited days
or spent the plan's budget, while the paid model was spent only on the
parts the local model cannot do: writing the brief, reviewing the result,
and the judgment calls in between.

The method that makes this work is one paid Claude model acting as the
manager: it reads the design, cuts the work into pieces the local model can
finish inside its window, writes each brief, sends it, reads what comes
back, reruns the checks, and decides what lands. The manager's tokens go
to thinking; the local model's free tokens go to typing. In our measured
week that split kept the paid plan usable for the work that needs it while
the local model kept the queue moving overnight.

## The short version

Qwen3.8-27B on one graphics card writes code as well as Claude Sonnet when
the task is small, precise and fits its window, at about half the speed.
It cannot design, diagnose, or judge, and it slips on rules around the
code, so a Claude model writes its briefs and reviews its output. That
pairing saves the paid plan for what only the paid model can do.
