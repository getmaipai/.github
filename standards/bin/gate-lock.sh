#!/usr/bin/env bash
# @maipai/standards - the machine-wide full-gate mutex.
#
# Why this exists: org docs/VERIFICATION.md > "One full gate at a
# time on a shared machine". Two full check.sh runs at once on the dev
# machine push it into memory pressure and fail tests the change never
# touched. The rule used to be a pgrep poll each session ran by hand,
# which had no ownership record (a pattern match cannot tell a live
# holder from a stale one) and no wake signal (a session that hit its
# capped wait sat reporting "waiting" on a gate that had already
# freed). See docs/DECISIONS.md, 2026-09-27. This is the real lock:
# every repo's scripts/check.sh takes it before any non-docs scope and
# releases it in an EXIT trap.
#
# Usage:
#   gate-lock.sh acquire <label> [item] [lane] blocks until held, exits 0
#                                         (exits 1 past the wait cap)
#   gate-lock.sh release <label>          frees it if <label> holds it
#   gate-lock.sh status                   holder or "free", plus queue
#   gate-lock.sh heavy <label> [--mem-gb N] -- <command...>
#                                         RUN-GUARD-01: runs a heavy command in one of two
#                                         machine-wide slots (see "Heavy runs" below)
#
# <label> names the caller unambiguously in `status`, e.g. "home-12345"
# (repo dirname plus the check.sh shell's PID). [item] is free text for
# the holder record (an item id), empty when the caller has none.
#
# State is machine-wide, never per repo: the resource being protected
# is this machine's memory, so every repo's gate serializes through one
# directory, ${XDG_STATE_HOME:-$HOME/.local/state}/maipai/gate-lock/:
#   holder  one line, <label>\t<item>\t<pid>\t<acquired-at UTC>
#   queue   one line per waiter, <label>\t<item>\t<enqueued-at>\t<pid>,
#           FIFO in file order
# <pid> is the process that owns the slot: GATE_LOCK_PID when the caller
# sets it, otherwise this script's parent (the check.sh shell that ran
# `bash gate-lock.sh acquire`). Never this script's own $$: acquire
# exits the moment it holds the lock, and a holder recorded under a
# dead PID would be reclaimed as stale by the very next waiter.
#
# Staleness is judged by `kill -0` on a recorded PID, never by elapsed
# time: a crashed holder (or a waiter killed while queued) is reclaimed
# without guessing, and a live one is never stolen however long it runs.
#
# The wait is FIFO: only the first live waiter in `queue` attempts the
# create, so a newcomer never jumps a session that has been waiting. It
# rechecks every GATE_LOCK_POLL_SECONDS (10) and gives up after
# position * GATE_LOCK_PER_POSITION_SECONDS (360), counting the deepest
# position it has held so a shrinking queue never shortens its allowance
# mid-wait, capped at GATE_LOCK_MAX_SECONDS (1800) in total. Giving up
# exits 1 with how long it waited and where it stood: the caller fails
# the gate and reports, never retries silently. The three overrides
# exist for this script's own tests; callers leave them unset.
#
# Sourcing this file defines gate_lock() and runs nothing; executing it
# runs gate_lock "$@".

# GATE-SPEED-01: GATE_LOCK_NAME picks a separate lock for a lighter class of
# gate (check.sh uses "frontend" for a frontend-only diff) so it never waits
# behind a backend or full gate; unset keeps the one machine-wide lock.
GATE_LOCK_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/maipai"
GATE_LOCK_DIR="$GATE_LOCK_ROOT/gate-lock${GATE_LOCK_NAME:+-$GATE_LOCK_NAME}"
GATE_LANE_QUEUE_DIR="$GATE_LOCK_ROOT/gate-lanes"

_gl_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
_gl_alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }
# Field <n> of a tab-separated record. cut, never `IFS=$'\t' read`: a tab
# is IFS whitespace, so read collapses the empty <item> field an
# item-less caller writes and shifts the PID into its place.
_gl_field() { printf '%s\n' "$1" | cut -f"$2"; }

