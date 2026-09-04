#!/usr/bin/env bash
# PostToolUse (Bash matcher): after a real git status/diff --stat check
# runs, stamp a per-repo flag file so block-blind-staging.sh knows a
# review just happened. Never blocks; always exits 0.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -n "$command" ] || exit 0

if ! echo "$command" | grep -qE '(^|[;&|]|&&)\s*git\s+(status\b|diff\s+--stat\b)'; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null) || exit 0
touch "$git_dir/maipai-status-checked" 2>/dev/null || true
exit 0
