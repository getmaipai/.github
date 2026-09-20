---
name: local-model-check
description: Check whether the household's local coding model (Qwen3.8-27B on the laptop, behind maipai-chat.service on :8791) is up, and diagnose why when it isn't - including the known Thunderbolt eGPU-drop failure mode. Use before routing an S or small-M item to the local-model lane (coordinate skill section 1b), when the lane is reported down or sits idle for no stated reason, or when Jesse asks whether Qwen or the local model is working.
---

# Check and diagnose the local model lane

Read-only diagnosis first, one safe restart action if the cause has
already cleared itself. Never reboot the laptop, never touch hardware
remotely, never loop retrying: two checks in, report what was found and
stop.

## 1. Health check (the fast path, exits here most of the time)

```
curl -sS --max-time 5 http://172.19.210.52:8791/v1/models
```

HTTP 200 with a model list: the lane is up. Report that and stop; this is
the common case and should cost one tool call.

## 2. Unreachable: narrow it down

```
ping -c 2 -t 3 172.19.210.52
ssh -o ConnectTimeout=5 laptop-linux 'systemctl status maipai-chat.service --no-pager -l'
```

- Ping fails: the laptop itself is off or off the network. Report that;
  nothing remote to check further.
- Ping succeeds, port closed: the engine service isn't running. Read the
  `systemctl status` output for the failure.

## 3. The known failure mode: the eGPU dropped off Thunderbolt

The engine is split across the laptop's internal RTX 2070 Super and an
external RTX 3070 in a Razer Core X Chroma enclosure over Thunderbolt
(`docs/local-coding-model.md`, the 2026-09-17 engine-host decision). If
`systemctl status` shows `ExecStartPre` failing a `test -e /dev/nvidiaN`
check, or the restart counter is high (hundreds, climbing every ~15s),
confirm with:

```
ssh laptop-linux 'nvidia-smi -L; boltctl list'
```

One GPU listed instead of two, and `boltctl` showing the Core X Chroma
enclosure(s) as `status: disconnected`, is the eGPU physically dropped
off the Thunderbolt link. **This is not remotely fixable.** systemd is
already auto-restarting every ~15s and will pick the service back up on
its own the moment the link comes back; do not stop that loop, do not
attempt a PCI or Thunderbolt rescan (a "disconnected" bolt status means
the physical link is down, not just unauthorized, and a rescan will not
bring it back).

**The action to report is a power cycle, not "check the cables."**
Jesse controls the eGPU enclosure's power through a Kasa smart plug and
has said this is the fix he wants named directly: tell him to power-cycle
the eGPU enclosure(s) via Kasa (off, a few seconds, back on), not a vaguer
"check the Thunderbolt connection." There are **two** Core X Chroma
enclosures (both named in `boltctl list`) - say which one(s) are still
`disconnected` so he knows whether one plug or both need cycling.

**Verify the cycle actually worked before telling him it's fixed.** A
first real attempt (2026-09-20) did not recover within several minutes:
`boltctl` stayed at `status: disconnected` on both enclosures and
`journalctl -u bolt` kept logging `udev: found 0 domain` - meaning the
host never even saw a hotplug, not just an unauthorized one. After
Jesse confirms he's cycled the power, poll instead of declaring success:

```
for i in 1 2 3 4 5 6; do
  sleep 15
  ssh laptop-linux 'nvidia-smi -L; boltctl list | grep status'
done
```

- **Both GPUs listed within the poll window**: recovered. Restart the
  service per step 5 if the grant exists, otherwise tell Jesse it will
  pick itself up within ~15s.
- **Still one GPU / both `disconnected` after ~90s**: the cycle alone
  didn't do it. Don't keep polling past this window (rare failures with
  no timeout are how a 15s check becomes a resident background loop).
  Report exactly that back to Jesse, plus what to check next: is the
  Kasa plug he toggled actually the eGPU's plug (not e.g. a light or
  the wrong outlet), did he cycle *both* enclosures if both need it,
  and does the Thunderbolt cable need a physical reseat now that power
  alone didn't clear it. This is new information each time, not a
  scripted fallback - say plainly that the power cycle didn't work
  rather than repeating the same instruction.

Route the item to Codex or a Haiku-floor Claude session while this is
unresolved (`CLAUDE.md`, Roles).

## 4. Anything else: read and report, don't guess

```
ssh laptop-linux 'journalctl -u maipai-chat.service --no-pager -n 40'
```

A binary-not-found, config, disk-space, or OOM error goes back to
Jesse or the coordinator verbatim (the log line, not a paraphrase) as a
blocker classified *environment* per the `coordinate` skill's blocker
classes. Don't try fixes beyond the one below without asking.

## 5. The one safe fix: restart after the cause has cleared

If step 3's GPU check now shows both cards present (the cable was
reseated since the failure was first seen), restarting gets the server
back immediately instead of waiting for the next auto-restart tick:

```
ssh laptop-linux 'sudo -n systemctl restart maipai-chat.service' && sleep 3 && curl -sS --max-time 5 http://172.19.210.52:8791/v1/models
```

**This needs passwordless sudo (or a polkit rule) scoped to this one
unit for the `maipai-admin` account; as of 2026-09-20 that grant does
not exist**, so `sudo -n` fails with "a password is required" and
`systemctl restart` alone fails with "Interactive authentication
required" - confirmed by hand, not assumed. Until Jesse adds that
narrow grant (never broad sudo) on the laptop itself, this step is not
runnable by an unattended session; report the confirmed-clear GPU
state and ask him to restart it, or wait for the next auto-restart
tick (systemd retries every ~15s on its own regardless). Any restart
attempted without first confirming the underlying cause is gone just
re-enters the same crash loop and burns a round trip for nothing.

## Why there's no standing watchdog here

systemd's own `Restart=on-failure` on `maipai-chat.service` already
retries indefinitely, so the lane self-heals the moment the eGPU
reconnects with no script needed; a second watchdog process would only
duplicate that. What's actually missing is Jesse finding out the lane
is down for a hardware reason - which this skill's report is for, not
a new daemon on the laptop. Nothing beyond this skill's read-only
checks and the one gated restart above should be built without a
concrete, currently-unsolved gap to justify it (the org's own rule
against hand-built work that duplicates a prebuilt mechanism, applied
here to systemd's own restart logic).
