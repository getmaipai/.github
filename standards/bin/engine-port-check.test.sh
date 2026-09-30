#!/usr/bin/env bash
# Regression test for engine-port-check.sh using committed fixture scripts.
set -uo pipefail
cd "$(dirname "$0")/../.."
CHECK="$(pwd)/standards/bin/engine-port-check.sh"
TMP_REPO=$(mktemp -d)
trap 'rm -rf "$TMP_REPO"' EXIT
cd "$TMP_REPO"
git init -q
git config user.name test
git config user.email test@example.invalid

mkdir -p scripts
cat > scripts/bad.ts <<'EOF'
const child = spawn("llama-server", [
  "--port", "8788",
]);
EOF
git add scripts/bad.ts
git commit -qm fixture
if "$CHECK" . >bad.out 2>&1; then
  echo "FAIL: fixed default engine port passed"
  exit 1
fi
grep -q 'fixed default engine port in launching script: scripts/bad.ts' bad.out || {
  cat bad.out
  echo "FAIL: missing fixed-port diagnostic"
  exit 1
}

cat > scripts/bad.ts <<'EOF'
const child = spawn("llama-server", [
  "--port", "28788",
]);
EOF
git add scripts/bad.ts
git commit -qm spare-port
"$CHECK" . >good.out 2>&1 || {
  cat good.out
  echo "FAIL: spare engine port was rejected"
  exit 1
}

cat > scripts/comment.ts <<'EOF'
// A note about llama-server on 8788 is not a launch.
const url = "http://127.0.0.1:8788";
EOF
git add scripts/comment.ts
git commit -qm comment
"$CHECK" . >good.out 2>&1 || {
  cat good.out
  echo "FAIL: engine references without a launch were rejected"
  exit 1
}

echo "engine-port-check.test.sh: all assertions passed"
