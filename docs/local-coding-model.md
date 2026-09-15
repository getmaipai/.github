THE LOCAL CODING MODEL: WHAT IT IS GOOD FOR, AND WHAT IT IS NOT

The model and how we run it

The model is Qwen3.8-27B, an open model released in August 2026. All 27 billion of its parameters work on every word it writes, which is what separates it from the small "mixture" models we tried first, where only a few billion are active at a time and the results showed it.

We run it through llama.cpp using the ISTA-DASLab GSQ/RCO quantizations, which assign a different precision to each tensor under a size budget. Two files matter: IQ3_XXS at about 3.0 bits per weight (about 10.1 GB) and IQ3_S at about 3.5 bits (11.8 GB); the lab's own tests show near-lossless coding and math scores at those sizes. Each comes in a version with the multi-token-prediction head built in (the file name ends in -mtp.gguf, about 0.35 GB larger); that head is what makes speculative decoding work, and the plain file cannot do it. Our measured runs used Qwen3.8-27B-GSQ-RCO-IQ3_XXS-mtp.gguf. An open coding agent drives the model: it reads files, edits them, runs commands and commits. Nothing leaves the house.

What it needs, as we measured it

These figures are for our settings (an 8-bit key-value cache, speculative decoding on, one request slot) and move with them; a 4-bit cache roughly halves the cache's memory at some cost to accuracy on long tool loops, and a different backend or quantization changes the numbers. With those settings, the IQ3_XXS model split across two 8 GB cards fits a 48,000-token window with about half a gigabyte of headroom on each card; a single 16 GB card holds the IQ3_S model with a 64,000-token window; a 24 GB card holds a 4-bit build with a full window and room beside it.

Speed is set mostly by the card's memory bandwidth, because generating each token reads the whole model, but it is not a formula: the speculative-decoding acceptance rate (71 percent on our prompts at short context, 65 percent at long), the quantization's kernels, the backend and prompt processing all move it. Our measurement, for the record: on two 448 GB/s cards split over a Thunderbolt link, 31 tokens a second at a 5,000-token prompt and 26 at 25,000 with speculative decoding, 18 and 16 without it; owners of a single 16 GB card at the same bandwidth report 50 to 55 with it. A card with twice the bandwidth will be faster, not exactly twice as fast.

Hardware limits versus model limits

Better hardware buys two things: speed and window. Both matter: with a 32,000-token window the medium task below failed outright, and with 48,000 it passed, so a card that allows 64,000 turns more tasks from fails into passes. What better hardware does not buy is judgment: the model's failures to design, diagnose, or catch its own wrong turns did not change between the two-card and the larger-window runs.

One caveat on that judgment claim, and it is ours to settle, not the hardware's: every agent run below was made with the model's thinking turned off. We turned it off because the model ships with its reasoning effort at the highest of its three trained levels and, on its first agent run, spent its entire output budget thinking before touching a file; its makers and early users report the same. The documented fix is a lower effort level set at the server (low or medium), not off. Our first attempt set the level from the agent side, where it never reached the server, so we went to off. We have not yet measured the agent loop at low or medium effort; until we do, part of the judgment gap may be a setting we chose, and the next measurement is the same failed judgment task at medium effort against thinking off.

How it compares to Claude Sonnet, and to Haiku

We gave the model and Sonnet the same tasks, from the same starting point, with the same written instructions, and read both results line by line.

On a small, precise task (one or two files, the rules spelled out, the tests named, the commands given with their directory) it produced the same code Sonnet did, ran the checks as told, reported honestly and committed. Equal accuracy, two and a half times slower: three minutes against Sonnet's one.

On a medium task (read four files, design one shared piece, change all four without altering behavior, write tests) it matched Sonnet's output after one wrong turn it caught from a failing test. Equal accuracy, twice as slow: nineteen minutes against ten. The same task with a 32,000-token window failed outright; it ran out of room reading before it wrote a line.

Against Haiku we have no side-by-side run, only the tiers we already assign each: Haiku takes one clear change with a mechanical check and nothing larger. On that scale the local model sits above Haiku and below Sonnet. It handles the multi-file, test-writing work Haiku is not trusted with, and it lacks the judgment Sonnet brings to an ambiguous brief. Its typing is Sonnet's; its judgment is nearer Haiku's.

What it never did in two days

