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
- **Outside data for quality is on by default, with a local option beside it (owner's ruling, 2026-11-01).** Where an outside
  service gives clearly better results (music matching and metadata, artist photos and bios, album art, synced lyrics, and
  the like), Home uses it by default and the text or ids it sends are named on the privacy page, with an off switch. Each of
  these is a request the product makes to serve the person, never telemetry, and never carries a name, address or account of
  the household, nor a child's or teen's free text. In parallel, every such source is paired with a local or offline
  alternative (embedded tags, bundled data, a self-hosted mirror) that an owner can pick for more privacy or to work with no
  internet, and sessions keep looking for more of them. The off switch falls back to the local source, never to a broken feature.
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
- **The household's own SearXNG passes a query's text to public search
  engines (owner's ruling, 2026-10-11).** It carries no identity or
  household data, and a child's or teen's query is checked first for the
  home address, phone numbers, email addresses and household names.
- **The optional ddgs source passes an adult's query text to DuckDuckGo
  (owner's ruling, 2026-10-17).** It is on by default for adults when
  SearXNG could not be set up, and an admin can turn it off. Each search
  is one the person asked for and the model decided to run, so it is not
  phone-home. It never carries a guest's query, and by default never a
  child's or teen's. An owner or admin can opt teens, or teens and
  children, in with `search.ddgs_for_minors` (owner's request, 2026-10-17):
  the setting is off by default and warns that DuckDuckGo's filter is not
  guaranteed. Even then ddgs is a second source beside SearXNG, never the
  only one. The privacy page row shows only while the helper runs and
  DuckDuckGo is picked.
- **Max research mode may read the open web for people who hold the Max
  grant (owner's ruling, 2026-11-01).** Only adults hold the Max grant;
  teens and children get no Max, so this path never runs for them. It
  counts as an allowed search, so it is not phone-home. Each question gets
  a budget: at most 12 searches and 40 pages, 4 pages per site, 3 seconds
  between requests to one site, and a site that answers 403 or 429 is
  skipped for the rest of the question while the other sites are still
  read (`THIRD-PARTY-SERVICES.md`). An admin off switch, the setting
  `research.max_web`, turns it off; off means Max research uses the
  offline reference library only. Page text is read to write the answer
  and is not stored beyond the cited sources kept with that message. A
  query carries only the person's own question text, with no household
  data added. The privacy page row names the setting and shows the state.
- **Style (LoRA) sources: an admin's click sends a search to Hugging Face, and to Civitai only if an admin turned it on (owner's request, 2026-11-02, in chat; design `home/docs/design/video-loras-2026-11-02.md`).** Only an owner or admin triggers these requests, from Settings, Pictures and videos, Styles; nothing runs in the background, refreshes or checks for newer versions. The hub makes the request, never a family member's browser, so no one's browser contacts those sites and no remote picture is hot-linked (the hub fetches a preview once and serves it from its own address). A request carries the words the admin typed, the filters they picked and, for a download, the file address they chose. It carries no household data, no person, no prompt and no companion or chat text. An optional token goes only to its own site: the Hugging Face token the admin already saved (for files that ask them to accept terms), or a Civitai key the admin saved; each is a write-only secret kept in Home, sent to the Stack in the body of one install job, never stored there, never logged, never put in a URL, and dropped on any redirect to another host. Hugging Face is on by default for admins, Civitai is off until an admin turns it on after reading a plain notice, and the privacy page rows (Hugging Face styles, Civitai styles) show only while the source is on. A downloaded style file lives only on the household's own disk; nothing is uploaded. Whether a style is adult is decided from fields the site itself publishes, not from reading words, and an adult or unsure style stays behind the Adult lock.
- **Every product keeps a user-tier privacy page** with the "what leaves the
  house" table: each outbound connection, when it happens, what it carries,
  and who receives it. Plain dad-test language. Adding or changing an
  outbound endpoint updates this page in the same commit, no exceptions
  (this is the docs-with-the-change rule applied to privacy).

MaiPai Stack keeps no privacy page. It publishes its outbound endpoints as rows (`/stack/v1/privacy`: the signed Catalog index checks, the pinned downloads, a provenance read before an install, a voice or its cloning weights fetched once on an explicit need), each saying when it happens, what it carries, who receives it and the setting that governs it, and Home's own page shows those rows in the same table as everything else that leaves the house. Adding or changing a Stack endpoint changes that data in the same commit, which is the docs-with-the-change rule applied to a daemon with no docs of its own.

Owner-approved: 2026-10-07
Owner-approved: 2026-11-01
