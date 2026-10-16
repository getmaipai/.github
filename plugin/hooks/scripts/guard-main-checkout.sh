#!/usr/bin/env bash
# PreToolUse (Bash matcher): MAIN-CHECKOUT-01. A repo's main checkout (the folder that holds the
# real .git) belongs to scripts/wt.sh: sessions work in their own worktrees. This hook denies
# the git commands that move a main checkout's branch, history, remote or worktree list
# (rebase, reset, checkout, switch, merge, pull, worktree add, remote set-url, force push),
# the way a wrong origin and a lane left on a main checkout went unnoticed on 2026-10-15.
# Deterministic: no network, no model, writes nothing. It reads the directory from `git -C <dir>`
# when present, else the tool call's cwd; a `cd dir && git ...` chain is judged by the cwd only.
# Owner-approved exception: put MAIPAI_ALLOW_MAIN_CHECKOUT=1 in the command.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -n "$command" ] || exit 0
echo "$command" | grep -qE 'MAIPAI_ALLOW_MAIN_CHECKOUT=1' && exit 0

verbs='(rebase|reset|checkout|switch|merge|pull|worktree[[:space:]]+add|remote[[:space:]]+set-url|push[[:space:]].*(--force|--force-with-lease|[[:space:]]-f)([[:space:]]|$))'
echo "$command" | grep -qE "(^|[;&|]|&&)[[:space:]]*git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+$verbs" || exit 0

dir=$(echo "$command" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+("([^"]+)"|([^[:space:]]+)).*/\2\3/p' | head -1)
[ -n "$dir" ] || dir=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$dir" ] || dir="$PWD"
case "$dir" in "~"*) dir="$HOME${dir#\~}";; esac
[ -d "$dir" ] || exit 0

top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || exit 0
case "$common" in /*) ;; *) common="$(cd "$dir/$common" && pwd)" ;; esac
main=$(cd "$common/.." && pwd -P)
top=$(cd "$top" && pwd -P)
[ "$top" = "$main" ] || exit 0
case "$main" in */getmaipai/*) ;; *) exit 0 ;; esac

repo=$(basename "$main")
jq -n --arg reason "This is the main checkout of $repo ($main); only scripts/wt.sh changes it. Do the work in your own worktree: MAIPAI_WT_SESSION=<name> bash scripts/wt.sh start <slug>. If Jesse approved this exact change, put MAIPAI_ALLOW_MAIN_CHECKOUT=1 in the command." '{decision: "deny", reason: $reason}' >&2
exit 2
