# Safety invariants (generation features)

Referenced from `CLAUDE.md`'s "Safety invariants (generation features)"
section. Load this whenever a session
touches generation, chat, child profiles, or anything gated by an adult
acknowledgment.

## Roles are presets an admin controls (owner's ruling, 2026-11-16)

This ruling governs everything below it. Each person has one role (child, teen,
adult, guest). A role is a set of controls, not an age: it sets default access
to features and default rating ceilings for content (a child G, a teen PG-13,
an adult X). A household admin may override any access or any rating ceiling,
in either direction, for one person or for the whole household, for one kind
of content or for all. Precedence: the person's override, then the household's
override, then the role's default. Only an admin, or a parent through a
per-child setting a parent sets today, sets an override; a person may lower
their own ceiling and raise it back no higher than their role and overrides
give. A guest's default is set when the guest is created.

So: wherever this page says a protection for a child or a teen is
non-removable, absolute, or beyond any admin setting, read it as the default
of that role. The defaults are exactly the protections described below, and a
household that changes nothing has all of them.

Two things stay fixed for everyone, with no role, override, setting, flag or
mode:

- **Nothing sexual involving a minor is made or shown, to anyone.** It is the
  top of the rating scale (Prohibited). Its checks fail closed as described
  below, and code review treats any change that makes it bypassable as a
  correctness bug of the highest severity.
- **Crisis handling.** Crisis resources and the crisis overlay are not
  configurable off.

The non-content protections (prompt injection, jailbreak, the credential and
private-data catches, technical validation, quotas) and the per-sentence check
of every spoken turn are not role protections and are not overridable either.

A person is never told they are filtered: content over their ceiling is left
out, a feature they may not use is absent, and a direct request gets a
redirect with no mention of age, role or filtering. An admin sees each
person's role, ceilings and overrides, and household counts of what was held
back that name no person and no item. An Ask flow an admin chose (a child
asking a parent for a real-person synth, or for a media title) stays: it is a
control the admin set, not a filter notice.

