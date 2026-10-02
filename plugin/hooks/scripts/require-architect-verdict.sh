#!/usr/bin/env bash
# PreToolUse (Bash matcher): the architect gate (ARCH-GATE-01, 2026-10-02).
# In a repo that keeps docs/design/RULES.md, refuses a `git commit` that
# touches the design surface (docs/design/**, docs/plans/**,
# docs/BACKLOG.md, or any path an area's `Governs:` glob in RULES.md names)
# unless the architect agent has ruled APPROVED on it within 24 hours:
# a record in <repo>/data-scratch/architect/<ITEM-ID>.verdict whose item id
# appears in the commit message, or whose sha256 matches the staged diff.
# A commit that edits RULES.md itself needs `Owner-approved: <date>` in its
# message, because only the owner changes a rule. Soft gate: every denial
# names the exact next step. No-op in a repo without docs/design/RULES.md.
# See docs/ARCHITECT.md.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -n "$command" ] || exit 0

# Detect a commit on the command with quoted spans emptied out, so a
# message that says "git commit" or "--amend" is not mistaken for a flag.
# Heredoc bodies are dropped first and quotes are emptied across newlines,
# so a multi-line message cannot smuggle a flag past the check.
bare=$(echo "$command" | awk '
  skip != "" { if ($0 ~ "^[[:space:]]*" skip "[[:space:]]*$") skip = ""; next }
  { print }
  match($0, /<<-?[[:space:]]*["\x27]?[A-Za-z_][A-Za-z0-9_]*/) && substr($0, RSTART - 1, 1) != "<" {
    t = substr($0, RSTART, RLENGTH); sub(/^<<-?[[:space:]]*["\x27]?/, "", t); skip = t
  }' | perl -0pe 's/"[^"]*"/""/g; s/\x27[^\x27]*\x27/\x27\x27/g')
echo "$bare" | grep -qE '(^|[;&|]|&&)[[:space:]]*git[[:space:]]([^;&|]*[[:space:]])?commit([[:space:]]|$)' || exit 0
echo "$bare" | grep -qE -- '--amend\b' && exit 0

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

# Resolve the repo the commit really targets: `git -C <dir>` or `cd <dir> &&`.
target=$(echo "$command" | sed -nE "s/.*git[[:space:]]+-C[[:space:]]+[\"']?([^\"'[:space:];&|]+).*/\1/p" | head -1)
[ -n "$target" ] || target=$(echo "$command" | sed -nE "s/(^|.*[;&|[:space:]])cd[[:space:]]+[\"']?([^\"'[:space:];&|]+)[\"']?[[:space:]]*&&.*/\2/p" | head -1)
if [ -n "$target" ]; then
  target="${target/#\$HOME/$HOME}"
  case "$target" in "~"|"~/"*) target="$HOME${target#\~}" ;; esac
  case "$target" in /*) cand="$target" ;; *) cand="$cwd/$target" ;; esac
  [ -d "$cand" ] && cwd="$cand"
fi

top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
rules="$top/docs/design/RULES.md"
[ -f "$rules" ] || exit 0

files=$(git -C "$cwd" diff --cached --name-only 2>/dev/null || true)
if echo "$bare" | grep -qE 'commit([[:space:]]+[^;&|]*)?[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)'; then
  files="$files
$(git -C "$cwd" diff --name-only 2>/dev/null || true)"
fi
files=$(echo "$files" | grep -v '^$' | sort -u || true)
[ -n "$files" ] || exit 0

deny() {
  jq -n --arg reason "$1" '{decision: "deny", reason: $reason}' >&2
  exit 2
}

# A `Governs:` glob to an anchored regex: ** crosses directories, * does not.
glob_to_regex() {
  printf '%s' "$1" | sed -E 's/[.+^$(){}|]/\\&/g; s/\*\*\//@DSD@/g; s/\*\*/@DS@/g; s/\*/[^\/]*/g; s/@DSD@/(.*\/)?/g; s/@DS@/.*/g; s/^/^/; s/$/$/'
}

# Rule edits: only the owner changes a rule.
if echo "$files" | grep -qx 'docs/design/RULES.md'; then
  if echo "$command" | grep -qE 'Owner-approved:[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
    exit 0
  fi
  deny "This commit edits docs/design/RULES.md, and only the owner changes a rule. If Jesse approved this change, add a line 'Owner-approved: YYYY-MM-DD' to the commit message and retry. If not, unstage RULES.md (git restore --staged docs/design/RULES.md) and file the change as a NEEDS-RULE-CHANGE request to the owner. This is a soft gate: the owner line makes the same commit go through."
fi

governed=""
globs=$(sed -nE 's/^Governs:[[:space:]]*(.*)$/\1/p' "$rules" | tr ',' '\n' | sed -E 's/^[[:space:]`]+//; s/[[:space:]`]+$//' | grep -v '^$' || true)
while IFS= read -r f; do
  case "$f" in
    docs/design/*|docs/plans/*|docs/BACKLOG.md) governed="$f"; break ;;
  esac
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    if echo "$f" | grep -qE "$(glob_to_regex "$g")"; then governed="$f"; break 2; fi
  done <<< "$globs"
done <<< "$files"
[ -n "$governed" ] || exit 0

# Look for a verdict: in this worktree's scratch, and the main checkout's.
common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
dirs="$top/data-scratch/architect"
[ -n "$common" ] && dirs="$dirs
$(dirname "$common")/data-scratch/architect"

staged_hash=$(git -C "$cwd" diff --cached 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
now=$(date -u +%s)
seen=""
approved=""
while IFS= read -r d; do
  [ -d "$d" ] || continue
  for v in "$d"/*.verdict; do
    [ -f "$v" ] || continue
    item=$(sed -nE 's/^item:[[:space:]]*(.*)$/\1/p' "$v" | head -1 | tr -d '[:space:]')
    verdict=$(sed -nE 's/^verdict:[[:space:]]*(.*)$/\1/p' "$v" | head -1 | tr -d '[:space:]')
    hash=$(sed -nE 's/^sha256:[[:space:]]*(.*)$/\1/p' "$v" | head -1 | tr -d '[:space:]')
    ts=$(sed -nE 's/^timestamp:[[:space:]]*(.*)$/\1/p' "$v" | head -1 | tr -d '[:space:]')
    [ -n "$item" ] || continue
    item_re=$(printf '%s' "$item" | sed -E 's/[][\.*^$(){}?+|\/]/\\&/g')
    if echo "$command" | grep -qE "(^|[^A-Za-z0-9_-])${item_re}([^A-Za-z0-9_-]|$)" || { [ -n "$hash" ] && [ "$hash" = "$staged_hash" ]; }; then
      epoch=$(date -u -d "$ts" +%s 2>/dev/null || date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo 0)
      if [ $(( now - epoch )) -gt 86400 ]; then
        seen="$seen $item=stale"
      elif [ "$verdict" = "APPROVED" ]; then
        approved="$item"
      else
        seen="$seen $item=$verdict"
      fi
    fi
  done
done <<< "$dirs"
[ -n "$approved" ] && exit 0

if [ -n "$seen" ]; then
  deny "This commit touches the design surface ($governed) and the architect's record is not an APPROVED one under 24 hours old:$seen. REJECTED or DUPLICATE: change the proposal to fit docs/design/RULES.md (or drop it) and dispatch the architect agent again with the item id. NEEDS-RULE-CHANGE: it goes to Jesse, not through this gate. stale: dispatch the architect agent again. This is a soft gate: a fresh APPROVED record and the same commit goes through."
fi
deny "This commit touches the design surface ($governed) and no architect verdict is on record. Dispatch the architect agent (maipai:architect) with the proposal, this repo's path and the item id; it writes data-scratch/architect/<ITEM-ID>.verdict. Put the item id in the commit message, retry, and the same commit goes through on an APPROVED verdict. This is a soft gate."
