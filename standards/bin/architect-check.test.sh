#!/usr/bin/env bash
# Regression test for architect-check.sh: a throwaway git repo per case,
# one clean pass and one case per failure.
set -uo pipefail
cd "$(dirname "$0")/../.."
CHECK="$(pwd)/standards/bin/architect-check.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FAIL=0

# new_repo <name>: a repo with one good area and its record.
new_repo() {
  local d="$TMP/$1"
  mkdir -p "$d/docs/design" "$d/docs/plans"
  cat > "$d/docs/design/RULES.md" <<'R'
# Design rules

## Chat turn

Record: [the chat path](../plans/chat.md), accepted 2026-10-02.
Governs: backend/chat/**

1. A rule.
R
  printf '# Chat\n\n## Supersedes\n\nNothing.\n' > "$d/docs/plans/chat.md"
  (cd "$d" && git init -q && git add -A)
  echo "$d"
}

# expect <desc> <exit> <substring> <repo>
expect() {
  local out code
  out=$(bash "$CHECK" "$4" 2>&1); code=$?
  if [ "$code" -ne "$2" ] || ! printf '%s' "$out" | grep -qF -- "$3"; then
    echo "FAIL: $1 (exit $code, wanted $2, wanted text: $3)"
    echo "$out"
    FAIL=1
  fi
}

d=$(new_repo clean)
expect "clean repo passes" 0 "consistent" "$d"

d="$TMP/norules"; mkdir -p "$d"; (cd "$d" && git init -q)
expect "repo without RULES.md passes untouched" 0 "nothing to check" "$d"

d="$TMP/norules-marker"; mkdir -p "$d/docs"; (cd "$d" && git init -q)
printf '# Old\n\n> **Superseded 2026-10-01** by [the chat path](nope.md).\n' > "$d/docs/old.md"
(cd "$d" && git add -A)
expect "markers but no RULES.md still checks the markers" 1 "docs/old.md:3" "$d"

d=$(new_repo norecord)
printf '\n## Memory\n\nA rule with no record.\n' >> "$d/docs/design/RULES.md"
expect "area without a Record line fails" 1 'area "Memory" names no design record' "$d"

d=$(new_repo missing)
sed -i.bak 's#chat.md#gone.md#' "$d/docs/design/RULES.md"; rm "$d/docs/design/RULES.md.bak"
expect "record file that does not exist fails" 1 "does not exist: ../plans/gone.md" "$d"

d=$(new_repo nosuper)
printf '# Chat\n\nNo heading.\n' > "$d/docs/plans/chat.md"
expect "record without a Supersedes heading fails" 1 "no '## Supersedes' heading" "$d"

d=$(new_repo badmarker)
printf '# Old\n\n> **Superseded 2026-10-01** by [the chat path](nope.md).\n' > "$d/docs/old.md"
(cd "$d" && git add -A)
expect "Superseded marker to a missing file fails" 1 "docs/old.md:3" "$d"

d=$(new_repo nolink)
printf '# Old\n\n> **Superseded 2026-10-01** and gone.\n' > "$d/docs/old.md"
(cd "$d" && git add -A)
expect "Superseded marker with no link fails" 1 "links to nothing" "$d"

d=$(new_repo goodmarker)
printf '# Old\n\n> **Superseded 2026-10-01** by [the chat path](plans/chat.md).\n' > "$d/docs/old.md"
(cd "$d" && git add -A)
expect "Superseded marker to an existing file passes" 0 "consistent" "$d"

[ "$FAIL" -eq 0 ] && echo "architect-check self-test passed"
exit "$FAIL"
