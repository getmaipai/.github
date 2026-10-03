#!/usr/bin/env bash
# Item claims, so two lanes (or two coordinator sessions) never get
# dispatched onto the same work, and so a session that finds unclaimed,
# uncommitted work in a shared checkout has one cheap place to check
# whose it is instead of a round of cross-session messages (docs/COORDINATION.md
# "Roles", coordinate SKILL.md section 1a).
#
# Usage:
#   claim.sh new   <repo> <item> <owner> <lane> [worktree]
#   claim.sh check <repo> <item>
#   claim.sh clear <repo> <item> <owner>
#   claim.sh list  <repo>
#
# <repo> is the repo root (claims live at
# <repo>/data-scratch/claims/<item>.claim). <lane> is "agent", "codex",
# "opencode", or "session" (a terminal Jesse opened himself).
set -euo pipefail

cmd="${1:?usage: claim.sh new|check|clear|list <repo> ...}"
repo="${2:?repo path}"
dir="$repo/data-scratch/claims"
mkdir -p "$dir"

case "$cmd" in
  list)
    shopt -s nullglob
    files=("$dir"/*.claim)
    if [ ${#files[@]} -eq 0 ]; then
      echo "no active claims"
    else
      for f in "${files[@]}"; do
        printf '%s\t%s\n' "$(basename "$f" .claim)" "$(cat "$f")"
      done
    fi
    ;;
  check)
    item="${3:?item id}"
    f="$dir/$item.claim"
    if [ -f "$f" ]; then cat "$f"; else echo "unclaimed"; fi
    ;;
  new)
    item="${3:?item id}"
    owner="${4:?owner name}"
    lane="${5:?lane (agent|codex|opencode|session)}"
    worktree="${6:-}"
    f="$dir/$item.claim"
    content="$(printf '%s\t%s\t%s\t%s' "$owner" "$lane" "$worktree" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
    # Atomic create: noclobber makes this redirect fail (not overwrite)
    # if the claim already exists, closing the check-then-write race
    # two coordinators claiming the same item at once would otherwise
    # hit (both pass "not present" before either writes).
    if (set -o noclobber; printf '%s\n' "$content" > "$f") 2>/dev/null; then
      echo "claimed"
      exit 0
    fi
    echo "already claimed: $(cat "$f")" >&2
    exit 1
    ;;
  clear)
    item="${3:?item id}"
    owner="${4:?owner name}"
    f="$dir/$item.claim"
    if [ -f "$f" ]; then
      current="$(cut -f1 "$f")"
      if [ "$current" != "$owner" ]; then
        echo "refused: claimed by $current, not $owner" >&2
        exit 1
      fi
      rm -f "$f"
    fi
    echo "cleared"
    ;;
  *)
    echo "usage: claim.sh new|check|clear|list <repo> ..." >&2
    exit 2
    ;;
esac
