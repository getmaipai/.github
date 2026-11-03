# Third-party services: we are the user (hard rules)

Referenced from `CLAUDE.md`'s "Third-party services: we are the user"
section. Load this whenever a session
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
  related, all-pages-now, every-thumbnail-now). A search reading its
  own few result pages is bounded by the budget below, not fan-out.
- **Prefer the front door.** A signed-in official session (the user's linked
  account, the platform's own feed, its official API with a token) beats
  anonymous scraping every time: it is what the user's own app would do, it is
  rate-limited generously, and it does not get the address flagged. Anonymous
  access is the fallback, never the plan. The exception is web search
  (owner's ruling, 2026-10-02): keyless search through the household's
  own SearXNG is the default path, not a fallback, and a hosted provider
  is an optional key (PRIVACY.md). An optional ddgs sidecar is a second
  keyless source (owner's ruling, 2026-10-11): adults only, one fixed
  browser identity, no rotation, no proxies, through the limiter with
  back-off. It is on by default for adults when the household's SearXNG
  could not be set up (owner's ruling, 2026-10-17, in chat, reversing the
  2026-10-11 "off by default"); the age and surface gates are unchanged.
  An admin can turn it off under Settings, Search, Web search sources.
  It stays closed for teens and children unless an owner or admin turns on
  `search.ddgs_for_minors` (Settings, Search, Web search; owner's request,
  2026-10-17, in chat). That setting is off by default and says plainly that
  DuckDuckGo's own filter is not guaranteed and the ddgs text search may
  ignore the strict safe-search request Home sends, so adult results may reach
  that age group. When on, ddgs is only a second source beside SearXNG, never
  the sole source, never on a spoken turn, never for a guest, and every other
  gate (the band's web switch, blocklists, page cleaning, output gate) stays.
- **Back off on the first signal.** A 429, a captcha, a "confirm you're not a
  bot", a LOGIN_REQUIRED where none is expected: stop that class of traffic
  immediately (quiet mode), keep only user-initiated requests, probe on a
  schedule, and resume only when the service is answering normally. Never
  retry through a block.
- **A search may read several result pages, inside a stated budget
  (owner's ruling, 2026-10-02).** Chat answers from page text, not
  snippets, so one search may fetch a few of its result pages. The
  budget is a cap on pages per search, the per-host pace above kept for
  every fetch, and a back-off on the first signal from any host. Why:
  an answer grounded in the pages is the point of the search, and a
  fixed cap keeps it a person's few tabs, never a crawl.
- **Max research mode may fetch from the open web, inside a fixed budget
  (owner's ruling, 2026-11-01).** It runs only for people who hold the Max
  grant (adults; teens and children get no Max), as an allowed search that
  reads result pages for the answer. Per question: at most 12 searches and
  40 pages, at most 4 pages from any one site, and 3 seconds between
  requests to one site. The first 403, 429 or robots.txt refusal from a site stops all requests
  to that site for the rest of the question, with no retry through it; the
  other sites are still read (owner's second answer, 2026-11-01). An
  admin can switch it off with `research.max_web`; off means the offline
  reference library only. Page text is read for the answer and is not
  stored beyond the cited sources kept with the message. Queries carry only
  the person's own question text, with no household data added. Why: deep
  research needs more pages than an ordinary search, and a fixed budget
  keeps it a person's open tabs, never a crawl.
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

## Style (LoRA) sources: Hugging Face and Civitai (VIDEO-LORA-DOC-01, 2026-11-02)

Read this before writing `lib/loras/source.ts` in Home or the `video.lora.install` job in the Stack (home `docs/design/video-loras-2026-11-02.md`
sections 5.2, 5.3 and 15). These are model hosts, not live video services, but the same rules apply: a person's pace, only what an admin asked for,
back off on the first signal, honest client, cache like a client.

| | Hugging Face | Civitai |
|---|---|---|
| Default | On for owner and admin | Off until an admin turns it on and reads the notice |
| Hosts allowed | `huggingface.co` (API and `/resolve/` files) and its file CDN hosts | `civitai.com` (API and `/api/download/models/`) and the download host its redirect names |
| Calls | `GET /api/models?filter=lora&search=...` (cursor from the `Link` header), `?blobs=true` for file size and LFS sha256, then the file | `GET /api/v1/models` (`types=LORA`, `baseModels`, `query`, `sort`, `cursor`, `limit`, `nsfw=false` unless an unlocked admin asks for adult results), `GET /api/v1/models/{id}`, then the file |
| Auth | Bearer token only for files that ask for accepted terms, from the existing household secret; sent to `huggingface.co` hosts only | A personal API key the admin saved, as a Bearer header (never a query string), sent to `civitai.com` hosts only |
| Sent | Typed search words, filters, repo and file names | Typed search words, filters, model and version ids |
| Never sent | Household, people, prompts, chat or companion text, any id of ours | Same |
| Documented limit | 500 API calls and 3,000 file requests per 5 minutes per anonymous IP, 1,000 and 5,000 with a free token ([rate limits page](https://huggingface.co/docs/hub/rate-limits), read 2026-11-02); a 429 carries `RateLimit` headers | No published numbers; Cloudflare edge limits and 429 |

**Our budget (the same for both, enforced by one limiter per host at `lib/loras/source.ts`):** one request per 2 seconds per host, at most 60 browse requests per
hour per household, at most one download at a time, a 5-minute cache of search responses (memory only), preview pictures cached 24 hours
and fetched only for results the viewer may see, the lazy Hugging Face `?blobs=true` call only for a repo that is on screen (one per repo, cached),
at most 1,000 results deep. The first 429, 5xx or sign-in demand stops that host for 1 minute, doubling to 30 minutes, for user-initiated requests only.
Nothing runs in the background and nothing checks for newer versions; "Check for a newer version" is a button. A 4 GB cap, HTTPS only, and a redirect to any host outside
the allow list is refused. The client sends one honest user agent that names MaiPai Home and its version, with no rotation.

**Terms.** The Hugging Face rate limits above were read on 2026-11-02; its Terms of Service were not read in this slice and need a person's read before release.
**The Civitai Terms of Service are unread**: `civitai.com/content/tos` answered 403 to the fetcher on 2026-11-02 (and on the earlier design pass).
Civitai therefore stays off by default and must not ship enabled until an owner or admin has read the terms and this section records what they say about
API use and automated downloads. Facts recorded elsewhere, not terms: real-person likeness content has been banned there since 2025-05-22 and the site has restricted
UK visitors; some downloads need an API key (whether one works without a key is unverified). Hugging Face and file import must work fully with Civitai off.

**Adult data.** Both sites' own fields are used as-is (Civitai `nsfw` flag and per-image `nsfwLevel`, Hugging Face tag `not-for-all-audiences`); no word list reads a name,
description or tag. Adult and unsure results are not drawn without the Adult unlock.

