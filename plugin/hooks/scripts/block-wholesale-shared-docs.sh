#!/usr/bin/env bash
# PreToolUse (Bash matcher): refuses a wholesale `git add` of the two shared
# doc files, docs/dev.md and docs/BACKLOG.md, in any repo. When two sessions
# work in one checkout they both append to those files, and a plain add
# sweeps the other session's unstaged hunks into your commit (it happened
# three times on 2026-09-13). Stage them with `git add -p` (or `-e`,
# `--patch`, `--interactive`) so only your own hunks go in. Any other file
# is untouched by this hook.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -n "$command" ] || exit 0

# Only git add commands naming one of the shared docs.
echo "$command" | grep -qE '(^|[;&|]|&&)\s*git\s+add\b' || exit 0
echo "$command" | grep -qE 'docs/(dev|BACKLOG)\.md' || exit 0

# Patch, edit or interactive modes stage hunks, not whole files: allowed.
echo "$command" | grep -qE 'git\s+add\s+[^;&|]*(-p\b|--patch\b|-e\b|--edit\b|-i\b|--interactive\b)' && exit 0

reason="docs/dev.md and docs/BACKLOG.md are shared between sessions: stage only your own hunks with git add -p <file> (never a plain git add of the whole file), then check git diff --cached for lines that are not yours."
jq -n --arg reason "$reason" '{decision: "deny", reason: $reason}' >&2
exit 2
