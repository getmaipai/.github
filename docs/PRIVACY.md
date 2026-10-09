# Privacy architecture (the promise, kept structurally)

Referenced from `CLAUDE.md`'s "Privacy architecture" section. Load this whenever a session
adds or changes an outbound network connection (an integration, an update
check, a model download).

"Nothing leaves your house" is the product. These rules keep it true:

- **Zero phone-home, ever.** No analytics, telemetry, crash reporting, usage
  pings, or unique identifiers are sent to us or to any third party we
  choose, in any product, under any setting. Local stats stored in the
  user's own database are fine and are not telemetry.
- **No MaiPai-operated service ever sits in a user data path.** No relays,
  proxies, sync servers, or cloud accounts. Org web properties (docs sites,
  the org page) are static and carry no trackers.
- **The household's own engine computer is inside the house (owner's ruling, 2026-10-07).** When Home uses an engine computer the owner paired, chat, pictures and voice travel between the two inside an encrypted, key-authenticated SSH link, over the home network. Only if an admin turns on the household setting "Reach the engine computer when away from home" does the link also use the owner's own Tailscale network, so those requests then cross the internet inside Tailscale's encrypted link; the setting is off by default. Home refuses any address that is neither on the home network nor, with that setting on, in the Tailscale ranges. The privacy page lists the link in the same commit that adds it, as two rows, the second shown only while the setting is on.
- **A person's activity stays theirs.** No user can see what another user
  does in any app; no role grants it; a person may share their own screen or
  hand over their own passcode.
- **Outbound connections are user-serving and transparent.** The app talks
  to the network only to serve the user: update checks, on-demand model and
  dependency downloads, and integrations the user enabled. An integration
  that identifies the user (their YouTube account, their location for
  weather) is opt-in, connects directly from their hub to that service with
  credentials stored locally, and never transits anything of ours.
- **Default-on public reads are allowed (owner's ruling, 2026-10-09).** A
  working hub needs outside data, so it may fetch named public sources by
  default (the RSS news shelf, reference-library updates). Each one carries
  no identifier or household data, polls slowly and politely
  (`THIRD-PARTY-SERVICES.md`), is listed in `/stack/v1/privacy` and the
  settings screen, and has an off switch. Anything that identifies the
  user stays opt-in.
- **An optional hosted search provider is the owner's choice, and the
  query text then leaves the house (owner's ruling, 2026-10-02).** The
  owner brings the provider and its key; it is not MaiPai-operated, and
  nothing of ours sits between the hub and it. It is off by default, its
  key is a write-only secret, and it is never used for a child's or a
  teen's query. The setting says in plain words that the query text
  leaves the house, and the privacy page gains its row in the same
  commit. It carries the owner's own search, so it is not telemetry.
  Search works fully with no key. Why: some owners want a hosted
  index's coverage and accept the trade, but the default must stay
  private and a minor's words must never go.
- **Every product keeps a user-tier privacy page** with the "what leaves the
  house" table: each outbound connection, when it happens, what it carries,
  and who receives it. Plain dad-test language. Adding or changing an
  outbound endpoint updates this page in the same commit, no exceptions
  (this is the docs-with-the-change rule applied to privacy).

MaiPai Stack keeps no privacy page. It publishes its outbound endpoints as rows (`/stack/v1/privacy`: the signed Catalog index checks, the pinned downloads, a provenance read before an install, a voice or its cloning weights fetched once on an explicit need), each saying when it happens, what it carries, who receives it and the setting that governs it, and Home's own page shows those rows in the same table as everything else that leaves the house. Adding or changing a Stack endpoint changes that data in the same commit, which is the docs-with-the-change rule applied to a daemon with no docs of its own.

Owner-approved: 2026-10-07
