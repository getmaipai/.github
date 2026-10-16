#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/plugin/hooks/scripts/guard-main-checkout.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
main="$TMP/getmaipai/demo"
mkdir -p "$main"
git init -q -b main "$main"
git -C "$main" config user.name Test
git -C "$main" config user.email test@example.invalid
git -C "$main" commit -q --allow-empty -m init
git -C "$main" worktree add -q -b wt/x "$TMP/getmaipai/wt-x"
wt="$TMP/getmaipai/wt-x"
run_hook() { printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$2" | bash "$HOOK" >/dev/null 2>"$TMP/err"; }
assert_ok() { run_hook "$1" "$2" || { cat "$TMP/err"; echo "expected allow: $2 in $1" >&2; exit 1; }; }
assert_deny() { if run_hook "$1" "$2"; then echo "expected deny: $2 in $1" >&2; exit 1; fi; grep -q "main checkout" "$TMP/err" || { cat "$TMP/err"; exit 1; }; }

assert_deny "$main" "git rebase origin/main"
assert_deny "$main" "git reset --hard origin/main"
assert_deny "$main" "git checkout other"
assert_deny "$main" "git switch -c lane/x"
assert_deny "$main" "git pull"
assert_deny "$main" "git worktree add ../x"
assert_deny "$main" "git remote set-url origin https://example.com/x.git"
assert_deny "$main" "git push --force origin main"
assert_deny "$wt" "git -C $main reset --hard HEAD"
assert_ok "$main" "git status"
assert_ok "$main" "git fetch origin"
assert_ok "$main" "git log --oneline"
assert_ok "$main" "git push origin HEAD:main"
assert_ok "$wt" "git rebase origin/main"
assert_ok "$wt" "git reset --hard HEAD"
assert_ok "$main" "MAIPAI_ALLOW_MAIN_CHECKOUT=1 git reset --hard origin/main"
echo "guard-main-checkout: ok"
