#!/usr/bin/env bash
# PreToolUse (Bash matcher): refuses a `git commit` unless `scripts/
# check.sh` has run to completion, in a scope that actually covers what
# is about to be committed, within the last 30 minutes. Same shape and
# same honesty level as require-review-before-commit.sh: this proves
# the gate ran and passed recently, not that nothing has changed since
# (the age window is the same tradeoff that hook already makes). Soft
# gate: run the right scope of check.sh and the same commit goes
# through.
#
# Scope-aware (GATE-SCOPE-01, home's own scripts/gateScope.ts): a
# scoped gate run only proves the stages IT covered are green, so a
# `frontend`-scoped stamp doesn't satisfy a commit that touches
# `backend/`. Where the target repo has `scripts/gateScope.ts` (home,
# today), this hook feeds it exactly the files this commit is about to
# create (--cached, plus the working tree too when -a/--all is in play
# - not check.sh's own compute_scope() working-tree-vs-merge-base diff,
# which in a shared checkout would also pick up a second session's own
# unrelated, still-uncommitted edits and could inflate the required
# scope past what this commit actually touches, found live). The
# frontend-imports-backend escalation this hook feeds it is hardcoded
# to home's own
# `@maipai/home-backend` package name convention (checked live via
# grep): a different repo's own gateScope.ts, if it ever adopts one
# with a differently-named backend package, would need this hook's own
# regex updated too, not something it picks up automatically. Where a
# repo has no gateScope.ts at all (every other repo, until one adopts
# the same split), the only two scopes that exist there in practice are
# `docs` and `full` (every repo's check.sh supports `--docs`, per the
# org rule), so the check falls back to a doc-only-files test matching
# gateScope.ts's own root-docs rule (root-level README/CHANGELOG/AGENTS/
# CLAUDE/LICENSE/NOTICE, or a docs/ path other than docs/api/ - not a
# blanket "any *.md anywhere", which would wrongly treat a bundled
# package's own README.md as a doc the way gateScope.ts's own comment
# explains it never does) - unlike that hook, though, a doc-only commit
# here is NOT exempt from needing a gate at all, only from needing more
# than the fast `--docs` one (the org rule names the docs path as its
# own required, seconds-not-minutes gate, never a full waiver).
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[ -n "$command" ] || exit 0

# "git" then any number of flag(-with-value) tokens (-C <path>,
# --no-pager, -c name=value, ...), then "commit" as its own word -
# catches `git -C <path> commit`/`git --no-pager commit`/`git
# --git-dir=<path> commit`, not just a bare `git commit` (found live:
# the narrower, immediate-adjacency version require-review-before-
# commit.sh already uses lets all of those bypass its own gate too, a
# pre-existing gap this hook doesn't repeat for itself). The
# flag-value character class includes `/` for exactly `--git-dir=/x`/
# `--work-tree=/x` (found live: without it, a `=`-joined flag+path
# token doesn't match at all, and the whole regex fails to recognize
# the command as a commit).
#
# `$command` with every quoted span emptied out (not just cut off after
# the first quote, which would also swallow real flags typed after a
# quoted message, e.g. `git commit -m "msg" -a`) - both this and the
# -a/--all check below scan raw command text, and a commit MESSAGE is
# exactly the kind of free text that can contain "--amend" or "-all"
# as ordinary words rather than real flags (found live).
command_unquoted=$(echo "$command" | sed -E 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g')

commit_re='(^|[;&|]|&&)\s*git(\s+-[A-Za-z0-9=._/-]+(\s+[^ ;&|-][^ ;&|]*)?)*\s+commit\b'
if ! echo "$command_unquoted" | grep -qE "$commit_re"; then
  exit 0
fi

if echo "$command_unquoted" | grep -qE -- '--amend\b'; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null) || exit 0
repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0

session_id=$(echo "$input" | jq -r '.session_id // empty')
[ -n "$session_id" ] || exit 0

files=$(git -C "$cwd" diff --cached --name-only 2>/dev/null || true)
# -a/--all-style flag anywhere after `commit`, not just immediately
# following it (found live: `git commit -m "msg" -a`, a real, common
# ordering, didn't match the immediate-adjacency version) - against the
# quote-stripped command (found live: a commit message like "note:
# skip -all changes" otherwise reads as the flag).
if echo "$command_unquoted" | grep -qE 'git\s+commit\b.*(^|[[:space:]])(-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)'; then
  files="$files