# A short-lived mutex around every read-modify-write of `queue`, every
# stale-holder reclaim and every claim of `holder`. `queue` is rewritten
# (filter to a temp file, mv) when a line leaves it, and an append racing
# that rewrite would be lost without it. It is a kernel flock(2) on fd 9,
# taken through perl (macOS ships no flock(1)): the lock belongs to the
# open file, which this shell keeps open on fd 9 after perl exits, and
# the kernel drops it the moment this process dies. So a process killed
# mid-edit can never leave it held, and nothing ever has to guess that a
# lock is stale and break it (a timed break let two processes in at once
# and both claim `holder`, found in review).
_gl_mutex_lock() {
  if ! exec 9>>"$GATE_LOCK_DIR/.mutex"; then
    echo "gate-lock: cannot open $GATE_LOCK_DIR/.mutex" >&2
    return 1
  fi
  perl -MFcntl=:flock -e 'open(my $fh, ">&=", 9) or die "gate-lock: fd 9: $!\n"; flock($fh, LOCK_EX) or die "gate-lock: flock: $!\n"'
}
_gl_mutex_unlock() { exec 9>&-; }

_gl_lane_mutex_lock() {
  mkdir -p "$GATE_LANE_QUEUE_DIR" || return 1
  if ! exec 8>>"$GATE_LANE_QUEUE_DIR/.mutex"; then
    echo "gate-lock: cannot open $GATE_LANE_QUEUE_DIR/.mutex" >&2
    return 1
  fi
  perl -MFcntl=:flock -e 'open(my $fh, ">&=", 8) or die "gate-lock: fd 8: $!\n"; flock($fh, LOCK_EX) or die "gate-lock: flock: $!\n"'
}
_gl_lane_mutex_unlock() { exec 8>&-; }

_gl_lane_prune() {
  local tmp line
  [ -f "$GATE_LANE_QUEUE_DIR/queue" ] || return 0
  tmp="$(mktemp "$GATE_LANE_QUEUE_DIR/.queue.XXXXXX")"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    _gl_alive "$(_gl_field "$line" 5)" && printf '%s\n' "$line"
  done < "$GATE_LANE_QUEUE_DIR/queue" > "$tmp"
  mv -f "$tmp" "$GATE_LANE_QUEUE_DIR/queue"
}

_gl_lane_remove() {
  local label="$1" tmp line
  _gl_lane_mutex_lock || return 1
  _gl_lane_prune
  if [ -f "$GATE_LANE_QUEUE_DIR/queue" ]; then
    tmp="$(mktemp "$GATE_LANE_QUEUE_DIR/.queue.XXXXXX")"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      [ "$(_gl_field "$line" 2)" = "$label" ] || printf '%s\n' "$line"
    done < "$GATE_LANE_QUEUE_DIR/queue" > "$tmp"
    mv -f "$tmp" "$GATE_LANE_QUEUE_DIR/queue"
  fi
  _gl_lane_mutex_unlock
}

_gl_lane_enqueue() {
  local lane="$1" label="$2" item="$3" pid="$4" line
  [ -n "$lane" ] || return 0
  _gl_lane_mutex_lock || return 1
  _gl_lane_prune
  if [ -f "$GATE_LANE_QUEUE_DIR/queue" ]; then
    while IFS= read -r line; do
      [ "$(_gl_field "$line" 1)" = "$lane" ] || continue
      _gl_lane_mutex_unlock
      echo "gate-lock: lane $lane already has queued gate $(_gl_field "$line" 2) (item $(_gl_field "$line" 3))" >&2
      return 1
    done < "$GATE_LANE_QUEUE_DIR/queue"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$lane" "$label" "$item" "$(_gl_now)" "$pid" >> "$GATE_LANE_QUEUE_DIR/queue"
  _gl_lane_mutex_unlock
}

# Rewrites `queue` without the lines for <label> and without any waiter
# whose recorded PID is dead. Caller holds the mutex.
_gl_queue_prune() {
  local label="$1" queue="$GATE_LOCK_DIR/queue" tmp line
  [ -f "$queue" ] || return 0
  tmp="$(mktemp "$GATE_LOCK_DIR/.queue.XXXXXX")"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "$(_gl_field "$line" 1)" = "$label" ] && continue
    _gl_alive "$(_gl_field "$line" 4)" || continue
    printf '%s\n' "$line"
  done < "$queue" > "$tmp"
  mv -f "$tmp" "$queue"
}

