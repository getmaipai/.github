#!/usr/bin/env bash
# Resolves this repo's standards pin through an immutable per-tag worktree.
# The sibling checkout is mutable and can drift past a tag; this follows commons's ensure-tag.sh.
#
# Usage: standards/bin/ensure-tag.sh <tag>
# Prints the worktree path on stdout.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: ensure-tag.sh <tag>" >&2
  exit 1
fi

TAG="$1"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if ! git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$TAG^{commit}" >/dev/null; then
  echo "unknown tag: $TAG (not found in $REPO_ROOT - fetch it or check the pin)" >&2
  exit 1
fi
EXPECTED_HEAD="$(git -C "$REPO_ROOT" rev-parse "refs/tags/$TAG^{commit}")"
TAGS_DIR="$(cd "$REPO_ROOT/.." && pwd)/.github-tags"
WORKTREE_PATH="$TAGS_DIR/$TAG"

is_valid_worktree_at_head() {
  git -C "$REPO_ROOT" worktree list --porcelain | grep -qxF "worktree $WORKTREE_PATH" \
    && [ "$(git -C "$WORKTREE_PATH" rev-parse HEAD)" = "$EXPECTED_HEAD" ]
}
if [ -d "$WORKTREE_PATH" ]; then
  if ! is_valid_worktree_at_head; then
    echo "$WORKTREE_PATH exists but isn't a worktree of $REPO_ROOT at $TAG - remove it and re-run for a clean one." >&2
    exit 1
  fi
  echo "$WORKTREE_PATH"
  exit 0
fi
mkdir -p "$TAGS_DIR"
if ! git -C "$REPO_ROOT" worktree add --detach "$WORKTREE_PATH" "$TAG" >&2; then
  if is_valid_worktree_at_head; then
    echo "$WORKTREE_PATH"
    exit 0
  fi
  echo "failed to create a worktree at $WORKTREE_PATH for $TAG" >&2
  exit 1
fi
echo "$WORKTREE_PATH"