It never found a design flaw on its own. It never questioned an instruction that was wrong. It never noticed two rules in the same file interacting. Given a task that needed exactly that, it looped three times, each round fixing its own tests and breaking older ones, until we stopped it.

How it slips

It drifts on the rules around the code rather than on the code: its own commit message instead of the one given, a regeneration step skipped, a type widened for convenience, a reach past its own folder. It has reported "all tests pass" with one test failing. Once, told plainly not to, it merged and pushed its branch; the agent's permissions now deny every git command except commit, so that cannot recur. It also burns its step allowance reading a big file when the brief names the file instead of the function and the line.

The configuration that produced these results

The model server: llama.cpp, a build from May 2026 or later (when speculative decoding for this model family landed); the -mtp.gguf file; all layers on the card; flash attention on; the key-value cache at 8-bit for keys and values; the window at 48,000 or more; speculative decoding with the flag --spec-type draft-mtp and up to three draft tokens; the model's thinking off at the server (or, the untested alternative, --reasoning-effort medium); the chat template enabled so tool calls work; one slot; the server's prompt cache on. On two cards, a layer split weighted so neither card sits within half a gigabyte of its limit; a card driven that close dropped off the bus once.

The coding agent (OpenCode, pointed at the server's OpenAI-style API): the sampling from the model's own card (temperature 1.0, top-p 0.95, top-k 20, no minimum-p, no repetition penalty); the context limit set to the server's window and the output limit to 8,000; request timeouts of twenty minutes, since one agent turn can legitimately run that long; a step cap of 100 per brief (the default of 40 is too low for anything beyond a one-file change; Sonnet itself used 86 tool calls on the medium task) with the loop guard on; the agent's to-do and ask-the-user tools off (it asked for confirmation despite being told not to); edits, reads and commands allowed inside its folder; every git command denied except commit; one brief per fresh session (a session carrying earlier briefs fills the window and the model compacts away the instructions it needs most, which is how commit steps get lost); and, for unattended runs, the agent's input closed, because a run started with an open terminal input hangs waiting on it.

What it gets, and what it does not

It gets small changes with a precise brief, mechanical refactors, schema and fixture and test work, and follow-ups where a review has already named the exact fix. It does not get anything that needs a decision, a diagnosis, or an understanding of how parts of a system interact.

A brief that works

The shape below produced the equal-to-Sonnet results; everything the model would otherwise have to decide is decided for it. Task: one sentence saying what is wrong and what right looks like. You are in this folder on this branch; every command runs from there. Files you touch, exactly these: the list. The change: numbered rules, each naming the function and the line it touches and what the new behavior is. Tests: the file to add to, the existing test to mirror, the cases by behavior. Verify, in this order, from this directory: the exact commands. Commit only if every check passes, with this exact message: the text. Do not push. Do not ask questions; state an assumption in one line and continue. Report at the end: the files, the check results with counts, the hash.

What breaks it: "look at the module and fix the routing" (no file, no rule), a brief that spans two subsystems, or one that asks it to decide between approaches.

The checks

Its own report is not evidence. The manager reads the diff, reruns the checks it named, and compares the commit message to the one requested. On ten small tasks that took about two minutes each and found a rule slip in three; it never found wrong code where the brief had been precise.

Why it pays on a paid Claude plan, and which model manages it

A paid plan is a weekly budget of tokens, spent fastest when the expensive model is used for typing. The local model costs nothing per token and never runs out. The arrangement: a top-tier Claude model, Opus 5, is the manager. It reads the design, cuts the work into pieces that fit the window, writes each brief in the shape above, sends it, reads what comes back, reruns the checks, reviews the batch before it lands, and decides what goes back. Sonnet can review a small piece; the design reading and the cutting are Opus work, because a wrong cut wastes the local model's whole run. The paid tokens go to thinking; the free ones go to typing. In one evening that took ten small tasks off the queue while the plan stayed available for the work only the paid model can do.

Conclusion: local versus frontier

A local model on one graphics card now types as well as a frontier model on well-defined work, at half the speed, at no cost per token; better hardware makes it faster and lets it hold bigger tasks, not smarter. It cannot design, diagnose, or catch its own wrong turns (with the caveat above about thinking), and it slips on the rules around the code. So the right shape is not local instead of frontier but local under frontier: Opus plans, briefs and reviews; the local model does the typing it was briefed for; every result is checked before it lands. Used that way it is a real second pair of hands, and the paid plan lasts the week.
