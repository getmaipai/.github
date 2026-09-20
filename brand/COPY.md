# MaiPai canonical copy

The one source for product descriptions. Repo description fields, the org
profile, READMEs, and docs pitches all use these, word for word. Change them
here first.

The formula: one sentence, bottom line up front. Only the home description
carries the "- for protection, privacy, and independence" closer; suffixes
are not repeated across products.

**Org (getmaipai):**
Your own AI at home, a robot companion, and apps to reach them anywhere, all on your own hardware, never the cloud.

**stack, repo description (one sentence, at most 120 characters, the GitHub field):**
The headless engine layer under MaiPai Home: local AI engines and models, installed, sized, run, watched and updated.

**stack (MaiPai Stack):**
MaiPai Stack is the engine foundation of MaiPai Home: the headless service that installs, sizes, runs, watches, updates and tests the engines and models behind Home, and gives Home one stable address by role. It has no interface and no users of its own; Home is its only caller.

**stack, the why paragraph** (READMEs and dev docs copy this word for word, under the one-liner):
Local AI is a pile of parts. One program runs the chat model, a different one turns speech into text, another turns text into speech, a small model listens for the wake word, and a fourth draws pictures. Each starts its own way, keeps its own files, needs its own slice of memory and breaks in its own way. Home should never have to know any of that. The Stack is the one interface between those raw parts and everything MaiPai builds on top: Home asks for "chat" or "say this" at one address and gets an answer, and the Stack decides which engine runs it, makes sure the right model file is there and untampered, keeps every engine fitting in memory at the same time, notices when one breaks and says how to fix it, and swaps a new build in, or back out, without Home changing a line. Swap an engine, add a role, move from the Mac to the robot's Linux box: Home does not change. Without the Stack, every product would carry its own copy of all that, and a kid asking for a picture could crash the family's chat.

**stack, the install sentence** (said once, plainly, wherever a reader might look for an installer):
Home's installer installs the Stack; a person never installs the Stack by itself.

**commons, repo description (one sentence, at most 120 characters, the GitHub field):**
MaiPai Commons: the org's libraries (ui, core, spec) every MaiPai product imports, pinned by tag.

**home (MaiPai Home):**
Your own AI, music, videos, podcasts, maps, books, and more, on your own
hardware, online or offline - for protection, privacy, and independence.

**catalog (MaiPai Catalog):**
New features and abilities for your Home and Bot, from one catalog: plugins, apps, companions and integrations, every one reviewed and signed.

**go (MaiPai Go):**
iPhone and Apple TV app for your MaiPai Home and Bot: your own AI, media, and robot companion, wherever you are.

**desktop (MaiPai Desktop, part of the home repo):**
Mac and Windows app for your MaiPai Home and Bot, right on your desktop, integrated with your dock and your computer.

**bot (MaiPai Bot):**
A robot friend with its own onboard AI: it sees, hears, talks, thinks, moves, self-charges, and guards your home in sentry mode. It recognizes each person by face and voice, keeps its own memories of people, facts, and experiences, and learns and evolves with your family.
