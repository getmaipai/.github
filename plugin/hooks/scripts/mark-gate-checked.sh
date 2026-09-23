#!/usr/bin/env bash
# PostToolUse (Bash matcher): stamps the flag file
# require-gate-before-commit.sh checks, whenever `scripts/check.sh` runs
# to completion (exit 0). PostToolUse only fires on success - a failing
# run fires PostToolUseFailure instead, which this hook doesn't match,
# so a red gate simply never stamps (the same honesty level
# mark-review-checked.sh already has for "did it run" versus "did it
# pass": here the two collapse into one signal, since PostToolUse itself
# is the pass signal). Belt and suspenders: an explicit exit-code check
# below too, in case that assumption is ever wrong for some tool variant.
#
# Unlike a boolean flag, the stamp's own content is the scope the run
# actually covered (`docs`/`frontend`/`backend`/`full`, GATE-SCOPE-01's
# own first output line, `== scope: <word> (<why>)`) - a scoped gate run
# only proves the stages IT covered are green, not every stage, so
# require-gate-before-commit.sh has to know which one this was to judge
# whether it actually covers the commit about to happen.
#
# Stamped per session, not per repo: `<git-dir>/maipai-gate-checked-
# <session_id>`, keyed off the hook payload's own `session_id` (present
# on every hook event). A single shared per-repo file would let one
# concurrent session's own narrower-scoped run (a `--docs` check while
# another session is mid-way through a real change in the same shared
# checkout, a pattern the org's own git workflow explicitly allows)
# silently overwrite a different session's still-valid, wider stamp -
# found live testing this exact hook, not a hypothetical.
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -n "$command" ] || exit 0

# Matches a bare `scripts/check.sh`, `./scripts/check.sh`, `bash
# scripts/check.sh`, or any of those with an absolute or relative
# directory prefix before `scripts/check.sh` (`bash /Users/.../home/
# scripts/check.sh` - found live: an earlier, narrower version of this
# regex didn't match that at all, so a genuinely passing gate run never
# got stamped) - but not `cat scripts/check.sh`/`grep ... scripts/
# check.sh ...` (a command whose own leading word isn't `bash`/`sh`/
# `source`/`.`/empty breaks the match, since nothing bridges it to
# `scripts/check.sh`).
if ! echo "$command" | grep -qE '(^|[;&|]|&&)\s*(bash\s+|sh\s+|source\s+|\.\s+)?([A-Za-z0-9_./-]*/)?scripts/check\.sh\b'; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null) || exit 0

session_id=$(echo "$input" | jq -r '.session_id // empty')
[ -n "$session_id" ] || exit 0

# The real field is `tool_response` (a Bash tool's own execa-shaped
# result object: stdout/stderr/exitCode/...), not `tool_result` - found
# live, disassembling the installed Claude Code binary's own Zod schema
# and its Bash-execution object-literal construction, after the docs
# and two independent research passes disagreed with each other and
# with reality. An explicit exit-code check here is the same "belt and
# suspenders" the top comment already promises: PostToolUse firing at
# all should already mean success, this just doesn't trust that alone.
exit_code=$(echo "$input" | jq -r '.tool_response.exitCode // .tool_response.code // 0')
[ "$exit_code" = "0" ] || exit 0

output=$(echo "$input" | jq -r '.tool_response.stdout // empty')
scope=$(echo "$output" | sed -n 's/^== scope: \([a-z]*\).*/\1/p' | head -1)

if [ -z "$scope" ]; then
  # No scope line at all: either this repo predates GATE-SCOPE-01 (every
  # check.sh run there covers everything, so `full` is correct), or it
  # postdates the org's scoped-gates rule but hasn't adopted a
  # gateScope.ts-style split yet and only supports the universal
  # `--docs`/full contract (every repo's check.sh, per the org rule) -
  # in that case a `--docs` invocation genuinely only ran the fast
  # standards-core path, and stamping it `full` would be a false pass
  # for any later commit touching real code (found live: bot's, stack's
  # and commons's own check.sh support --docs but print no scope line
  # at all, unlike home's).
  if echo "$command" | grep -qE -- '--docs\b'; then
    scope="docs"
  else
    scope="full"
  fi
fi

echo "$scope" > "$git_dir/maipai-gate-checked-$session_id" 2>/dev/null || true
exit 0
