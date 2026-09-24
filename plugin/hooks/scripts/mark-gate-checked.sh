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
#
# GATE-HOOK-02 (the org's own "gate per push, not per commit" rule): the
# stamp also carries enough to prove which exact file CONTENT the gate
# covered, not just that a gate of some scope ran - two commits from the
# same unchanged tree both have to go through on one stamp, but an edit
# to a tracked file after the stamp has to invalidate it for that file.
# Line 2 is `HEAD` at stamp time; every line after is one dirty tracked
# file's own working-tree blob hash, `<blob-hash>\t<path>`, one per
# `git diff --name-only HEAD` path, each hashed with `git hash-object`
# (found live: `git diff --raw HEAD`'s own new-blob-hash column reads
# all-zeros for the working-tree side of an uncommitted change - a
# raw diff only ever computes a real hash for a tree or the index,
# never for a file git hasn't been asked to store yet - so that field
# can't stand in for the real content hash the way it can for a
# `--cached` diff). A file absent from this manifest was clean
# (matched HEAD) at stamp time; require-gate-before-commit.sh compares
# each committed file against whichever of the two that implies.
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
repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0

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

# `git rev-parse HEAD` prints the literal word "HEAD" to stdout before
# failing on an unborn branch (no commit yet), so a `2>/dev/null ||
# echo ""` fallback here would capture "HEAD" itself, not empty (the
# same stdout-leak-on-failure shape require-gate-before-commit.sh's
# own $gate_head/$expected_hash reads already work around) - the
# explicit failure branch below is what actually clears it.
if ! gate_head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null); then
  gate_head=""
fi
zero_hash="0000000000000000000000000000000000000000"

{
  echo "$scope"
  echo "$gate_head"
  # Untracked files never appear here (`git diff --name-only HEAD` only
  # ever compares tracked content) - a brand-new file staged after the
  # stamp has no manifest entry AND no HEAD blob, which the requiring
  # hook reads as "new, ungated content," the correct call. A path
  # already deleted from the working tree at stamp time hashes as the
  # same zero sentinel `git diff --raw`'s own `D` status uses, so a
  # pre-gated deletion committed later in an unchanged tree still
  # compares equal there, never a false deny.
  git -C "$repo_root" diff --name-only HEAD -- 2>/dev/null | while IFS= read -r f; do
    [ -n "$f" ] || continue
    # `-e` alone follows a symlink to its target and reads false for a
    # DANGLING one (found live: a tracked dangling symlink's own
    # content - the target string - hashed as the zero "deleted"
    # sentinel regardless of what it actually pointed to, collapsing
    # every retarget into one value); `-L` catches the link itself. A
    # symlink's own git-stored content is its target string, never
    # what it points to, so it can't go through plain `git hash-object
    # -- <path>` either (found live: that opens the TARGET file, which
    # is exactly the file that doesn't exist for a dangling link) -
    # `readlink` plus `git hash-object --stdin` is what actually
    # matches the blob git itself would store (verified against `git
    # cat-file -p HEAD:<path>` on a real tracked symlink).
    if [ -L "$repo_root/$f" ]; then
      h=$(readlink -n "$repo_root/$f" 2>/dev/null | git -C "$repo_root" hash-object --stdin 2>/dev/null || echo "$zero_hash")
    elif [ -e "$repo_root/$f" ]; then
      h=$(git -C "$repo_root" hash-object -- "$f" 2>/dev/null || echo "$zero_hash")
    else
      h="$zero_hash"
    fi
    printf '%s\t%s\n' "$h" "$f"
  done
} > "$git_dir/maipai-gate-checked-$session_id" 2>/dev/null || true
exit 0
