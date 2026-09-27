#!/usr/bin/env bash
# .github pre-commit gate. This repo hosts @maipai/standards itself, so it
# calls the core directly rather than through a sibling checkout.
set -euo pipefail
cd "$(dirname "$0")/.."

# One full gate at a time on this machine (org CLAUDE.md > Verification;
# docs/DECISIONS.md, 2026-09-27). This gate has no docs-only scope, so it
# always takes the machine-wide lock, blocking FIFO behind any other
# repo's full gate, and frees it on every exit path, a failure or a kill
# included. GATE_LOCK_ITEM, when a caller sets it, names the item in
# `gate-lock.sh status`.
GATE_LOCK_LABEL="$(basename "$(pwd)")-$$"
trap 'bash standards/bin/gate-lock.sh release "$GATE_LOCK_LABEL" >/dev/null 2>&1 || true' EXIT
if ! GATE_LOCK_PID=$$ bash standards/bin/gate-lock.sh acquire "$GATE_LOCK_LABEL" "${GATE_LOCK_ITEM:-}"; then
  echo "== gate-lock: could not take the machine-wide full-gate lock (see above); not running the gate"
  exit 1
fi

if [ -d standards/schemas ]; then
  echo "== standards: regenerate and check for drift"
  (cd standards && bun run gen:ts >/dev/null)
  (cd standards && bash scripts/gen-py.sh >/dev/null)
  if ! git diff --quiet -- standards/gen; then
    echo "standards/gen/ is out of date with standards/schemas/. Run the gen scripts and commit the result."
    git --no-pager diff --stat -- standards/gen
    exit 1
  fi

  echo "== standards: bun test"
  (cd standards && bun install --silent && bun test)

  echo "== standards: ruff"
  (cd standards && uv run --frozen ruff check . && uv run --frozen ruff format --check .)

  echo "== standards: pytest"
  (cd standards && uv run --frozen pytest tests/py -q)
fi

# Leaves ../.github-tags/std-v0.1.0 in place on purpose for reuse.
echo "== ensure-tag.sh: create, reuse, refuse-unknown"
FIRST_PATH="$(bash standards/bin/ensure-tag.sh std-v0.1.0)"
SECOND_PATH="$(bash standards/bin/ensure-tag.sh std-v0.1.0)"
if [ "$FIRST_PATH" != "$SECOND_PATH" ] || [ ! -d "$FIRST_PATH" ]; then
  echo "ensure-tag.sh did not reuse the worktree it just created ($FIRST_PATH vs $SECOND_PATH)"
  exit 1
fi
if bash standards/bin/ensure-tag.sh this-tag-does-not-exist >/dev/null 2>&1; then
  echo "ensure-tag.sh accepted an unknown tag; it must refuse"
  exit 1
fi

echo "== standards: prose-lint.sh self-test"
bash standards/bin/prose-lint.test.sh

echo "== plugin: bun test"
bun test plugin/skills/status-dashboard/parse-backlog.test.ts

echo "== standards core (local)"
bash standards/bin/check-core.sh "$(pwd)"

echo "== all checks passed"
