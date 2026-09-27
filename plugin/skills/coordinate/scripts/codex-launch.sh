#!/usr/bin/env bash
# Opens the Codex tmux session in one command instead of a separate
# `tmux new` followed by a separate `codex`/`codexd` command
# (coordinate SKILL.md section 1b). If the session already exists and
# looks idle (a shell prompt, not Codex running), re-points it the same
# way `codex-clear.sh` waits out a mid-compact state. If it exists and
# looks busy, refuses unless `--force` is passed: killing a live pane
# with Ctrl-C loses whatever Codex was mid-turn on, so that is never
# the default.
#
# Usage: codex-launch.sh [--force] <worktree-path> [tmux-session-name] [launch-cmd]
#   worktree-path      absolute path to the fixed Codex worktree (e.g.
#                       .../home-codex)
#   tmux-session-name  defaults to "codex"
#   launch-cmd          defaults to "codexd" (never plain "codex": it
#                       prompts for approval on every command and stalls
#                       the lane, per feedback_codex_launch_codexd)
set -euo pipefail

force=""
if [ "${1:-}" = "--force" ]; then
  force="1"
  shift
fi

worktree="${1:?usage: codex-launch.sh [--force] <worktree-path> [session] [launch-cmd]}"
session="${2:-codex}"
launch_cmd="${3:-codexd}"

if [ ! -d "$worktree" ]; then
  echo "worktree not found: $worktree" >&2
  exit 1
fi

if tmux has-session -t "$session" 2>/dev/null; then
  pane="$(tmux capture-pane -t "$session" -p | tail -5)"
  if grep -q "Compacting context" <<<"$pane"; then
    for _ in $(seq 1 20); do
      pane="$(tmux capture-pane -t "$session" -p | tail -5)"
      grep -q "Compacting context" <<<"$pane" || break
      sleep 3
    done
  elif [ -z "$force" ] && grep -qE "Working|Compacting context" <<<"$pane"; then
    echo "session '$session' looks busy (mid-turn); refusing to interrupt it. Pass --force to kill and re-point it anyway." >&2
    exit 1
  fi
  tmux send-keys -t "$session" C-c
  sleep 1
  tmux send-keys -t "$session" "cd \"$worktree\" && $launch_cmd" Enter
  echo "re-pointed existing session '$session' at $worktree"
else
  tmux new-session -d -s "$session" -c "$worktree" "$launch_cmd"
  echo "opened new session '$session' at $worktree running $launch_cmd"
fi
