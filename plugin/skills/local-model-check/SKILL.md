---
name: local-model-check
description: The one procedure for the household's local coding model (Qwen3.8-27B behind maipai-chat.service on :8791, split across the laptop's internal RTX 2070 Super and an RTX 3070 in a Thunderbolt enclosure) - health check, diagnosis, the known eGPU-drop failure and its verified one-command recovery, and the rules for running anything heavy on that host. Read it on the SYMPTOM, never on a judgment about the cause: any time nvidia-smi shows fewer than two GPUs, the :8791 health check does not return 200, the service is stuck in activating/auto-restart, the host stops answering ssh or ping, OR you are about to run any build, download, bench or restart on it - even when you already know why, and especially when you caused it yourself. Also before routing an item to the local-model lane, and when Jesse asks whether Qwen or the local model is working.
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

**Trust `nvidia-smi`, not the script's last line.** Until 2026-09-22
that line grepped for the RTX 5060 Ti's PCI id and so printed "no eGPU
yet" on a *successful* wake, because the enclosure holds an RTX 3070
now. It has been fixed to test `/dev/nvidia1`, but the lesson stands:
proof of recovery is two cards in `nvidia-smi` plus a 200 from the
health check, never a script's own summary. A wake that worked also
shows the Thunderbolt controller back on the bus (`8086:15e8`,
`8086:15e9`) and the Core X Chroma entries at `auth=1`.

**B. The full verified sequence (when A doesn't clear it, or the
kernel needs a clean start)**: smart plug off, a *clean* reboot
(`sudo systemctl reboot` or `poweroff`, never forced - a forced
power-off is reserved for a provably hung kernel only, confirmed twice
in the homelab's own history, and is not the routine path), wait for
the login prompt, smart plug back on, wait ~10s, then run the wake
script above. Full detail, exact grub/udev fixes, and the two-Fingerbot-
vs-one-cable distinction live in the homelab repo; don't duplicate them
here, read that doc when a session actually needs them.

**Both of those need root.** Check first whether the scoped grant
exists before assuming it doesn't:

```
ssh laptop-linux 'sudo -n systemctl restart maipai-chat.service --help >/dev/null 2>&1 && echo GRANT_OK || echo NO_GRANT'
```

**The grant IS installed** - confirmed live 2026-09-22
(`/etc/sudoers.d/maipai-admin-egpu`, put in place 2026-09-20). So run
step A yourself; do not ask Jesse to type it. It is scoped to exactly
four commands (`systemctl restart maipai-chat.service`,
`systemctl reboot`, `poweroff`,
`bash /home/maipai-admin/egpu-wake.sh`) and nothing wider. If
`NO_GRANT` ever comes back, `laptop/linux/grant-egpu-sudo.sh` in the
homelab repo reinstalls it and Jesse runs that one line with his own
password. Never guess at working around a missing grant (no privilege
escalation, no alternate account probing, no asking for his password
in chat).

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

## Read this skill on the SYMPTOM, never on your judgment of the cause

This is the most important line in the file, because on 2026-09-22 a
session had every fact below available and used none of them.

**Trigger on any of these, full stop:**

- `nvidia-smi` lists fewer than two GPUs on that host
- the health check on `:8791` does not return 200
- `maipai-chat` is `activating (auto-restart)` or its `ExecStartPre`
  `test -e /dev/nvidia1` is failing
- you are about to run *anything* heavy on that host

**Do not** first ask why it happened. The 2026-09-22 session skipped
this skill precisely because it *knew* the cause - it had caused the
reboot itself - so it classified the situation as "my incident to
debug" rather than "the local model is down." One missing card after a
reboot is this failure class no matter who caused the reboot. Knowing
the cause is not a reason to skip the procedure; it is usually the
reason people skip it.

The second half of that miss: the session had been driving the host
all day with raw `ssh`, `lspci` and `nvidia-smi` for benchmarking, so
reaching for a runbook felt like a step backwards. Fluency with the
primitives is not a substitute for the procedure. It re-derived the
whole diagnosis from kernel logs, told Jesse to power-cycle hardware
he did not need to touch, and only found this file when he said "you
have a procedure for this." Cost: about forty minutes and the lane.

## Check the temperature, not just the service (2026-09-22)

That host shuts ITSELF down under sustained load, and it looks nothing
like a crash: no panic, no OOM line, just Intel Dynamic Tuning ACPI
errors (`\_TZ.ETMD`, `\_SB.IETM._OSC`) and two seconds later an
orderly `systemd-shutdown`. Twice in one afternoon.

Measured while merely serving inference: `acpitz` **92 C against a
100 C trip point**, both GPUs cool at 58-63 C. The CPU is the
constraint, not the cards, not VRAM.

So when the host is unreachable and you are reconstructing why, or
before you ask it to do anything sustained:

```
ssh laptop-linux 'cat /sys/class/thermal/thermal_zone0/temp'
```

Divide by 1000. Anything over about 85 C means it is close to the
edge and should not be given a build, a bench suite, or a long
benchmark. A previous boot's ending is worth reading too, because the
evidence is only there:

```
ssh laptop-linux 'journalctl -b -1 --no-pager | tail -5'
```

An orderly "Shutting down / Syncing filesystems" at the end means it
was not a crash - look for the thermal ACPI lines just above it rather
than hunting for a kernel fault that is not there. Full detail and the
measured table are in the homelab repo, `docs/hosts/maipai-home.md`,
"Thermal: this chassis shuts itself down under sustained load".

## Never run heavy work on that host while the lane is live

Same day, the cause of the above. A session started a 12-way parallel
CUDA build (`cmake --build -j 12`) plus an 11 GB model download while
`maipai-chat` was actively serving Session C. `ggml-cuda` is
template-heavy and each `nvcc` costs several GB; twelve of them on a
31 GB box already holding the model took the machine out entirely - no
SSH, no ping - and the reboot that followed dropped the eGPU.

`nproc` is not a budget. Before any build, download, or bench there:

1. **Cost the job, don't count cores.** CUDA compilation is the
   specific trap: several GB per parallel job. Never exceed `-j 4` on
   this machine.
2. **Stop the service first** for anything heavy, and restart it after;
   `systemctl restart maipai-chat.service` is granted. A build racing a
   live model server is the failure above.
3. **Fence the lane before stopping the service** - park the open
   briefs, stop `lanes-autofeed` - so Session C is not mid-request when
   the engine disappears. Put them back afterwards.
4. **Watch remote work to its first real output.** The build above died
   at *configure* (nvcc is not on a non-interactive shell's PATH; it
   needs `-DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc`), and the
   blind retry is what killed the box.
