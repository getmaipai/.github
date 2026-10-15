#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/plugin/hooks/scripts/require-review-before-commit.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
repo="$TMP/repo"
mkdir -p "$repo/scripts" "$repo/backend/src/auth"
git init -q -b main "$repo"
git -C "$repo" config user.name Test
git -C "$repo" config user.email test@example.invalid
# Fixture classifier: auth paths are T2, everything else T1.
cat > "$repo/scripts/wt.sh" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == tier ]]; then
  shift
  for f in "$@"; do [[ "$f" == backend/src/auth/* ]] && { echo T2; exit; }; done
  echo T1
fi
SH
printf 'code\n' > "$repo/app.ts"
printf 'auth\n' > "$repo/backend/src/auth/session.ts"
git -C "$repo" add . && git -C "$repo" commit -qm init
run_hook() {
  printf '{"cwd":"%s","tool_input":{"command":"git commit -m test"}}' "$repo" | (cd "$repo" && bash "$HOOK") >/dev/null 2>"$TMP/err"
}

# T1 commit passes with no review stamp.
echo change >> "$repo/app.ts"; git -C "$repo" add app.ts
run_hook || { cat "$TMP/err"; echo 'expected allow: T1 without stamp' >&2; exit 1; }
git -C "$repo" reset -q --hard HEAD

# T2 path is denied without a stamp.
echo change >> "$repo/backend/src/auth/session.ts"; git -C "$repo" add backend/src/auth/session.ts
if run_hook; then echo 'expected deny: T2 without stamp' >&2; exit 1; fi
grep -q 'code-review' "$TMP/err" || { cat "$TMP/err"; exit 1; }

# A fresh review stamp lets the T2 commit through.
touch "$repo/.git/maipai-review-checked"
run_hook || { cat "$TMP/err"; echo 'expected allow: T2 with stamp' >&2; exit 1; }
echo 'review hook tests passed'
