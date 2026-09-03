# Updates, notifications of updates, and install

Everything that can be updated appears in one place, updates itself where
that is safe, asks with one click where it is not, and never needs a
terminal after the first install. Users touch releases, never `main`; a
release tag is the deploy, and re-pointing to the previous tag is the
rollback. Full source: platform plan section 2.4.

## What updates, from where, on what default channel

| Thing | Source | Default channel |
|---|---|---|
| Hub app | GitHub Release of `home`, signed asset plus sha256 | `notify` with one-click install; `auto` in the nightly window is an admin switch |
| Robot app | GitHub Release of `bot`; the hub downloads once, verifies, and pushes it over the link when paired, directly when standalone | follows the hub; standalone `notify` |
| Packages | catalog index; robots receive from the hub | `auto`, demoted to `notify` for that update when permissions change; `pinned` available |
| Models | catalog model packages | `notify` (shows size and whether the GPU must be idle) |
| Kit, shell, and sidecars (llama-server binary, ComfyUI, the voice sidecar, SearXNG, kiwix) | pinned in the app release with sha256 | with the app; a sidecar never updates alone |
| Pod firmware | hub release assets | `notify` per pod |

## The Updates page

One `updates` projection (installed, latest, summary, url, channel,
progress, needs, blocked_by) drives an Updates page grouped by kind, with
"Update all," per-row install, hold, and rollback; a sidebar badge; one
household notification per day at most through the digest (see
[NOTIFICATIONS.md](NOTIFICATIONS.md)). Every check is one signed request to
a static file, logged locally, and listed on the privacy page as the only
periodic outbound call.

## Install mechanics

Verify signature and sha256 first (a robot re-verifies what the hub pushed,
with its own keys). Back up the affected data. Stage into
`releases/<version>` beside the current one. Run migrations forward after a
dry run against the backup. Swap the `current` pointer. Restart under the
supervisor. Answer the health check within a fixed window or the pointer
moves back and the previous version boots. Keep the last two releases.
Packages drain and relaunch without a restart and must pass their smoke
test before re-enabling.

Only when safe: the hub in a nightly window (default 03:00 to 05:00 local),
never during playback, a conversation, a generation job, or an active
download; a robot only when docked, charging above a floor, idle, and
nobody in conversation, announcing before and after.

Compatibility gates check `min_app` and the link's spec major before
download and show `blocked_by` with the choice, never installing blind.
Hub first, robots only after the hub is healthy. Rollback is a button that
re-points and restarts; where a migration touched data it restores the
pre-update backup and says so first.

## Easy install

The one-line hub install, then the wizard, then never a terminal. A
flashable robot image whose first boot is the pairing or Wi-Fi screen. One
click for packages and models. "Update all." A step that would ask for a
shell command is a bug to file.
