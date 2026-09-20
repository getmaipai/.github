# Third-party services: we are the user (hard rules)

Pinned from `CLAUDE.md`'s "Topic docs" index. Load this whenever a session
writes or changes code that fetches from an external service (YouTube,
Reddit, TikTok, Vimeo, Plex, Google, a weather API, or the like).

MaiPai is the family's assistant, so toward YouTube, Reddit, TikTok, Vimeo,
Plex, Google, the weather API and every other service it talks to, **it behaves
as the user would, only automated**. It never behaves like a scraper. YouTube
walled the hub's home IP on 2026-08-28 because the server's own background
fan-out (discovery expansion, suggestion pools, warm-aheads, transcripts) far
exceeded what a person could ever generate; every family member's player was
dark for a day. These rules exist so that never repeats, on any service.

- **A person's pace.** Budget every service to what one engaged human does:
  a page every few seconds, not dozens a second. Every integration gets a
  rate limiter (token bucket) at its single choke point, and all traffic to
  that service goes through it - never a raw fetch on the side.
- **Only what the user asked for, or would see next.** Foreground requests
  serve the screen in front of someone. Background work (warming, expanding,
  building pools, enriching) is bounded, staggered, and stops entirely when
  the service pushes back. No fan-out that multiplies per item (related-of-
  related, all-pages-now, every-thumbnail-now).
- **Prefer the front door.** A signed-in official session (the user's linked
  account, the platform's own feed, its official API with a token) beats
  anonymous scraping every time: it is what the user's own app would do, it is
  rate-limited generously, and it does not get the address flagged. Anonymous
  access is the fallback, never the plan.
- **Back off on the first signal.** A 429, a captcha, a "confirm you're not a
  bot", a LOGIN_REQUIRED where none is expected: stop that class of traffic
  immediately (quiet mode), keep only user-initiated requests, probe on a
  schedule, and resume only when the service is answering normally. Never
  retry through a block.
- **Look like the user's client, honestly.** Real user agents, the client's
  own headers, one identity per household session. No header spoofing tricks
  beyond what the platform's own app sends, no rotating identities, no
  proxies-as-evasion. If a service says no, the answer is to ask less, sign
  in properly, or drop the feature - not to sneak around it.
- **Cache like a client.** Once fetched, keep it (TTL by how fast it changes).
  A refresh is a user action or a slow schedule, never "on every render".
- **Prove it before shipping.** Any feature that adds traffic to a service
  states its request budget in the PR/commit message and is checked against
  the limiter; any block seen in prod is written up (cause, budget, fix) in
  the repo's dev docs so the lesson stays.
