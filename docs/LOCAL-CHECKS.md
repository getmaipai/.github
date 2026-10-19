# Local checks on a developer machine

Dev tier. Every repo's `scripts/check.sh` ends with the standards core (`standards/bin/check-core.sh`), which needs two things on the
machine that no repo can ship: the `gitleaks` binary and a private PII wordlist. Without them the gate only prints a warning and
skips the scan, so a leak is not caught. Set both up once per machine.

## 1. Install gitleaks

```bash
brew install gitleaks
```

Check with `gitleaks version`. `check-core.sh` runs `gitleaks dir --no-banner --redact .` in each repo and fails on any finding.
A repo may carry its own `.gitleaks.toml` (Home does, for the `maipai_key_` placeholder shape).

## 2. Create the private PII wordlist

The wordlist lives at `~/.config/maipai/pii-words.txt`. It is never committed, never pasted into an issue, a doc or a chat, and not
copied to another machine over an insecure channel.

```bash
mkdir -p ~/.config/maipai
chmod 700 ~/.config/maipai
touch ~/.config/maipai/pii-words.txt
chmod 600 ~/.config/maipai/pii-words.txt
```

Format, read by `standards/bin/pii-scan.sh`:

- One word or phrase per line. Blank lines and lines that start with `#` are ignored.
- Each entry is an extended regular expression matched as a whole word, case-insensitive, with `git grep -inwE` over tracked files
  and the working tree. Escape dots in IP addresses and phone numbers (`192\.0\.2\.10`).
- Put in it what must never reach a repo: family member names, the home address, phone numbers, personal email addresses, real
  LAN IPs and homelab hostnames. The owner's own name is the one allowed exception, so leave it out.
- A name that is also a roster persona word (see the org `CLAUDE.md`) would fail the scan on legitimate examples. Keep it out of the
  list and rely on review for that one.

To find the LAN addresses of the machine you work on:

```bash
ifconfig | grep "inet "
```

## 3. Check that both work

Run the standards core from any repo checkout:

```bash
bash scripts/check.sh --pre
```

The output must show the `standards: gitleaks (working tree)` and `standards: PII wordlist` steps with no `WARN: gitleaks not
installed` and no `WARN: no PII wordlist` line. To scan one repo by hand:

```bash
bash /path/to/.github/standards/bin/pii-scan.sh /path/to/repo
gitleaks dir --no-banner --redact /path/to/repo
```

`pii-scan.sh` exits 0 and prints nothing when clean. To audit a repo's full history once (slower, run it before making a repo
public), use `gitleaks git --no-banner --redact /path/to/repo`.

## When a scan reports a hit

- A real secret or private value: remove it, rotate the credential if it was ever pushed, and rewrite the example to use `192.0.2.x`,
  `example.com` or a roster persona.
- A false positive (a fake key in a test fixture or a design asset): change the value to an obvious placeholder first. Only when
  that is impossible, add the finding's fingerprint to the repo's `.gitleaksignore` with a one-line comment saying why.
- Never loosen `pii-scan.sh` or `check-core.sh` to make a hit pass.
