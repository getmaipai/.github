# @maipai/standards

The enforceable half of the org standards: shell tooling every `getmaipai`
repo pins by tag and calls from its own `scripts/check.sh`. The prose half
(what the rules say and why) lives in [`../CLAUDE.md`](../CLAUDE.md) and the
`docs/` tree beside it; this package is what actually runs.

Current version: **std-v0.3.0** (see [`VERSION`](VERSION)).

## What v0.1 shipped

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

## What v0.2 added

The five cross-cutting schemas platform plan 2.1 lists, each a JSON Schema
2020-12 file under `schemas/`, with generated Zod (`gen/ts/`) and Pydantic
v2 (`gen/py/`) bindings, fixture-tested the same way `home/spec/` tests
its own schemas (`fixtures/`, `tests/ts/`, `tests/py/`):

- `error-entry.schema.json` (`ErrorEntry`): the shape of one code in an
  error catalogue. `home/spec/errors/errors.json` is the populated
  catalogue for the platform, conforming to this; this package doesn't
  hold catalogue data itself, only the shape.
- `logging-line.schema.json` (`LoggingLine`): one structured log line.
- `trace-span.schema.json` (`TraceSpan`): one span in a trace, the
  Developer-tools timeline's unit.
- `budget.schema.json` (`Budget`): one performance budget declaration
  against a named reference machine.
- `privacy-row.schema.json` (`PrivacyRow`): one row of a "what leaves the
  house" table; a package's manifest `data_sources[]` is an array of
  these.

These are meant to be imported cross-repo by `$ref` (a consumer's own
schema references e.g.
`https://getmaipai.github.io/.github/standards/schemas/privacy-row.schema.json`),
not copied. `home/spec/schemas/manifest.schema.json` does exactly that for
`PrivacyRow`; see `home/spec/README.md`'s "Cross-repo schemas" section for
how its codegen resolves it, including a real gotcha (a blanket JSON
Schema resolver over the whole document breaks an unrelated schema's
internal `oneOf`) worth reading before repeating the pattern elsewhere.

Later versions add the screenshot pipeline pieces (viewport matrix,
overflow and clipping checks, the vision-review runner), per the platform
plan chapter 2.1. The kit lint and the design tokens' source do not live
here: they ship with the kit itself as `@maipai/ui` in `getmaipai/shared`
(`ui/eslint.config.js`, imported by a consumer as
`@maipai/ui/eslint.config.js`, and
`ui/src/tokens.css`), since a lint that names the kit's own primitives
belongs beside them, and every consumer pins the kit's tag rather than a
second copy of its rules here.

## What v0.3 added

- The prose lint no longer flags exclamation points inside inline code spans, HTML comments or Markdown image syntax.
- The prose lint's line scanner was rewritten in awk, reducing runtime from
  60 seconds to under 0.1 seconds for consumers.
- Gitleaks is scoped to the working tree for each commit, so consumers get
  findings from the files they are checking rather than unrelated paths.
- The kit lint and design tokens now live with the kit in commons, so
  consumers pin and run the kit's own rules beside its primitives.
- `bin/ensure-tag.sh` and the pin block resolve the standards tag through a
  per-tag worktree, so consumers run the exact immutable release they pin.

## How a repo pins this

A consuming repo's `scripts/check.sh` runs its own build, lint, and test
steps first, then calls the core:

```bash
STANDARDS_REPO="${MAIPAI_STANDARDS_DIR:-../.github}"
STD_TAG="std-v0.3.0"
if [ ! -x "$STANDARDS_REPO/standards/bin/ensure-tag.sh" ]; then
  echo "getmaipai/.github is missing at $STANDARDS_REPO or older than std-v0.3.0 (set MAIPAI_STANDARDS_DIR to a checkout that has standards/bin/ensure-tag.sh)"
  exit 1
fi
STANDARDS_DIR="$(bash "$STANDARDS_REPO/standards/bin/ensure-tag.sh" "$STD_TAG")"
if [ "$(cat "$STANDARDS_DIR/standards/VERSION")" != "${STD_TAG#std-v}" ]; then
  echo "@maipai/standards at $STANDARDS_DIR is $(cat "$STANDARDS_DIR/standards/VERSION"), but the tag is $STD_TAG"
  exit 1
fi
bash "$STANDARDS_DIR/standards/bin/check-core.sh" "$(pwd)"
```

The guard is what a contributor sees on a machine without the checkout; without it the call fails as a bare shell error.

The pin is the git tag. `MAIPAI_STANDARDS_DIR` names where the `.github` repo is (the sibling checkout by default); `ensure-tag.sh` resolves the tag to a read-only worktree under `../.github-tags/`, so a gate never runs whatever the working checkout happens to have, and the `VERSION` compare catches a tag cut against the wrong commit. Bumping a pin is one edit, the tag string.

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

`bin/check-core.sh` run against this repo itself proves the shell tooling
(see `scripts/check.sh` at the repo root; a deliberate em dash in any
tracked `.md` file must fail it). The v0.2 schemas have their own suite:
`bun test` and `uv run pytest tests/py -q`, round-tripping every fixture
in `fixtures/` through both generated model sets, the same proof
`home/spec/` uses for its own schemas.

Every `uv run` in the gate is `--frozen`: the gate reads the lock, never rewrites it.