# 1-indexed position of <label> in `queue`, 0 when absent.
_gl_queue_position() {
  local label="$1" n=0 line
  [ -f "$GATE_LOCK_DIR/queue" ] || { echo 0; return 0; }
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    n=$((n + 1))
    if [ "$(_gl_field "$line" 1)" = "$label" ]; then echo "$n"; return 0; fi
  done < "$GATE_LOCK_DIR/queue"
  echo 0
}

# Removes `holder` if its recorded PID is dead, or if it is empty. Caller
# holds the mutex, and every claim is made under the mutex too, so two
# waiters that both judge the same holder dead cannot both remove it (the
# second would otherwise delete the first one's fresh claim), and an
# empty holder seen here is a claimant that died between the create and
# the write (or a full disk), never a claim still being written.
_gl_reclaim_stale() {
  local holder="$GATE_LOCK_DIR/holder" line pid
  [ -f "$holder" ] || return 0
  line="$(cat "$holder" 2>/dev/null || true)"
  if [ -z "$line" ]; then
    echo "gate-lock: reclaiming an empty holder record" >&2
    rm -f "$holder"
    return 0
  fi
  pid="$(_gl_field "$line" 3)"
  if ! _gl_alive "$pid"; then
    echo "gate-lock: reclaiming a stale lock held by $(_gl_field "$line" 1) (pid $pid is not running)" >&2
    rm -f "$holder"
  fi
}

# The atomic claim: noclobber makes the redirect fail rather than
# overwrite when `holder` already exists (the lane-lock.sh primitive).
_gl_try_create() {
  local label="$1" item="$2" pid="$3"
  (set -o noclobber; printf '%s\t%s\t%s\t%s\n' "$label" "$item" "$pid" "$(_gl_now)" > "$GATE_LOCK_DIR/holder") 2>/dev/null
}

_gl_acquire() {
  local label="$1" item="$2" pid="$3" lane="${4:-}"
  local poll="${GATE_LOCK_POLL_SECONDS:-10}"
  local per="${GATE_LOCK_PER_POSITION_SECONDS:-360}"
  local max="${GATE_LOCK_MAX_SECONDS:-1800}"
  local start pos deepest=1 allowed elapsed

  if ! mkdir -p "$GATE_LOCK_DIR" || ! : >> "$GATE_LOCK_DIR/queue"; then
    echo "gate-lock: cannot write the lock state at $GATE_LOCK_DIR" >&2
    return 1
  fi

  # Fast path, only when no live session is already waiting: a free (or
  # stale) lock is taken at once; otherwise this caller joins the queue.
  _gl_mutex_lock || return 1
  _gl_queue_prune "$label"
  if [ ! -s "$GATE_LOCK_DIR/queue" ]; then
    _gl_reclaim_stale
    if _gl_try_create "$label" "$item" "$pid"; then
      _gl_mutex_unlock
      echo "acquired"
      return 0
    fi
  fi
  if ! _gl_lane_enqueue "$lane" "$label" "$item" "$pid"; then
    _gl_mutex_unlock
    return 1
  fi
  printf '%s\t%s\t%s\t%s\n' "$label" "$item" "$(_gl_now)" "$pid" >> "$GATE_LOCK_DIR/queue"
  _gl_mutex_unlock

  # A caller interrupted while queued (Ctrl-C on check.sh reaches this
  # process too) leaves the queue rather than blocking the ones behind.
  # Executed only: a sourcing shell's own traps are never replaced.
  [ "$_GL_SOURCED" = 1 ] || trap '_gl_mutex_lock; _gl_queue_prune "$label"; _gl_mutex_unlock; _gl_lane_remove "$label"; exit 130' INT TERM HUP

  start=$(date +%s)
  echo "gate-lock: waiting for the full gate (held by $(cut -f1 "$GATE_LOCK_DIR/holder" 2>/dev/null || echo "nobody"))" >&2
  while :; do
    _gl_mutex_lock || return 1
    _gl_reclaim_stale
    _gl_queue_prune ""
    pos="$(_gl_queue_position "$label")"
    if [ "$pos" = 0 ]; then
      # Pruned by another process (its own view of a dead PID, or a
      # corrupt line): rejoin at the back rather than wait unqueued.
      printf '%s\t%s\t%s\t%s\n' "$label" "$item" "$(_gl_now)" "$pid" >> "$GATE_LOCK_DIR/queue"
      pos="$(_gl_queue_position "$label")"
    fi
    if [ "$pos" = 1 ] && _gl_try_create "$label" "$item" "$pid"; then
      _gl_queue_prune "$label"
      _gl_mutex_unlock
      _gl_lane_remove "$label"
      [ "$_GL_SOURCED" = 1 ] || trap - INT TERM HUP
      echo "acquired after $(( $(date +%s) - start ))s"
      return 0
    fi
    _gl_mutex_unlock

    [ "$pos" -gt "$deepest" ] && deepest="$pos"
    allowed=$((deepest * per))
    [ "$allowed" -gt "$max" ] && allowed="$max"
    elapsed=$(( $(date +%s) - start ))
    if [ "$elapsed" -ge "$allowed" ] || ! _gl_alive "$pid"; then
      _gl_mutex_lock || return 1
      _gl_queue_prune "$label"
      _gl_mutex_unlock
      _gl_lane_remove "$label"
      [ "$_GL_SOURCED" = 1 ] || trap - INT TERM HUP
      if ! _gl_alive "$pid"; then
        echo "gate-lock: gave up, the owning process (pid $pid) exited while queued" >&2
      else
        echo "gate-lock: gave up after ${elapsed}s at queue position $pos (allowance ${allowed}s); holder: $(cat "$GATE_LOCK_DIR/holder" 2>/dev/null || echo none)" >&2
      fi
      return 1
    fi
    # GATE-SPEED-01: a waiting gate says where it stands every minute.
    if [ $(( elapsed / 60 )) -gt "${_gl_last_note:-0}" ]; then
      _gl_last_note=$(( elapsed / 60 ))
      echo "gate-lock: still waiting, position $pos of $(grep -c . "$GATE_LOCK_DIR/queue" 2>/dev/null || echo "$pos"), ${elapsed}s so far; holder: $(cut -f1,2 "$GATE_LOCK_DIR/holder" 2>/dev/null | tr '\t' ' ' || echo none)" >&2
    fi
    sleep "$poll"
  done
}

