#!/usr/bin/env bash
# Clears the Codex tmux pane between briefs, waiting out a mid-compact
# state first so the /clear keystroke isn't swallowed (the 2026-09-21
# failure mode in coordinate SKILL.md section 1b). One command instead
# of the coordinator hand-typing capture-pane/send-keys/wait each time.
#
# Usage: codex-clear.sh <tmux-session-name>
set -euo pipefail
session="${1:?tmux session name, e.g. codex}"

for _ in $(seq 1 20); do
  pane="$(tmux capture-pane -t "$session" -p | tail -5)"
  if ! grep -q "Compacting context" <<<"$pane"; then
    break
  fi
  sleep 3
done

tmux send-keys -t "$session" "/clear" Enter
sleep 2
echo "cleared $session"
