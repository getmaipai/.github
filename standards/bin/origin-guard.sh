#!/usr/bin/env bash
# Fails when a checkout's `origin` points at a different getmaipai repo than the checkout's own.
# A mixed-up origin (home pointed at commons.git, 2026-10-15) makes fetches show another repo's
# history and a push land in the wrong repo. Used by wt.sh and as a pre-push hook.
#
# Usage: origin-guard.sh [repo-dir]   (default: the current checkout)
set -euo pipefail
dir="${1:-.}"
common="$(git -C "$dir" rev-parse --git-common-dir)"
case "$common" in /*) ;; *) common="$(cd "$dir/$common" && pwd)" ;; esac
repo="$(basename "$(cd "$common/.." && pwd)")"
url="$(git -C "$dir" remote get-url origin 2>/dev/null)" || { echo "origin-guard: no origin remote in $repo; add it with: git remote add origin https://github.com/getmaipai/$repo.git" >&2; exit 1; }
# Only GitHub getmaipai remotes are checked; local mirrors and test fixtures pass.
case "$url" in *getmaipai/*) ;; *) exit 0 ;; esac
name="${url%/}"; name="${name##*/}"; name="${name##*:}"; name="${name%.git}"
if [ "$name" != "$repo" ]; then
  echo "origin-guard: origin of the $repo checkout points at '$url', not $repo.git. Fix with: git -C $(cd "$common/.." && pwd) remote set-url origin https://github.com/getmaipai/$repo.git" >&2
  exit 1
fi
