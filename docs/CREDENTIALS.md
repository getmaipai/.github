# Credentials and secrets (hard rules)

Referenced from `CLAUDE.md`'s "Credentials and secrets" section. Load this whenever a session
touches auth, tokens, OAuth, API keys, session cookies, or anything else
that stores or handles a credential.

A leaked family credential is the one failure MaiPai cannot recover from with an
update. Found on the hub on 2026-08-29: a linked account's OAuth refresh token
sitting in plaintext in `app.db`, and the keystore key readable by every local
Windows account. Both are fixed; these rules keep them fixed.

- **Never in git, ever.** Anything under a repo's `data/`, every `.env`, key,
  token, cookie jar, session file, exported credential or DB is ignored by
  `.gitignore` and stays that way. Before every commit, `git diff --cached`
  is checked for secrets; a secret that reaches a remote is rotated the same
  hour, and the commit is rewritten out of history, never "removed in a
  follow-up".
- **Encrypted at rest, keyed outside the data.** Any reversible secret the
  app stores (OAuth tokens, app passwords, API keys, session cookies) is
  encrypted with the keystore (`lib/secrets`: AES-256-GCM, key in `data/keys`
  or `SECRETS_KEY`), never plaintext in a table or JSON file. A copied
  database must be useless without the key. One-way secrets (PINs) are
  hashed with a pepper, never encrypted.
- **Least privilege on disk.** Secret stores are readable only by the
  service account, SYSTEM and administrators (`lib/secretPaths`); the server
  re-applies that at boot and whenever it writes one. Full-disk encryption
  on the host is expected, not a substitute.
- **Never logged, never returned.** No secret value in logs, error messages,
  notifications, chat context, API responses (status = "present", "expires",
  never the value), screenshots, or session notes. Prefixes and lengths are
  fine for debugging; values are not.
- **Handled only where needed.** Credentials move over encrypted channels
  (HTTPS, SSH) and live only on the server that uses them; a working copy on
  a laptop or in a scratch folder is deleted as soon as the task is done, and
  the deletion is stated. Never pass a secret on a command line or in a
  process list; use a file with restricted permissions or the environment of
  a child process.
- **Scoped and revocable.** Prefer per-purpose tokens (a TV-device OAuth
  grant, an app password) over a person's real password. Every stored
  credential has a status, an expiry, and a one-click revoke in the admin
  UI, and the app notices and reports when it stops working.
- **Identity is per-person; a shared session may only be a doorkey.**
  Personalization - history, resume, recommendations, a person's own feed -
  is never pooled into one account: it stays per MaiPai user, enforced at the
  query level. A household MAY share ONE playback/fetch session (ideally a
  dedicated account, not a real person's) purely to get past a per-IP block,
  because that session carries no identity and shapes no one's suggestions.
  The test: if the shared thing would change what another person sees or
  recommends, it is identity and must be per-person; if it only unlocks a
  fetch, it may be shared. A person may always connect their own, and their
  playback uses it in preference to the shared one.
