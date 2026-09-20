---
name: local-model-check
description: Check whether the household's local coding model (Qwen3.8-27B on the laptop, behind maipai-chat.service on :8791) is up, and diagnose why when it isn't - including the known Thunderbolt eGPU-drop failure mode and its verified recovery. Use before routing an S or small-M item to the local-model lane (coordinate skill section 1b), when the lane is reported down or sits idle for no stated reason, or when Jesse asks whether Qwen or the local model is working.
---

# Check and diagnose the local model lane

Read-only diagnosis first, one safe restart action if the cause has
already cleared itself. Never reboot the laptop, never power-cycle
hardware, never loop retrying: report what was found and stop at the
window named in each step.

No LAN IPs or hostnames are written into this file (org rule: homelab
topology lives only in the private homelab repo). Connect with the SSH
alias `laptop-linux` (already in `~/.ssh/config` on the coordinator's
machine); run checks over that SSH connection rather than curling an
address directly, so this file stays portable and compliant.

## 1. Health check (the fast path, exits here most of the time)

```
ssh -o ConnectTimeout=5 laptop-linux 'curl -sS --max-time 5 http://localhost:8791/v1/models'
```

HTTP 200 with a model list: the lane is up. Report that and stop; this is
the common case and should cost one tool call. If the SSH connection
itself fails (not just the curl), the laptop is off or off the network;
report that and stop, nothing remote to check further.

## 2. Unreachable: read the service status

```
ssh laptop-linux 'systemctl status maipai-chat.service --no-pager -l'
```

## 3. The known failure mode: the eGPU dropped off Thunderbolt

The engine is split across the laptop's internal RTX 2070 Super and an
external RTX 3070 in a Razer Core X Chroma enclosure over Thunderbolt
(`docs/local-coding-model.md`; the full topology and verified recovery
runbook are in the private homelab repo,
`laptop/README.md` and `docs/hosts/maipai-home.md`,
"The same procedure, fully remote"). If `systemctl status` shows
`ExecStartPre` failing a `test -e /dev/nvidiaN` check, or the restart
counter is high (hundreds, climbing every ~15s), confirm with:

```
ssh laptop-linux 'nvidia-smi -L; boltctl list'
```

One GPU listed instead of two, and `boltctl` showing the Core X Chroma
enclosure(s) as `status: disconnected`, is the eGPU off the Thunderbolt
link. **A plain power cycle on the enclosure's smart plug is not
enough by itself and should not be reported as the fix on its own**
(learned live, 2026-09-20: Jesse power-cycled it, `boltctl` stayed
`disconnected` and `journalctl -u bolt` kept logging `found 0 domain`
for several minutes after). The homelab runbook explains why: powering
the enclosure back up while the laptop is already running is not a
cable event to the Thunderbolt controller, so nothing tells it to
rescan on its own. Two ways to actually recover it, in order of
preference:

**A. Software wake (fastest, no reboot, when the laptop is already up
and the enclosure now has power)**: run the deployed wake script,
which force-powers the Thunderbolt controller via its Intel WMI switch
and rescans the PCI bus:

```
ssh laptop-linux 'sudo bash /home/maipai-admin/egpu-wake.sh'
```

**B. The full verified sequence (when A doesn't clear it, or the
kernel needs a clean start)**: smart plug off, a *clean* reboot
(`sudo systemctl reboot` or `poweroff`, never forced - a forced
power-off is reserved for a provably hung kernel only, confirmed twice
in the homelab's own history, and is not the routine path), wait for
the login prompt, smart plug back on, wait ~10s, then run the wake
script above. Full detail, exact grub/udev fixes, and the two-Fingerbot-
vs-one-cable distinction live in the homelab repo; don't duplicate them
here, read that doc when a session actually needs them.

**Both of those need root and this session does not have it.** Checked
by hand, not assumed: `sudo -n` on `laptop-linux` fails with "a
password is required", and a bare `sudo systemctl reboot` /
`sudo bash egpu-wake.sh` fail with "interactive authentication
required." Until Jesse adds a narrow NOPASSWD grant for these two
specific commands to the `maipai-admin` account (never broad sudo),
report the diagnosis and ask him to run whichever of A or B applies,
or provide the sudo password interactively in his own session. Never
guess at working around the missing grant (no privilege escalation, no
alternate account probing).

**Jesse's smart plug is the one he controls** (he's said this
directly: he does the physical/remote toggle, this skill's job is to
tell him precisely when and why - name of the plug and its address
live in the homelab repo, not here). When telling him to power-cycle
it, say which enclosure(s) `boltctl` shows as `disconnected` (there are
two Core X Chroma units), and that the cycle alone will not bring it
back without step A or B above following it - name the follow-up
command, don't leave it implied.

**Verify recovery before declaring success**, either path:

```
for i in 1 2 3 4 5 6; do
  sleep 15
  ssh laptop-linux 'nvidia-smi -L'
done
```

- **Both GPUs listed within the window**: recovered. `maipai-chat.service`
  auto-restarts within ~15s on its own; confirm with step 1's health
  check once more rather than assuming.
- **Still one GPU after ~90s**: A or B did not clear it. Don't keep
  polling past this window. Report exactly that - which step was tried,
  what `boltctl` shows now - and that it may need the other path (A
  after a failed B's reboot, or a physical cable check per the homelab
  doc if both A and a clean reboot leave it disconnected).

Route the item to Codex or a Haiku-floor Claude session while this is
unresolved (`CLAUDE.md`, Roles).

## 4. Anything else: read and report, don't guess

```
ssh laptop-linux 'journalctl -u maipai-chat.service --no-pager -n 40'
```

A binary-not-found, config, disk-space, or OOM error goes back to
Jesse or the coordinator verbatim (the log line, not a paraphrase) as a
blocker classified *environment* per the `coordinate` skill's blocker
classes. Don't try fixes beyond the ones named above without asking.

## Why there's no standing watchdog here

systemd's own `Restart=on-failure` on `maipai-chat.service` already
retries indefinitely, so the lane self-heals the moment the eGPU link
is actually restored (step A or B above), with no extra script needed
for that part. What was missing before this skill existed was Jesse
finding out the lane was down for a hardware reason and exactly which
command clears it - that's what this skill's report is for. A second
watchdog daemon on the laptop would only duplicate systemd's own
restart logic; nothing beyond the checks above should be built without
a concrete, currently-unsolved gap to justify it (the org's rule
against hand-built work duplicating a prebuilt mechanism, applied here
too). If Jesse grants the scoped sudo noted above, the next addition
is running A or B automatically from this skill rather than asking him
to run it - not a new daemon.
