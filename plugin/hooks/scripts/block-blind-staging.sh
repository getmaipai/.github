#!/usr/bin/env bash
# PreToolUse (Bash matcher): refuses a blind "stage everything" command
# (git add -A/--all, bare git add ., git commit -a/--all) unless git status
# was run in this repo within the last 15 minutes. The org rule (CLAUDE.md
# > Git workflow) is to stage specific files after reviewing status, not to
# never use git add -A; this hook enforces the "after reviewing" part, not
# a blanket ban, so it only blocks when there is no recent status check to
# point to.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -n "$command" ] || exit 0

# commit's -a can combine with other short flags (-am, -av, -avm...), so
# match any short-flag cluster containing "a", not just a bare "-a".
if ! echo "$command" | grep -qE '(^|[;&|]|&&)\s*git\s+(add\s+(-A\b|--all\b|\.\s*$|\.\s*[;&|])|commit\s+(-[a-zA-Z]*a[a-zA-Z]*\b|--all\b))'; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null) || exit 0
flag_file="$git_dir/maipai-status-checked"

if [ -f "$flag_file" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$flag_file" 2>/dev/null || stat -c %Y "$flag_file" 2>/dev/null) ))
  if [ "$age" -lt 900 ]; then
    exit 0
  fi
fi

reason="Run git status first (or git diff --stat for a staged look), review what will actually be included, then stage specific files by name. A blind git add -A, git add ., or git commit -a with no recent git status in this session risks picking up in-progress work from another session in a shared checkout, or staging something that should stay out. This is a soft gate: run git status and the same command will go through."
jq -n --arg reason "$reason" '{decision: "deny", reason: $reason}' >&2
exit 2
