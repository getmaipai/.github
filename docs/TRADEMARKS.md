# Trademarks and platform references

Pinned from `CLAUDE.md`'s "Topic docs" index. Load this whenever a session
writes copy, UI, or code that mentions a third-party platform (YouTube,
TikTok, Plex, Spotify, Reddit, and the rest) or styles an integration tile.

Standing editorial rules for any mention of third-party platforms anywhere:
code, docs, UI copy, READMEs, release notes, commit messages, issues.

- **Names only, descriptively.** Third-party names may be used to state
  compatibility ("connects to YouTube"), never in product or feature branding,
  app names, icons, or logos. No platform logos or brand assets in any repo,
  ever.
- **Every product README carries the standard disclaimer block**, kept
  word-for-word consistent across repos: MaiPai is open-source software for
  personal, self-hosted, non-commercial use by you and your household; it is
  not affiliated with, endorsed by, or sponsored by any platform it can
  connect to; all product names and trademarks belong to their respective
  owners; you are responsible for complying with the terms and laws that
  apply to you and the services you access. The release skill checks the
  block is present and current before cutting a release.
- **Banned vocabulary in all copy:** "bypass", "free <platform> content",
  "ad-free <platform>", "without limits", "avoid paying", or any phrasing
  that pitches a MaiPai feature as a way around another service's rules or
  pricing. Describe what MaiPai is (a private family hub for your own media
  and accounts), not what it gets around.
- **Integrations are described, not branded:** "YouTube integration" as a
  descriptive phrase is fine; "MaiPaiTube" or platform-styled UI is not.
- **No borrowed trade dress.** A platform's distinctive visual identity is as
  off-limits as its logo: signature brand colors used as identifiers
  (YouTube's red on a play control, Spotify's green on anything audio,
  Netflix-red accents on a video shelf), containered icon shapes (the rounded
  red play-button tile), typography lockups, or screen layouts recognizable
  as a specific app's look. MaiPai surfaces use MaiPai's own palette and
  iconography everywhere, including for integration tiles: an integration is
  represented by a generic glyph (a play triangle, a music note) in MaiPai
  colors plus its written name, never by an imitation of the platform's mark.
  Colors as plain colors are fine (red exists); what's banned is using a
  brand's color-plus-shape combination where users would read it as that
  brand.
- **How strict: conventions are free, signatures are not.** UI patterns found
  across three or more competing apps (thumbnail card grids, focus/hover
  autoplay previews, duration badges, watched-progress bars, category
  shelves, vertical short-video feeds, "continue watching" rows) are industry
  conventions: use them freely. An element that lives in one app and evokes
  it is a signature: skip it. Two tests: the convention test above, and the
  squint test (if a glance from the couch could mistake the screen for the
  other app, it's too close; if it just reads "a streaming app", it's fine).
  The craft rule: copy the function, restyle the form in MaiPai's own
  palette, shapes, and type.
- **Section and feature naming in our UIs:** generic descriptive names
  (Trending, Popular, Subscriptions, Continue watching) are always fine, and
  so is honestly labeling a source section with the platform's name
  ("YouTube", with a generic glyph). Prefer plain English over a platform's
  branded jargon for features: "Short videos", not "Shorts". Platform
  taxonomy displayed as data (their category names on their content) is data,
  not branding.
- **Trademark and copyright symbols:** don't sprinkle them. Third-party names
  appear unmarked in running text; the README disclaimer block covers
  attribution once. Our own marks carry no ™ for now, and never ® (that
  requires an actual registration). Copyright is the "Copyright (c) <years>
  Jesse Torres" line in each LICENSE; no per-file headers, no © elsewhere.
- When writing anything that touches these rules and the right wording is
  unclear, flag it for Jesse instead of improvising.
