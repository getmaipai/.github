#!/usr/bin/env bash
# PreToolUse (Bash matcher): refuses a `git commit` that touches code
# (not just docs) unless the `code-review` skill has run in this repo
# within the last 30 minutes. Jesse's rule (2026-09-04): relying on a
# session "remembering" to review its own work doesn't survive a fresh
# session, so this is enforced the same mechanical way as
# block-blind-staging.sh, not left to memory. Soft gate: run /code-review,
# address what it finds, and the same commit goes through.
#
# This proves the review was *invoked* recently (see
# mark-review-checked.sh), not that its findings were read and addressed
# — there is no tool call to hook that fires only once a multi-agent
# review's findings have all landed. Same honesty level as
# block-blind-staging.sh's own guarantee.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -n "$command" ] || exit 0

if ! echo "$command" | grep -qE '(^|[;&|]|&&)\s*git\s+commit\b'; then
  exit 0
fi

# --amend repeats history rather than adding new, unreviewed work; a bare
# `git commit` with nothing to commit will fail on its own anyway. Only
# gate a real new commit.
if echo "$command" | grep -qE -- '--amend\b'; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null) || exit 0

# `git commit -a`/`--all`/an `-a`-cluster (-am, -av...) stages tracked
# working-tree changes AT commit time, not before: a first cut of this
# hook checked only `--cached` and a `git commit -am` with nothing
# pre-staged sailed through with an empty diff every time (caught by a
# code review of this very hook). Match the same flag-cluster regex
# block-blind-staging.sh uses, and fold in unstaged tracked changes when
# it's present.
files=$(git -C "$cwd" diff --cached --name-only 2>/dev/null || true)
if echo "$command" | grep -qE 'git\s+commit\s+(-[a-zA-Z]*a[a-zA-Z]*\b|--all\b)'; then
  files="$files
$(git -C "$cwd" diff --name-only 2>/dev/null || true)"
fi
files=$(echo "$files" | grep -v '^$' || true)

# Doc-only commits (a CHANGELOG entry, a dev.md note, a README tweak)
# don't need a code review. Anything else touched trips the gate.
[ -n "$files" ] || exit 0
if ! echo "$files" | grep -qvE '\.md$|^LICENSE$|^NOTICE$'; then
  exit 0
fi

flag_file="$git_dir/maipai-review-checked"

if [ -f "$flag_file" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$flag_file" 2>/dev/null || stat -c %Y "$flag_file" 2>/dev/null) ))
  if [ "$age" -lt 1800 ]; then
    exit 0
  fi
fi

reason="This commit touches code and no code-review run is on record for this repo in the last 30 minutes. Run the code-review skill (at least medium effort) against the diff, address what it finds, then retry this commit. This is a soft gate: once code-review runs, the same commit goes through."
jq -n --arg reason "$reason" '{decision: "deny", reason: $reason}' >&2
exit 2
