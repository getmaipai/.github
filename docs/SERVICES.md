# Services: how a MaiPai daemon runs on a person's machine

The layer under every product. MaiPai Stack is the first daemon built
to it; Home's watcher and the robot's processes follow it. Written
2026-09-17 from the survey in
`stack/docs/plans/operations-design-2026-09-17.md` (Ollama, Tailscale,
Syncthing, Home Assistant, launchd, systemd and Windows service
semantics, all primary sources).

## The three pieces

A MaiPai daemon ships as three pieces and never as a container:

1. **The daemon**, one compiled binary (Bun's single-file build with
   the web UI embedded), run by the OS service manager as the signed-in
   user so it has the GPU, the user's files and the keychain.
2. **The web UI**, served by the daemon on localhost, the whole admin
   surface; nothing to install, one origin, the shared kit.
3. **A thin native status app** (the tray or menu-bar item), which
   holds no logic, reads the daemon's event feed, opens the UI, offers
   Start, Pause and Resume, and is the only process that posts native
   notifications. It is an independent observer: when the daemon is
   down it says so and offers Start; it never assumes.

No Docker: on the Mac a container has no Metal and no unified memory,
and everywhere it is a second thing to install and explain. A Linux
server image may be offered later as packaging; it is not the
architecture.

## Same shape on every OS

One configuration, one API, one set of docs. Only these differ per
platform, each recorded in the product's `dev.md`:

| | macOS | Linux | Windows |
|---|---|---|---|
| Service manager | launchd LaunchAgent (`~/Library/LaunchAgents/com.maipai.<product>.plist`) | `systemd --user` unit | Windows service |
| Restart policy | `KeepAlive {SuccessfulExit: false}`, `ThrottleInterval 30` | `Restart=on-failure`, `WatchdogSec=30`, `StartLimitBurst=5` | restart twice, then stop; reset the count after an hour |
| Data directory | `~/.maipai/<product>/data` | `~/.maipai/<product>/data` | `%LOCALAPPDATA%\\MaiPai\\<product>\\data` |
| Logs | `<data>/logs`, stdout and stderr captured by launchd | `<data>/logs`, journald captures stdout | `<data>/logs`, the Event Log for start, stop and failure only |
| Native notifications | the status app, under its bundle id | the status app over D-Bus (libnotify) | the status app with an AppUserModelID |

The daemon exits 0 on a deliberate stop and non-zero on failure, so
"restart on failure" means what it says. On Linux it sends the
readiness and `WATCHDOG=1` datagrams to `$NOTIFY_SOCKET` itself; no
libsystemd.

MaiPai Stack is the first daemon built to this section and shows the shape on both systems (`stack/docs/dev.md`): on macOS a launchd agent installed, started, stopped, inspected and removed by the daemon's own subcommands, restarted on failure, logging under its data directory; on Linux a `systemd --user` unit of `Type=notify` with `Restart=on-failure`, a five second restart delay, a thirty second watchdog, five starts per five minutes, enabled for the default target, the daemon answering the manager itself (READY when its server is up, the watchdog beat at half the interval, STOPPING on stop) over the notify socket with no libsystemd, and the manager chosen by platform at start. Home's installer installs the Stack; a person never installs it by itself.

## The watchdog layers

Three, none of them a second daemon: the service manager restarts on
failure and throttles a crash loop; the daemon's own supervisor
restarts its engine children with backoff and raises a health item
instead of restarting a child forever; the status app polls the
daemon's health endpoint and shows the truth when it is gone.

## One instance

A daemon runs at most once per machine per OS user, whatever data directory
or port it is given. On 2026-09-29 a second hub, started by hand with a
different data directory and port, ran beside the real one for hours and
answered on its port with an empty household. A lock per data directory
would not have stopped it, so the lock is per machine.

On boot, before opening any database or binding a port, the daemon takes
an exclusive lock at `~/.maipai/<product>/<daemon>.lock`
(`%LOCALAPPDATA%\MaiPai\<product>\<daemon>.lock` on Windows). The file is
JSON, `{pid, startedAt, port, dataDir, cwd}`, and it is created atomically:
write a temp file, then `link()` it into place, falling back to an
exclusive create where hard links do not exist.

- **Stale locks are reclaimed.** A lock is stale when its pid is dead, when
  the pid now belongs to something that is not the daemon's runtime, or
  when that process started after `startedAt`. A crashed daemon never
  blocks the next start.
- **Released on exit.** A clean exit, SIGINT and SIGTERM all release it. A
  hard kill leaves a stale lock, which the next start reclaims.
- **A second start refuses.** It exits 1 before touching any database and
  says, in plain words, which daemon is running and how to stop it:
  `Another <Product> <daemon> is already running on this machine (PID n,
  port n, data directory ...). Only one runs at a time, so this one will
  not start, and it has not touched any database. Stop the running one
  first: kill n.`
- **No production opt-out.** Tests that boot throwaway instances on their
  own data directory and port set a test-only environment variable that
  skips the lock, point the lock path at a temp file, and the daemon logs
  a warning to stderr whenever the variable is set.
- **Managers read the same file.** The service manager scripts and the
  status tooling read the lock to name a daemon they did not start, with
  its pid, port and data directory, and refuse to report success for a
  start that was refused.

A data directory outside the product's own home (the repo checkout for a
source run, `~/.maipai/<product>/data` for an install) is refused unless
the person set it on purpose, so a working-directory slip cannot silently
create a second, empty household. Home's implementation is
`backend/src/lib/instanceLock.ts` and `bootGuard.ts`.

## Health, one list

The daemon owns one list of health items: `code`, `severity`
(`critical | error | warning`), `title`, `text`, `since`, `cause`, at
most one `fix` (`label`, `action`), an optional learn-more link. Items
are keyed and idempotent: raising the same code updates, resolving
deletes. `GET /<product>/v1/health` returns the list, the event feed
carries `health.changed`, and every surface (the UI, the status app,
a CLI) renders the same list. Severity drives presentation only:
critical is a badge plus a native notification, error a badge,
warning visible on the health page. A Repair is a health item with a
fix, shown in the shape Home Assistant made familiar: a badge count,
one card per item, a plain title, why, one Fix or Learn more, and
Ignore.

## Logs

Structured JSON lines per the logging standard in
[ENGINEERING.md](ENGINEERING.md), one rotating file per engine or
child process plus the daemon's, `0600`, rotation by size and
retention by days, secrets and PII never landing (the redaction test
is mandatory), a Logs page that tails them. Nothing is sent anywhere.

## Notifications from a daemon

A daemon never shells out to `osascript` or `terminal-notifier`, and
never pretends to be another app. Native notifications are posted
only by the status app under its own identity. Off-machine channels
(Telegram, ntfy) are opt-in, direct from the machine to the service,
tested from the channel form with a real message, listed on the
product's privacy page, per [NOTIFICATIONS.md](NOTIFICATIONS.md).

## Install and uninstall

Install is one command hosted by us that downloads only our own
binary from our own release with its checksum verified, installs under
the user's home, registers the service, starts it and opens the UI;
re-running updates; `--uninstall` removes the service and the binary
and never the data directory, and says so. The app bundle with the
status app is the second path and runs the same steps. Nothing at
install time comes from a third party; engines and models arrive
later, when the person chooses an ability, each pinned and checksummed.

## Updates

Per [UPDATES.md](UPDATES.md): opt-in checks that send only a
conditional-request header and a user agent, manifests we host as
release assets, the previous version kept for one-click rollback, a
drain before any swap.
