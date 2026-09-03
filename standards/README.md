# @maipai/standards

The enforceable half of the org standards: shell tooling every `getmaipai`
repo pins by tag and calls from its own `scripts/check.sh`. The prose half
(what the rules say and why) lives in [`../CLAUDE.md`](../CLAUDE.md) and the
`docs/` tree beside it; this package is what actually runs.

Current version: **std-v0.1.0** (see [`VERSION`](VERSION)).

## What v0.1 ships

- `bin/check-core.sh`: the shared `check.sh` core. Runs gitleaks, the PII
  wordlist scan, the prose lint, and the licence check, in that order, and
  exits non-zero on the first category that fails (each check still runs and
  reports, so one commit shows every problem at once).
- `bin/pii-scan.sh`: word-boundary scan of tracked files and the working tree
  against the private wordlist at `~/.config/maipai/pii-words.txt`.
- `bin/prose-lint.sh`: the AI writing standards from
  [`CLAUDE.md`](../CLAUDE.md) > Writing style, checked line by line against
  every tracked Markdown file. A line documenting the rule itself (a style
  guide has to name the words it bans) can end with
  `<!-- prose-lint: allow -->` to opt out; that marker exists for that one
  case, not for silencing a real violation.
- `bin/licence-check.sh`: confirms `LICENSE` is AGPL-3.0 with a copyright
  line.

Later versions add: the kit lint, the screenshot pipeline pieces (viewport
matrix, overflow and clipping checks, the vision-review runner), the
cross-cutting schemas (`logging.json`, `trace.json`, `errors.json`,
`budgets.json`, `privacy.json`), and the design tokens' source, per the
platform plan chapter 2.1.

## How a repo pins this

A consuming repo's `scripts/check.sh` runs its own build, lint, and test
steps first, then calls the core:

```bash
STANDARDS_DIR="${MAIPAI_STANDARDS_DIR:-../.github}"
if [ ! -d "$STANDARDS_DIR/standards" ]; then
  echo "missing @maipai/standards checkout at $STANDARDS_DIR (pin std-v0.1.0)"
  exit 1
fi
bash "$STANDARDS_DIR/standards/bin/check-core.sh" "$(pwd)"
```

The pin is the git tag: a repo states which `std-vX.Y.Z` it targets in its
own dev docs, and `MAIPAI_STANDARDS_DIR` points at a checkout of `.github` at
that tag (the sibling checkout on the dev machine, or a shallow clone in CI).
`check-core.sh` does not itself verify the tag; that is the honesty of the
pin, the same way a `package.json` version range is honesty until someone
runs `npm outdated`.

## Why shell, not an npm package

The plan's language ("published from `.github`... pinned by every repo") is
about the pin discipline, not the distribution mechanism. Every consumer
today is a bash `check.sh`; shipping this as bash next to it, versioned by
git tag, gets the same guarantee (a repo can name exactly which core it
runs against, and `check.sh` fails loud if that checkout is missing) with no
registry to operate. If the kit lint or the vision-review runner need a real
JS/TS runtime later, that piece can publish to GitHub Packages without
moving this one.

## Testing this package

There is no separate test suite yet: `bin/check-core.sh` run against this
repo itself is the test (see `scripts/check.sh` at the repo root). A
deliberate em dash in any tracked `.md` file must fail it.
