#!/usr/bin/env bash
# Lane lock for a Codex or OpenCode target shared across coordinator
# sessions (CLAUDE.md "Roles", coordinate SKILL.md section 1a). Neither
# Codex nor OpenCode has a per-caller identity ListAgents can show, so
# this is the registry that answers "who is driving this lane right
# now" in one cheap read instead of a cross-session message round trip.
#
# Usage:
#   lane-lock.sh acquire <repo> <lane> <coordinator> <item>
#   lane-lock.sh release <repo> <lane> <coordinator>
#   lane-lock.sh status  <repo> <lane>
#
# <repo> is the repo root (the lock lives at
# <repo>/data-scratch/lane-locks/<lane>.lock, already covered by that
# repo's data-* gitignore rule). <lane> is "codex" or "opencode".
set -euo pipefail

cmd="${1:?usage: lane-lock.sh acquire|release|status <repo> <lane> [coordinator] [item]}"
repo="${2:?repo path}"
lane="${3:?lane name (codex|opencode)}"
dir="$repo/data-scratch/lane-locks"
lock="$dir/$lane.lock"
mkdir -p "$dir"

case "$cmd" in
  status)
    if [ -f "$lock" ]; then cat "$lock"; else echo "free"; fi
    ;;
  acquire)
    coordinator="${4:?coordinator name}"
    item="${5:?item id}"
    content="$(printf '%s\t%s\t%s' "$coordinator" "$item" "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
    # Atomic create: noclobber makes this redirect fail (not overwrite)
    # if the lock already exists, closing the check-then-write race two
    # coordinators acquiring at the same instant would otherwise hit.
    if (set -o noclobber; printf '%s\n' "$content" > "$lock") 2>/dev/null; then
      echo "acquired"
      exit 0
    fi
    owner="$(cut -f1 "$lock" 2>/dev/null || true)"
    if [ "$owner" = "$coordinator" ]; then
      printf '%s\n' "$content" > "$lock"
      echo "acquired"
      exit 0
    fi
    echo "held by $owner: $(cat "$lock")" >&2
    exit 1
    ;;
  release)
    coordinator="${4:?coordinator name}"
    if [ -f "$lock" ]; then
      owner="$(cut -f1 "$lock")"
      if [ "$owner" != "$coordinator" ]; then
        echo "refused: held by $owner, not $coordinator" >&2
        exit 1
      fi
      rm -f "$lock"
    fi
    echo "released"
    ;;
  *)
    echo "usage: lane-lock.sh acquire|release|status <repo> <lane> [coordinator] [item]" >&2
    exit 2
    ;;
esac
