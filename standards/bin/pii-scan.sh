#!/usr/bin/env bash
# @maipai/standards: PII wordlist scan.
#
# Scans tracked files plus the working tree (staged, unstaged, untracked)
# against the private wordlist at ~/.config/maipai/pii-words.txt. That file
# is never committed anywhere; a repo without it just warns and passes, so a
# fresh machine does not fail check.sh before the wordlist is set up.
set -euo pipefail
REPO_ROOT="${1:-.}"
cd "$REPO_ROOT"

WORDS="$HOME/.config/maipai/pii-words.txt"
if [ ! -f "$WORDS" ]; then
  echo "WARN: no PII wordlist at $WORDS"
  exit 0
fi

PATTERN=$(grep -v '^#' "$WORDS" | grep -v '^$' | paste -sd'|' -)
if [ -z "$PATTERN" ]; then
  exit 0
fi

STATUS=0

HITS=$(git grep -inwE "$PATTERN" -- ':!*.lock' 2>/dev/null || true)
if [ -n "$HITS" ]; then
  echo "PII wordlist hits (tracked files):"
  echo "$HITS"
  STATUS=1
fi

UHITS=$( (git ls-files --others --exclude-standard; git diff --name-only) | sort -u \
  | grep -v '\.lock$' | xargs -r grep -inwE "$PATTERN" 2>/dev/null || true)
if [ -n "$UHITS" ]; then
  echo "PII wordlist hits (working tree):"
  echo "$UHITS"
  STATUS=1
fi

exit $STATUS
