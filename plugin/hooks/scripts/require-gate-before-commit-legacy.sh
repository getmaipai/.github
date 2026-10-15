#!/usr/bin/env bash
# PreToolUse (Bash matcher): refuses a `git commit` unless `scripts/
# check.sh` has run to completion, in a scope that actually covers what
# is about to be committed, within the last 30 minutes, AND every file
# about to be committed still carries exactly the content that run
# tested (GATE-HOOK-02 - the org's own "gate per push, not per commit"
# rule needs a batch of commits off one gate run to go through, but a
# tracked-file edit after that run has to force a fresh one). Soft
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
all_flag=0
if echo "$command_unquoted" | grep -qE 'git\s+commit\b.*(^|[[:space:]])(-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)'; then
  all_flag=1
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
gate_head=""
manifest=""
if [ -f "$flag_file" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$flag_file" 2>/dev/null || stat -c %Y "$flag_file" 2>/dev/null) ))
  if [ "$age" -lt 1800 ]; then
    stamped_scope=$(sed -n '1p' "$flag_file" 2>/dev/null || true)
    gate_head=$(sed -n '2p' "$flag_file" 2>/dev/null || true)
    manifest=$(tail -n +3 "$flag_file" 2>/dev/null || true)
  fi
fi

if [ -z "$stamped_scope" ]; then
  deny "No scripts/check.sh run is on record for this repo in the last 30 minutes. Run it (the right scope for your diff, or --docs for a docs-only change), then retry this commit. This is a soft gate: once the gate runs, the same commit goes through."
fi

# GATE-HOOK-02 (the org's own "gate per push, not per commit" rule): a
# scope-covering, recent-enough stamp only proves the gate saw the
# tree it ran against - not that nothing has changed since for a file
# THIS commit is about to take. Two commits from the same unchanged
# tree both pass (every one of their files still matches what the
# stamp recorded); a tracked-file edit after the stamp fails, and
# names the file, whether that edit is to a file the gate already saw
# dirty (its own working-tree hash moved again), a file that was clean
# at stamp time (now diverges from `gate_head`'s own blob), or a new
# file the gate never saw at all (no manifest entry, no `gate_head`
# blob either). The zero-hash sentinel matters for a deletion: a path
# already staged for deletion AT stamp time carries that same all-zero
# hash in the manifest (mark-gate-checked.sh's own convention for a
# missing working-tree file), so committing that same pre-gated
# deletion later in an unchanged tree still compares equal, never a
# false deny.
if [ -n "$gate_head" ]; then
  zero_hash="0000000000000000000000000000000000000000"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # What content THIS commit actually takes for $f: with -a/--all,
    # `git commit` stages the working tree for every tracked path
    # itself, inside the real commit call that runs AFTER this hook -
    # so a file only picked up via -a's own supplemental diff above
    # still has its OLD, pre-edit content in the index right now, and
    # checking the index here would silently pass a post-stamp edit
    # straight through (found live: staged one file, stamped the gate,
    # edited a second, already-clean file with no `git add`, then `git
    # commit -a` - the index-only check read the second file's stale,
    # matching-HEAD blob and allowed it). Without -a, the index IS what
    # gets committed, same as before.
    if [ "$all_flag" = 1 ]; then
      # A symlink's own git-stored content is its target string, never
      # what it points to (mirroring mark-gate-checked.sh's own
      # manifest write, and the same reason plain `git hash-object --
      # <path>` can't be used here either): `readlink` plus `git
      # hash-object --stdin` matches the blob git itself would store;
      # a regular file hashes directly; anything else (including a
      # dangling symlink resolved with `readlink`, and a genuinely
      # absent path) falls to the zero "deleted" sentinel.
      if [ -L "$repo_root/$f" ]; then
        staged_hash=$(readlink -n "$repo_root/$f" 2>/dev/null | git -C "$repo_root" hash-object --stdin 2>/dev/null) || staged_hash="$zero_hash"
      elif [ -e "$repo_root/$f" ]; then
        staged_hash=$(git -C "$repo_root" hash-object -- "$f" 2>/dev/null) || staged_hash="$zero_hash"
      else
        staged_hash="$zero_hash"
      fi
    else
      # `git rev-parse` prints its own unresolved argument to stdout
      # even when it fails (found live: a `2>/dev/null || echo
      # fallback` still captured "$path\nfallback", two lines, since
      # rev-parse's failed attempt already wrote to stdout before the
      # `||` ran) - so the fallback has to overwrite the assignment in
      # an explicit failure branch, never lean on `||` inside the same
      # command substitution.
      if ! staged_hash=$(git -C "$repo_root" rev-parse ":$f" 2>/dev/null); then
        staged_hash="$zero_hash"
      fi
    fi
    manifest_hash=$(echo "$manifest" | awk -F'\t' -v p="$f" '$2 == p { print $1; exit }')
    if [ -n "$manifest_hash" ]; then
      expected_hash="$manifest_hash"
    elif ! expected_hash=$(git -C "$repo_root" rev-parse "$gate_head:$f" 2>/dev/null); then
      expected_hash="NEW"
    fi
    if [ "$staged_hash" != "$expected_hash" ]; then
      deny "$f changed after the last scripts/check.sh run (stamped against $gate_head) - that gate never saw this content. Run 'bash scripts/check.sh' again and retry."
    fi
  done <<EOF
$files
EOF
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
