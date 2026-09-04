#!/usr/bin/env bash
# SessionStart: if the session opens inside a git repo, surface the branch,
# dirty file count, and (if this repo has one) the open-checklist count from
# docs/dev.md, so leftover state from a prior session is visible immediately
# instead of discovered mid-task.
set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0

branch=$(git -C "$repo_root" branch --show-current 2>/dev/null || echo "detached HEAD")
dirty=$(git -C "$repo_root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

ahead_behind=""
if upstream=$(git -C "$repo_root" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null); then
  counts=$(git -C "$repo_root" rev-list --left-right --count "$upstream"...HEAD 2>/dev/null || echo "0 0")
  behind=$(echo "$counts" | awk '{print $1}')
  ahead=$(echo "$counts" | awk '{print $2}')
  if [ "$ahead" != "0" ] || [ "$behind" != "0" ]; then
    ahead_behind=", ${ahead} ahead / ${behind} behind ${upstream}"
  fi
fi

open_items=""
if [ -f "$repo_root/docs/dev.md" ]; then
  count=$(grep -c '^\s*- \[ \]' "$repo_root/docs/dev.md" 2>/dev/null || echo 0)
  if [ "$count" -gt 0 ]; then
    open_items=". docs/dev.md has ${count} open checklist item(s)"
  fi
fi

echo "Repo: $(basename "$repo_root") on branch ${branch}${ahead_behind}, ${dirty} file(s) dirty${open_items}."
