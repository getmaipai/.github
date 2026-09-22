# Safety invariants (generation features)

Referenced from `CLAUDE.md`'s "Safety invariants (generation features)"
section. Load this whenever a session
touches generation, chat, child profiles, or anything gated by an adult
acknowledgment.

MaiPai gives adults full control of their own local AI. Two things are not
controls, they are architecture:

- **Child-safety protections on generation and chat are non-removable.** No
  admin setting, config flag, environment variable, or "advanced mode" may
  disable or weaken them, including for the household's own admin. Code
  review treats any change that makes them bypassable as a correctness bug
  of the highest severity. These protections and their design may be
  documented publicly; they are a feature, not a liability.
- **Child profiles are restricted by default.** Unrestricted generation and
  chat are unlocked per-user by an adult, never inherited, never the default
  for a new profile. Safe-by-default, adult-opt-in.
- No feature is built whose purpose is generating imagery of identifiable
  real people.

Marketing and copy rule (all tiers, all repos): never pitch generation
features as "uncensored", "unfiltered", "no restrictions", or any
filter-bypass framing. The honest pitch is the one we mean: your hardware,
your rules; no cloud company deciding for your family; parents decide what
kids can access.

Adult freedom comes with three standing pieces:

- **AI-outputs disclaimer** in every product README (joining the standard
  disclaimer block) and in the product's first-run: outputs come from
  third-party models the user chooses to download; they can be wrong,
  offensive, or harmful; they are not medical, legal, or professional
  advice; the user is responsible for how they use them.
- **One-time adult acknowledgment to unlock unrestricted mode**: a single
  clear dialog, per adult, stating that unrestricted mode answers without
  filters and that what they do with it is their responsibility. One
  confirmation, no legalese ceremony, never repeated.
- **Crisis resources: offer, never block.** When self-harm intent appears in
  a conversation, the app adds crisis resources (988 and local equivalents)
  alongside the conversation without blocking or censoring what an adult can
  discuss. This overlay is part of the safety architecture: it is not
  configurable off.
- **A model's reasoning is a second output, gated like the first (owner's
  ruling, 2026-09-22).** A thinking stream can hold exactly what the
  answer was built to withhold (how to tell a child that Santa is not
  real, a memory the child may not read), and anything sent to a client
  is visible in it. So: a minor's turn never receives reasoning, because
  the hub does not emit it (never a client-side hide); reasoning passes
  the same output gate and the same disclosure filter as the answer
  before any adult sees it, a recalled memory quoted in the thinking
  included; no voice, glance or shared-screen surface shows reasoning,
  and a shared screen with a child possibly present counts as shared;
  and the turn's record says when reasoning was withheld and why. This is
  architecture, not a setting: no admin switch, flag or mode may send a
  child a reasoning stream.

Neutrality rule: MaiPai ships neutral. No jailbreak presets, no
harm-optimized prompt packs, nothing that curates toward dangerous uses.
Users bring their own models and their own intentions.

Licensing note: no acceptable-use restrictions get added to our license
(added restrictions are incompatible with AGPL-3.0). The README disclaimer
and the models' own licenses carry use responsibility, which rests with the
user.