_gl_release() {
  local label="$1" holder="$GATE_LOCK_DIR/holder" owner
  mkdir -p "$GATE_LOCK_DIR" || return 1
  _gl_mutex_lock || return 1
  _gl_queue_prune "$label"
  if [ -f "$holder" ]; then
    owner="$(cut -f1 "$holder")"
    if [ "$owner" != "$label" ]; then
      _gl_mutex_unlock
      echo "refused: held by $owner, not $label" >&2
      return 1
    fi
    rm -f "$holder"
  fi
  _gl_mutex_unlock
  echo "released"
}

_gl_status() {
  local holder="$GATE_LOCK_DIR/holder" queue="$GATE_LOCK_DIR/queue" pid
  if [ -f "$holder" ]; then
    pid="$(cut -f3 "$holder")"
    if _gl_alive "$pid"; then
      echo "held: $(cat "$holder")"
    else
      echo "held (stale, pid $pid not running): $(cat "$holder")"
    fi
  else
    echo "free"
  fi
  if [ -s "$queue" ]; then
    echo "queue:"
    sed 's/^/  /' "$queue"
  fi
}

# ---------------------------------------------------------------------------
# Heavy runs (RUN-GUARD-01 and RELIABILITY-PREVENT-09, 2026-10-30). The full
# gate is one mutex above; every other heavy run (an ad hoc `bun test`, a
# `--pre` run, a bench, an evaluation, `bun run screenshots`, an Xcode build)
# goes through `heavy`, which holds one of GATE_HEAVY_SLOTS (2) machine-wide
# slots under $GATE_LOCK_ROOT/heavy-slots/. On 2026-10-30 tests, installs,
# Playwright and Xcode running at once took the load to 65 and the Mac had to
# be restarted. The run
#   1. waits, with a plain message every 30 s, while both slots are held, the
#      one-minute load average is over GATE_HEAVY_MAX_LOAD (20), or the free
#      memory reported by memory_pressure is under GATE_HEAVY_MIN_FREE_PCT (25);
#      it gives up after GATE_HEAVY_MAX_WAIT_SECONDS (900) with exit 75;
#   2. starts the command at background priority (`taskpolicy -b`) in its own
#      process group, whose id is the one recorded pid the cap and the cleanup
#      act on;
#   3. every GATE_HEAVY_SAMPLE_SECONDS (5) adds up the resident memory of that
#      group; over the cap (--mem-gb, else GATE_HEAVY_MEM_GB, default 8) it
#      stops the group (TERM, then KILL after 10 s) and exits 137 saying so;
#   4. when the command ends, stops whatever it left in the group (headless
#      browsers, dev servers), and prints the group's peak memory.
# Nothing outside the group is ever signalled, and nothing is found by name.
# A heavy run started inside a heavy run (GATE_HEAVY_HELD is set) just runs, so
# the full gate calling tests cannot wait on its own slot. The load and memory
# readers can be replaced (GATE_HEAVY_LOAD_CMD, GATE_HEAVY_FREE_CMD,
# GATE_HEAVY_RSS_CMD, GATE_HEAVY_TASKPOLICY) for this script's tests.

