#!/usr/bin/env bash
# Target for Codex CLI's `notify` config (or a hooks.json command). Codex
# invokes this itself the instant a turn completes, so the coordinator can
# Monitor the log below for a real push instead of scraping `tmux
# capture-pane` on a schedule (coordinate SKILL.md section 1b).
#
# Codex's own notify/hook payload shape has changed across versions and
# nothing here parses it: this script just appends whatever it was handed,
# verbatim, as one line. The coordinator reads that line's JSON when
# Monitor fires.
#
# Wiring (in ~/.codex/config.toml or the equivalent hooks.json entry for
# the installed version):
#   notify = ["<this script's absolute path>"]
#
# Usage: codex-notify.sh [payload-as-arg]   (falls back to stdin)
set -euo pipefail

log="$HOME/.local/state/maipai/codex-events.log"
mkdir -p "$(dirname "$log")"

payload="${1:-}"
if [ -z "$payload" ]; then
  if [ -t 0 ]; then
    # No arg and stdin is an interactive terminal, not a pipe: reading
    # would block forever. Record that instead of hanging.
    payload="(codex-notify.sh called with no argument and no piped stdin)"
  else
    payload="$(cat)"
  fi
fi

printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(printf '%s' "$payload" | tr '\n' ' ')" >> "$log"
