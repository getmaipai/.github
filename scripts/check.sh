#!/usr/bin/env bash
# .github pre-commit gate. This repo hosts @maipai/standards itself, so it
# calls the core directly rather than through a sibling checkout.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== standards core (local)"
bash standards/bin/check-core.sh "$(pwd)"

echo "== all checks passed"