$(git -C "$cwd" diff --name-only 2>/dev/null || true)"
fi
files=$(echo "$files" | grep -v '^$' || true)

# Nothing staged - let the real `git commit` fail on its own with its
# own message, not this hook's.
[ -n "$files" ] || exit 0

deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{decision: "deny", reason: $reason}' >&2
  exit 2
}

flag_file="$git_dir/maipai-gate-checked-$session_id"
stamped_scope=""
if [ -f "$flag_file" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$flag_file" 2>/dev/null || stat -c %Y "$flag_file" 2>/dev/null) ))
  if [ "$age" -lt 1800 ]; then
    stamped_scope=$(cat "$flag_file" 2>/dev/null || true)
  fi
fi

if [ -z "$stamped_scope" ]; then
  deny "No scripts/check.sh run is on record for this repo in the last 30 minutes. Run it (the right scope for your diff, or --docs for a docs-only change), then retry this commit. This is a soft gate: once the gate runs, the same commit goes through."
fi

[ "$stamped_scope" = "full" ] && exit 0

is_doc_path() {
  case "$1" in
    README.md|CHANGELOG.md|AGENTS.md|CLAUDE.md|LICENSE|NOTICE) return 0 ;;
    docs/api/*) return 1 ;;
    docs/*) return 0 ;;
  esac
  return 1
}

doc_only=1
while IFS= read -r f; do
  [ -n "$f" ] || continue
  is_doc_path "$f" || doc_only=0
done <<EOF
$files
EOF

if [ -f "$repo_root/scripts/gateScope.ts" ]; then
  changed_file=$(mktemp)
  imported_file=$(mktemp)
  trap "rm -f '$changed_file' '$imported_file'" EXIT

  # $files (already computed above: --cached, plus the working-tree
  # diff too when -a/--all is in play) is exactly the set this commit
  # is about to create - not a fresh working-tree-vs-merge-base diff,
  # which an earlier version of this hook used to mirror check.sh's own
  # compute_scope() as closely as possible. That mirroring was the bug:
  # in a shared checkout (the org's own workflow explicitly allows one),
  # a second session's own unrelated, still-uncommitted edits sitting in
  # the same working tree would get swept into "what needs scoping" and
  # could inflate the required scope past what this commit actually
  # touches, denying a commit that was genuinely, fully covered by the
  # stamped run (found live). What check.sh itself scopes a *gate run*
  # to and what this hook scopes a *specific commit* to are different
  # questions; $files answers the second one correctly.
  printf '%s\n' "$files" > "$changed_file"

  # `git grep` exits 1 (not an error) when it finds nothing - real in
  # any repo whose frontend/ doesn't import backend code at all, and
  # under `set -o pipefail` that would otherwise kill this whole script
  # via the pipeline's own exit status (found live, testing against a
  # synthetic repo with no such imports - the same bug filed as
  # getmaipai/home#144 against check.sh's own identical, currently
  # dormant, copy of this line).
  { git -C "$repo_root" grep -hoE '@maipai/home-backend/src/[A-Za-z0-9_./-]+' -- frontend/ 2>/dev/null || true; } \
    | sed 's#@maipai/home-backend/#backend/#' \
    | sort -u > "$imported_file"

  required_scope=$( (cd "$repo_root" && bun scripts/gateScope.ts "$changed_file" "$imported_file" 2>/dev/null | head -1) || true)

  if [ -n "$required_scope" ]; then
    if [ "$required_scope" = "$stamped_scope" ]; then
      exit 0
    fi
    deny "The last scripts/check.sh run was scoped to '$stamped_scope', but this commit's own diff needs '$required_scope' (scripts/gateScope.ts's own answer). Run 'bash scripts/check.sh' (or the '$required_scope'-covering scope) and retry."
  fi
  # gateScope.ts existed but produced nothing usable (bun missing, a
  # crash) - fall through to the repo-agnostic doc-only check below
  # rather than silently passing.
fi

if [ "$doc_only" = 1 ] && { [ "$stamped_scope" = "docs" ] || [ "$stamped_scope" = "full" ]; }; then
  exit 0
fi

deny "The last scripts/check.sh run was scoped to '$stamped_scope', which doesn't cover this commit's own files. Run 'bash scripts/check.sh' (the full gate, or --docs if every staged file is really docs-only) and retry."