_gh_dir() { echo "$GATE_LOCK_ROOT/heavy-slots"; }
_gh_load() { if [ -n "${GATE_HEAVY_LOAD_CMD:-}" ]; then sh -c "$GATE_HEAVY_LOAD_CMD"; else sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}'; fi; }
_gh_free_pct() {
  if [ -n "${GATE_HEAVY_FREE_CMD:-}" ]; then sh -c "$GATE_HEAVY_FREE_CMD"; return; fi
  command -v memory_pressure >/dev/null 2>&1 || { echo 100; return; }
  memory_pressure 2>/dev/null | awk '/free percentage/ {gsub("%","",$NF); print $NF}'
}
# KB of resident memory summed over one process group.
_gh_group_rss_kb() {
  if [ -n "${GATE_HEAVY_RSS_CMD:-}" ]; then GATE_HEAVY_PGID="$1" sh -c "$GATE_HEAVY_RSS_CMD"; return; fi
  ps -ax -o pgid=,rss= 2>/dev/null | awk -v g="$1" '$1 == g {s += $2} END {print s + 0}'
}

# Claims a free slot (reclaiming a dead owner's) and prints its path, or returns 1.
_gh_claim() {
  local dir n f pid slots="${GATE_HEAVY_SLOTS:-2}"
  dir="$(_gh_dir)"; mkdir -p "$dir" || return 1
  for n in $(seq 1 "$slots"); do
    f="$dir/slot-$n"
    if [ -f "$f" ]; then
      pid="$(cut -f2 "$f" 2>/dev/null)"
      _gl_alive "$pid" && continue
      rm -f "$f"
    fi
    if (set -o noclobber; printf '%s\t%s\t%s\n' "$1" "$$" "$(_gl_now)" > "$f") 2>/dev/null; then echo "$f"; return 0; fi
  done
  return 1
}

_gh_stop_group() {
  local pgid="$1"
  kill -TERM -- "-$pgid" 2>/dev/null || return 0
  local i=0
  while [ "$i" -lt 10 ] && [ "$(_gh_group_rss_kb "$pgid")" != 0 ]; do sleep 1; i=$((i + 1)); done
  kill -KILL -- "-$pgid" 2>/dev/null || true
}

