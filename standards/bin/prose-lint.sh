#!/usr/bin/env bash
# @maipai/standards: prose lint.
#
# Enforces the org's AI writing standards (CLAUDE.md > Writing style) against
# every tracked Markdown file: no em dashes, no AI filler vocabulary, no
# "not just X, it's Y" constructions, no exclamation points outside fenced
# or inline code or an HTML comment. Exits non-zero on any hit.
#
# A line that ends with the literal marker `<!-- prose-lint: allow -->` is
# exempt from every check on this file. Use it only for a line that names a
# banned construct as documentation of the rule itself (a style guide has to
# say the words it bans); never to silence an actual violation.
#
# The line-scanning state machine (fenced blocks, inline code spans, HTML
# comments, the four checks) lives in prose-lint.awk: a pure-bash version of
# the same logic (nested `while` loops of parameter expansion per character,
# across every line of every file) took over a minute on this org's own
# docs/dev.md files, a real per-commit cost paid by every repo. awk does the
# identical job in a fraction of a second.
set -uo pipefail
REPO_ROOT="${1:-.}"
cd "$REPO_ROOT"

ALLOW_MARKER='<!-- prose-lint: allow -->'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# An array, not word-split command substitution: a tracked filename could
# in principle contain a space (bash 3.2 has no `mapfile`, hence the
# read loop rather than `readarray`).
files=()
while IFS= read -r f; do
  [ -n "$f" ] && files+=("$f")
done < <(git ls-files '*.md' 2>/dev/null)
[ "${#files[@]}" -gt 0 ] || exit 0

awk -v allow_marker="$ALLOW_MARKER" -f "$SCRIPT_DIR/prose-lint.awk" "${files[@]}"
