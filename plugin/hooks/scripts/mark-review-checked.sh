#!/usr/bin/env bash
# PostToolUse (Skill matcher): stamps the flag file
# require-review-before-commit.sh checks, whenever the `code-review`
# skill is invoked.
#
# NOT ReportFindings: the first version of this hook matched
# ReportFindings, on the assumption the code-review skill reports through
# it. A code review of THIS hook (2026-09-04) caught that wrong: when
# code-review runs as a forked/background agent (the normal way an agent
# session invokes it), its own loaded instructions explicitly say not to
# call ReportFindings, and to return a JSON block as the result instead.
# ReportFindings is for an interactive foreground run rendering into the
# host UI, which is not how this hook needs to observe it.
#
# Honesty about what this proves: it stamps at *invocation*, not at
# "findings were read and addressed" — there is no tool call available to
# hook that fires only once a multi-agent review's parallel findings have
# all landed (those arrive as task-notifications, not tool calls). This is
# the same honesty level as mark-git-status-checked.sh: proof the check
# ran recently, not proof its output was acted on. Never blocks.
set -euo pipefail

input=$(cat)
skill=$(echo "$input" | jq -r '.tool_input.skill // empty')

case "$skill" in
  code-review|*:code-review) ;;
  *) exit 0 ;;
esac

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null) || exit 0
touch "$git_dir/maipai-review-checked" 2>/dev/null || true
exit 0
