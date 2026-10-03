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
#   gate-lock.sh acquire <label> [item]   blocks until held, exits 0
#                                         (exits 1 past the wait cap)
#   gate-lock.sh release <label>          frees it if <label> holds it
#   gate-lock.sh status                   holder or "free", plus queue
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

GATE_LOCK_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/maipai/gate-lock"

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
  local label="$1" item="$2" pid="$3"
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
  printf '%s\t%s\t%s\t%s\n' "$label" "$item" "$(_gl_now)" "$pid" >> "$GATE_LOCK_DIR/queue"
  _gl_mutex_unlock

  # A caller interrupted while queued (Ctrl-C on check.sh reaches this
  # process too) leaves the queue rather than blocking the ones behind.
  # Executed only: a sourcing shell's own traps are never replaced.
  [ "$_GL_SOURCED" = 1 ] || trap '_gl_mutex_lock; _gl_queue_prune "$label"; _gl_mutex_unlock; exit 130' INT TERM HUP

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
      [ "$_GL_SOURCED" = 1 ] || trap - INT TERM HUP
      if ! _gl_alive "$pid"; then
        echo "gate-lock: gave up, the owning process (pid $pid) exited while queued" >&2
      else
        echo "gate-lock: gave up after ${elapsed}s at queue position $pos (allowance ${allowed}s); holder: $(cat "$GATE_LOCK_DIR/holder" 2>/dev/null || echo none)" >&2
      fi
      return 1
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

gate_lock() {
  local usage="usage: gate-lock.sh acquire <label> [item] | release <label> | status"
  case "${1:-}" in
    acquire)
      [ -n "${2:-}" ] || { echo "$usage" >&2; return 2; }
      if [ "$_GL_SOURCED" = 1 ]; then
        _gl_acquire "$2" "${3:-}" "${GATE_LOCK_PID:-$$}"
      else
        _gl_acquire "$2" "${3:-}" "${GATE_LOCK_PID:-$PPID}"
      fi
      ;;
    release)
      [ -n "${2:-}" ] || { echo "$usage" >&2; return 2; }
      _gl_release "$2"
      ;;
    status)
      _gl_status
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