_gl_heavy() {
  local label="${1:-}" cap_gb="${GATE_HEAVY_MEM_GB:-8}"
  [ -n "$label" ] || { echo "usage: gate-lock.sh heavy <label> [--mem-gb N] -- <command...>" >&2; return 2; }
  shift
  if [ "${1:-}" = "--mem-gb" ]; then cap_gb="${2:?--mem-gb needs a number}"; shift 2; fi
  [ "${1:-}" = "--" ] && shift
  [ "$#" -gt 0 ] || { echo "gate-lock: heavy needs a command after --" >&2; return 2; }
  if [ -n "${GATE_HEAVY_HELD:-}" ]; then "$@"; return $?; fi

  local max_load="${GATE_HEAVY_MAX_LOAD:-20}" min_free="${GATE_HEAVY_MIN_FREE_PCT:-25}"
  local max_wait="${GATE_HEAVY_MAX_WAIT_SECONDS:-900}" poll="${GATE_HEAVY_POLL_SECONDS:-5}" note_every="${GATE_HEAVY_NOTE_SECONDS:-30}"
  local sample="${GATE_HEAVY_SAMPLE_SECONDS:-5}" tp="${GATE_HEAVY_TASKPOLICY:-taskpolicy}"
  local start slot why load free last_note=-1 elapsed
  start=$(date +%s)
  while :; do
    load="$(_gh_load)"; free="$(_gh_free_pct)"; why=""
    if awk -v l="${load:-0}" -v m="$max_load" 'BEGIN {exit !(l > m)}'; then why="the computer is busy (load $load, limit $max_load)"
    elif awk -v f="${free:-100}" -v m="$min_free" 'BEGIN {exit !(f < m)}'; then why="the computer is low on free memory (${free}% free, need ${min_free}%)"; fi
    if [ -z "$why" ] && slot="$(_gh_claim "$label")"; then break; fi
    [ -n "$why" ] || why="both heavy-run slots are in use ($(cut -f1 "$(_gh_dir)"/slot-* 2>/dev/null | tr '\n' ' '))"
    elapsed=$(( $(date +%s) - start ))
    if [ "$elapsed" -ge "$max_wait" ]; then
      echo "gate-lock: gave up after ${elapsed}s: $why. Nothing was started; try again when the computer is quieter." >&2
      return 75
    fi
    if [ $(( elapsed / note_every )) -gt "$last_note" ]; then
      last_note=$(( elapsed / note_every ))
      echo "gate-lock: $label is waiting to start: $why. It starts by itself when that clears (gives up after ${max_wait}s)." >&2
    fi
    sleep "$poll"
  done

  local pid pgid rc=0 peak=0 cur capped=0 cap_kb
  cap_kb=$(awk -v g="$cap_gb" 'BEGIN {printf "%d", g * 1048576}')
  # The slot is freed on every way out. The command runs as a group leader (setpgrp), so one pgid names all of it.
  trap 'rm -f "$slot"' EXIT
  GATE_HEAVY_HELD=1 perl -e 'setpgrp(0, 0); my @c = @ARGV; if (my $tp = shift @c) { exec($tp, "-b", @c) if $tp ne "-" } exec(@c)' -- "$tp" "$@" &
  pid=$!; pgid=$pid
  trap '_gh_stop_group "$pgid"; rm -f "$slot"; exit 130' INT TERM HUP
  while kill -0 "$pid" 2>/dev/null; do
    cur="$(_gh_group_rss_kb "$pgid")"
    [ "${cur:-0}" -gt "$peak" ] && peak="$cur"
    if [ "$cap_kb" -gt 0 ] && [ "${cur:-0}" -gt "$cap_kb" ]; then
      capped=1
      echo "gate-lock: $label used $(( cur / 1048576 )) GB of memory, over its $cap_gb GB limit. Stopping it and everything it started (process group $pgid). Raise the limit with --mem-gb if this run really needs more." >&2
      _gh_stop_group "$pgid"
      break
    fi
    sleep "$sample" &
    wait $! 2>/dev/null || true
  done
  wait "$pid" 2>/dev/null; rc=$?
  # Helpers the run left behind (headless browsers, dev servers) are in its group.
  if [ "$(_gh_group_rss_kb "$pgid")" != 0 ]; then _gh_stop_group "$pgid"; fi
  rm -f "$slot"; trap - EXIT INT TERM HUP
  echo "gate-lock: $label peak memory $(awk -v k="$peak" 'BEGIN {printf "%.1f", k / 1048576}') GB (limit $cap_gb GB)" >&2
  [ "$capped" = 1 ] && return 137
  return "$rc"
}

gate_lock() {
  local usage="usage: gate-lock.sh acquire <label> [item] | release <label> | status | heavy <label> [--mem-gb N] -- <command...>"
  case "${1:-}" in
    acquire)
      [ -n "${2:-}" ] || { echo "$usage" >&2; return 2; }
      if [ "$_GL_SOURCED" = 1 ]; then
        _gl_acquire "$2" "${3:-}" "${GATE_LOCK_PID:-$$}" "${4:-${GATE_LOCK_LANE:-}}"
      else
        _gl_acquire "$2" "${3:-}" "${GATE_LOCK_PID:-$PPID}" "${4:-${GATE_LOCK_LANE:-}}"
      fi
      ;;
    release)
      [ -n "${2:-}" ] || { echo "$usage" >&2; return 2; }
      _gl_release "$2"
      ;;
    status)
      _gl_status
      ;;
    heavy)
      shift
      _gl_heavy "$@"
      ;;
    *)
      echo "$usage" >&2
      return 2
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _GL_SOURCED=0
  set -uo pipefail
  gate_lock "$@"
else
  _GL_SOURCED=1
fi
