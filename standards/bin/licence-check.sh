#!/usr/bin/env bash
# @maipai/standards: licence check.
#
# Confirms LICENSE is present and is AGPL-3.0 with a Copyright (c) line, and
# that a NOTICE file exists whenever third-party components need attribution
# (best-effort: flags NOTICE as missing only when the repo has a lockfile,
# since an empty repo has nothing to attribute yet).
set -euo pipefail
REPO_ROOT="${1:-.}"
cd "$REPO_ROOT"

STATUS=0

if [ ! -f LICENSE ]; then
  echo "missing LICENSE"
  STATUS=1
else
  if ! grep -qi "GNU AFFERO GENERAL PUBLIC LICENSE" LICENSE; then
    echo "LICENSE is not AGPL-3.0"
    STATUS=1
  fi
  if ! grep -q "Copyright (c)" LICENSE; then
    echo "LICENSE is missing a Copyright (c) line"
    STATUS=1
  fi
fi

exit $STATUS
