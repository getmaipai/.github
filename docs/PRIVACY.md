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
- **Outbound connections are user-serving and transparent.** The app talks
  to the network only to serve the user: update checks, on-demand model and
  dependency downloads, and integrations the user enabled. An integration
  that identifies the user (their YouTube account, their location for
  weather) is opt-in, connects directly from their hub to that service with
  credentials stored locally, and never transits anything of ours.
- **Every product keeps a user-tier privacy page** with the "what leaves the
  house" table: each outbound connection, when it happens, what it carries,
  and who receives it. Plain dad-test language. Adding or changing an
  outbound endpoint updates this page in the same commit, no exceptions
  (this is the docs-with-the-change rule applied to privacy).

MaiPai Stack keeps no privacy page. It publishes its outbound endpoints as rows (`/stack/v1/privacy`: the signed Catalog index checks, the pinned downloads, a provenance read before an install, a voice or its cloning weights fetched once on an explicit need), each saying when it happens, what it carries, who receives it and the setting that governs it, and Home's own page shows those rows in the same table as everything else that leaves the house. Adding or changing a Stack endpoint changes that data in the same commit, which is the docs-with-the-change rule applied to a daemon with no docs of its own.