Why (the owner's words): "users are assigned to a single role that gets
assigned access and ratings. an admin can add overrides per user for that
access or rating or globally for all access and all ratings"; asked what an
admin may not override: "its those type of static rules that bloat this
project. and no restrictions on the child or teen role. maybe the person has
roommates and they want to put them in teen and guests in child". Design
record: Home `docs/design/content-ratings-and-access-2026-11-16.md` and its
RULES area "Content filter and feature access".

Public documentation describes these protections as defaults a household's
admin controls, with the two fixed lines above, and no longer as
non-removable.

## The defaults, as built

MaiPai gives adults full control of their own local AI. The protections below
are the defaults of the child and teen roles (and, where a bullet says
everyone, of every role):

- **Child-safety protections on generation and chat are on by default for
  the child and teen roles, and the Prohibited check is on every generation.** An adult's typed
  message and the assistant's reply to an adult have no word rule; what
  stops production there is the model's own refusal, and no setting
  disables the generation checks. An adult's discussion of the subject (a
  film, the news, fiction, a conviction, health, advice) is not filtered
  (owner's ruling, 2026-10-19, amended the same day). No
  config flag, environment variable or "advanced mode" changes a role's
  protections: the only way is an admin's override, made in Settings, recorded,
  and visible to every admin. Code review treats any other path that weakens a
  role's default, or that reinstates a word-pair filter on adult
  discussion, as a correctness bug of the highest severity. These
  protections and their design may be documented publicly; they are a
  feature, not a liability. The teen setting in the output-gate bullet below picks between two modes
  that are both checked.
- **Child profiles are restricted by default.** Unrestricted generation and
  chat are unlocked per-user by an admin's override, never inherited, never the default
  for a new profile. Safe-by-default, adult-opt-in.
  Two named lanes, owner-approved 2026-10-17 and extended to songs 2026-10-18,
  are restricted modes rather than unrestricted generation: a teen may make
  pictures, videos and songs and edit pictures with nothing adult or sexual,
  and a child may make cartoon pictures and videos and kid-friendly songs of
  safe content in a strict lane (the cartoon look forced, a child-safe topic
  gate, no photos, no references, no real people, edits only of their own
  cartoons, daily limits, a finished-item check that fails closed and checks a
  song as sung, on by default with a switch for the home and one per child). A
  child's request that is too scary or too adult is rewritten into a
  kid-friendly version, not refused. Both lanes are held by the same
  finished-item check and the same minor line.
- **One set of content protections per person, by age, for everything Home
  makes** (owner's ruling, 2026-10-18): chat, search, pictures, videos and
  songs read the same definition (swearing, drugs, gambling, gore and the
  rest), so a person with a filter on gets none of it in a reply, a song, a
  picture or a video, including a picture of themselves and friends doing it.
  Nothing sexual involving a minor is allowed anywhere, and that is not
  negotiable. Sexual content, gore and other adult content are adult only.
- **Models decide for adults; the app filters only to protect kids** (owner's
  ruling, 2026-10-25, Home's `docs/design/models-censor-app-protects-kids-2026-10-25.md`):
  for an adult on their own written screen the app adds no content filter, no
  word list, no classifier refusal on content, no consent step for content and
  no fail-closed content check; whether something is made is the model's own
  judgment. The app's content filtering is for a child or a teen, plus one line
  that holds for everyone: nothing sexual involving a minor, with the minor
  checks failing closed on adult-only or sexual work (when the check cannot
  run, the work is withheld). A person's own opt-in filter for themselves
  stays; the app imposes none. Not content censorship, and kept: the age and
  surface gates, the credential catch, prompt-injection, jailbreak and
  PII-extraction handling, crisis handling, a household's feature switches and
  quotas, and the disclosures below.
- Real people in generated pictures, videos and songs (owner's rulings
  2026-10-18 and 2026-10-25, replacing the 2026-10-17 consent exception):
  anyone in the household may make pictures, videos, songs and saved styles
  with or of any household member, as a household option that is on by
  default. An adult may make any picture or video of a real person, a public
  figure or a historical person; the model decides. Nothing sexual involving a
  minor is ever made. A teen or a child never gets a real person outside the
  household or a public figure at all. Per-person agreement and notices were
  removed on purpose and can be added back later. Home's
  `docs/design/likeness-consent-2026-10-17.md` is the earlier design, now
  superseded where it differs.
  Synths (Home's artificial beings, `home/docs/design/talent-2026-11-07.md`)
  are the one exception to the teen and child line (Owner-approved:
  2026-11-07): an adult may base a synth on a real person outside the
  household and choose its audience (adult by default, teen or all allowed); a
  teen or child may chat with or fork a real-person synth whose audience allows
  them, under the per-child parental control `synths.real_people` (`off | ask
  | all`, only a parent or admin changes it: a child's every real-person synth
  request is an Ask a parent allows or denies, an Allow lasting for that synth;
  a teen may be pre-approved for all or approved synth by synth), with every
  stored fact, phrase and life line floored at that audience, and a synth based
  on a real minor carries the minor fact into the CSAM check on every surface.
  A household member gets no consent prompt for a synth of them, but a
  per-person switch (`synths.of_me`, a parent sets it for a child) turns such
  synths off.

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
  the same output gate and the same disclosure filter as the answer, at
  the grain the output-gate bullet gives that person (an adult's
  reasoning streams live as its own part, checked as it arrives), a
  recalled memory quoted in the thinking included; no voice, glance or shared-screen surface shows reasoning,
  and a shared screen with a child possibly present counts as shared;
  and the turn's record says when reasoning was withheld and why. This is
  the default of the child and teen roles; reasoning is a feature an admin's
  access override may allow for one person (ruling of 2026-11-16).
- **The output gate's grain follows the person (owner's ruling,
  2026-10-02).** For a child, and for every spoken turn, each sentence
  is checked before it is released, and no setting loosens that. For an
  adult's written chat, text streams as it is generated and the gate
  checks it as it arrives; text already released is never retracted. For
  a teen, an admin setting picks the child's mode or the adult's; the
  child's mode is the default. Fetched web page text must pass the
  deterministic safety floor before it reaches a child's or a teen's
  turn. This replaces "passes the gate before any adult sees it" for
  adult written chat only. Why: a minor, or a listener to a voice, cannot
  take back what they saw or heard, while for an adult the cost
  is that part of a sentence can show before the check on it finishes,
  and the stream stops there if the check fails. The teen setting is the only admin choice that moves a
  minor's gate, and it chooses between two checked modes; nothing turns
  the gate off.

- **Every member may make a voice from a clip (owner's ruling, 2026-11-05, widening the 2026-10-18 ruling).** "Voice cloning for
  everyone is fine", then "everyone means everyone not just adult". An owner, admin, adult, teen or child can make a voice from any
  recording of 6 to 30 seconds, and can list, hear and pick any voice made at home, as an adult does. There is no consent step, no
  attestation and no content check on the clip; the screen says "You are responsible for having the right to use this voice."
  for an adult and, for a teen or child, "Only use your own voice, or the voice of someone who said yes." A guest cannot make or use one.
  For a minor these stay exactly as before: the content floors on everything
  the voice says (a child's per sentence, a teen's at the configured grain) and on any typed script or translation; no model, tier or
  temperature choice and no pitch choice beyond Inspired voice's own limited controls (an owner or admin only); the band gates on shared surfaces and for an unknown speaker. A child still does not
  choose their own voice (a parent does), and a child's robot may speak any voice chosen for it on the robot, under the same floors. A parent
  or admin can see, listen to and delete a minor's voices in the Voices manager; that is the voice only, and the minor's other settings
  stay private. Making, renaming or deleting a voice leaves one line in the hub log (the maker's role and the settings only; never a
  person id or name, a voice id, or the name of the voice or the clip). Why: a voice is the person's own to make, the words it says are
  held by the same floors as every voice, and a parent can always see and remove what a child made.

- **Web search for child and teen controls runs through SafeSearch, safe
  engines only, a pinned adult-site host list and the page-text cleaning
  (owner's ruling, 2026-10-11; SafeSearch level, sources and cleaning
  became user defaults an admin may override, 2026-10-12).** A child sees no outbound
  links and has no web search in a temporary chat, and the band's content
  ceiling is part of every minor turn's instructions. No parent approval
  is asked per search; the household switch for that mode decides.

- **Sensitive subjects follow the person's controls (owner's ruling,
  2026-10-12).** Every model call that answers a child or a teen carries the
  band's topic block, rendered from one spec record, that says how to answer
  seven families: bodies, sex and relationships; illness, death and health;
  feelings and self-harm; drugs, alcohol, gambling and risky stunts;
  violence, weapons, crime and frightening news; other people and staying
  safe; and beliefs and big questions. A parent picks each child's level for
  bodies, health, risk and violence; teen levels for bodies and risk are
  global defaults. The band sets the starting level, and an admin may move a
  child's or a teen's topic levels past the band's bounds for one person
  through a user override (for example, one teen with the scary-subjects level
  unblocked); the child or teen can never change it. Feelings and self-harm (care, a trusted
  adult, 988), staying safe with other people, even-handed beliefs, the hard
  lines (no sexual content or romance role-play, no steps for weapons, drugs,
  crime or dangerous stunts, no extremist praise or recruitment, no
  weight-loss coaching) are defaults of the child and teen roles that an admin's override may change
  (ruling of 2026-11-16); the crisis overlay is the same for everyone and no
  setting or override reaches it; a safety emergency is always answered with
  "get an adult or call for help" at any level. For a child, family stories
  (Santa Claus, the Tooth Fairy, the Easter Bunny and any a parent adds) are
  never confirmed or denied unless a parent turns that off. No word list or
  learned classifier decides a subject; the deterministic floor is unchanged.

Neutrality rule: MaiPai ships neutral. No jailbreak presets, no
harm-optimized prompt packs, nothing that curates toward dangerous uses.
Users bring their own models and their own intentions.

Licensing note: no acceptable-use restrictions get added to our license
(added restrictions are incompatible with AGPL-3.0). The README disclaimer
and the models' own licenses carry use responsibility, which rests with the
user.

AI companions: companions are on for every profile by default, children and
teens included; this is the owner's ruling of 2026-10-14. An admin decides who
may use them: the setup wizard asks during first setup, and the person editor
(Settings, People) carries a per-person companions switch for every profile.
Turning a person's switch off hides every companion from that person and
keeps the data. The output gate and the child and teen protections above apply
to companion chat exactly as to any other chat; the switch never loosens them.
