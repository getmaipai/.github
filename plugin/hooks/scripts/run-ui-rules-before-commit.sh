#!/usr/bin/env bash
# PreToolUse (Bash matcher): PRECOMMIT-RULES-01. Before a `git commit` in a
# repo that ships scripts/ui-rules-precommit.sh (Home), runs that script on
# what is already staged, so a Claude or Codex session hears about an
# Elements/UI rule violation (className override on a kit part, a new
# wrapper, a grown baseline, a missing ledger reason) in about a second
# instead of at the gate. Deterministic: no network, no model, writes
# nothing. The repo script exits at once when no staged file can matter.
# Skip: MAIPAI_SKIP_UI_RULES=1 in the environment; scripts/check.sh ignores
# it, so a skipped commit still cannot pass the gate.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -n "$command" ] || exit 0
echo "$command" | grep -qE '(^|[;&|]|&&)\s*git\s+commit\b' || exit 0
echo "$command" | grep -qE -- '--amend\b' && exit 0
echo "$command" | grep -qE 'MAIPAI_SKIP_UI_RULES=1' && exit 0

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$root/scripts/ui-rules-precommit.sh" ] || exit 0

if out=$(cd "$root" && bash scripts/ui-rules-precommit.sh 2>&1); then
  exit 0
fi
jq -n --arg reason "$out" '{decision: "deny", reason: $reason}' >&2
exit 2
