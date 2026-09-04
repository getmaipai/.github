#!/usr/bin/env bash
# .github pre-commit gate. This repo hosts @maipai/standards itself, so it
# calls the core directly rather than through a sibling checkout.
set -euo pipefail
cd "$(dirname "$0")/.."

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
  (cd standards && uv run ruff check . && uv run ruff format --check .)

  echo "== standards: pytest"
  (cd standards && uv run pytest tests/py -q)
fi

echo "== standards core (local)"
bash standards/bin/check-core.sh "$(pwd)"

echo "== all checks passed"
