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
  documented publicly; they are a feature, not a liability. The one named
  exception is the teen setting in the output-gate bullet below, which
  picks between two modes that are both checked; the child's mode and
  everything for a child stays absolute.
- **Child profiles are restricted by default.** Unrestricted generation and
  chat are unlocked per-user by an adult, never inherited, never the default
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
  finished-item check and the same absolute lines; every other child
  protection stays non-removable.
- **One set of content protections per person, by age, for everything Home
  makes** (owner's ruling, 2026-10-18): chat, search, pictures, videos and
  songs read the same definition (swearing, drugs, gambling, gore and the
  rest), so a person with a filter on gets none of it in a reply, a song, a
  picture or a video, including a picture of themselves and friends doing it.
  Nothing sexual involving a minor is allowed anywhere, and that is not
  negotiable. Sexual content, gore and other adult content are adult only.
- Real people in generated pictures, videos and songs (owner's ruling,
  2026-10-18, replacing the 2026-10-17 consent exception): anyone in the
  household may make pictures, videos, songs and saved styles with or of any
  household member, as a household option that is on by default. A photo of a
  real person is never turned into adult content, and nothing sexual involving
  a minor is ever made. Public figures and anyone outside the household stay
  refused. Per-person agreement and notices were removed on purpose and can be
  added back later. Home's `docs/design/likeness-consent-2026-10-17.md` is the
  earlier design, now superseded where it differs.

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
  architecture, not a setting: no admin switch, flag or mode may send a
  child a reasoning stream.
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
  weight-loss coaching) and the crisis overlay are the same for every minor
  and no setting or override reaches them; a safety emergency is always answered with
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
