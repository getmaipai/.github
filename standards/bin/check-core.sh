#!/usr/bin/env bash
# @maipai/standards std-v0.1.0 - shared check.sh core.
#
# Pinned by every getmaipai repo's scripts/check.sh (called after the repo's
# own build/lint/test steps). Runs the checks that are the same everywhere:
# gitleaks, the PII wordlist scan, the prose lint, and the licence check.
# Every category runs even if an earlier one fails, so one commit shows
# every problem at once; the exit code is non-zero if any category failed.
#
# Usage: bash <path-to-this-file> <repo-root>
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-.}"
cd "$REPO_ROOT"

STATUS=0

echo "== standards: gitleaks"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks dir --no-banner --redact . && gitleaks git --no-banner --redact .
  if [ $? -ne 0 ]; then
    echo "gitleaks found problems"
    STATUS=1
  fi
else
  echo "WARN: gitleaks not installed (brew install gitleaks)"
fi

echo "== standards: PII wordlist"
bash "$HERE/pii-scan.sh" "$REPO_ROOT" || STATUS=1

echo "== standards: prose lint"
bash "$HERE/prose-lint.sh" "$REPO_ROOT" || STATUS=1

echo "== standards: licence check"
bash "$HERE/licence-check.sh" "$REPO_ROOT" || STATUS=1

if [ "$STATUS" -eq 0 ]; then
  echo "== standards core passed (std-v0.1.0)"
else
  echo "== standards core FAILED (std-v0.1.0)"
fi

exit "$STATUS"
