#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/plugin/hooks/scripts/require-gate-before-commit.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
repo="$TMP/repo"
mkdir -p "$repo/scripts" "$repo/data-scratch/gate-stamps"
git init -q -b main "$repo"
git -C "$repo" config user.name Test
git -C "$repo" config user.email test@example.invalid
cat > "$repo/scripts/wt.sh" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == tier ]]; then
  shift
  for f in "$@"; do [[ "$f" == backend/src/auth/* ]] && { echo T2; exit; }; done
  echo T1
fi
SH
chmod +x "$repo/scripts/wt.sh"
printf 'base\n' > "$repo/README.md"
printf 'code\n' > "$repo/app.ts"
mkdir -p "$repo/backend/src/auth"; printf 'auth\n' > "$repo/backend/src/auth/session.ts"
git -C "$repo" add . && git -C "$repo" commit -qm init
run_hook() {
  local command="git commit -m 'test'"
  printf '{"cwd":"%s","session_id":"fixture","tool_input":{"command":"%s"}}' "$repo" "$command" | bash "$HOOK" >/dev/null 2>"$TMP/err"
}
make_stamp() {
  local tier="$1"
  node - "$repo" "$tier" <<'NODE'
const fs=require('fs'),cp=require('child_process');
const [root,tier]=process.argv.slice(2); const files=cp.execFileSync('git',['-C',root,'diff','--cached','--name-only'],{encoding:'utf8'}).trim().split('\n').filter(Boolean);
const manifest=Object.fromEntries(files.map(p=>[p,cp.execFileSync('git',['-C',root,'rev-parse',`:${p}`],{encoding:'utf8'}).trim()]));
fs.writeFileSync(root+'/data-scratch/gate-stamps/main.json',JSON.stringify({tier,head:'head',exitCode:0,created:new Date().toISOString(),manifest}));
NODE
}
assert_ok() { run_hook || { cat "$TMP/err"; echo "expected allow: $1" >&2; exit 1; }; }
assert_deny() { if run_hook; then echo "expected deny: $1" >&2; exit 1; fi; grep -q "$1" "$TMP/err" || { cat "$TMP/err"; exit 1; }; }

# T0 passes without a stamp.
echo doc >> "$repo/README.md"; git -C "$repo" add README.md
# Stub classifier returns T1 by default; supply a T0 classifier for this assertion.
sed -i.bak 's/echo T1/echo T0/' "$repo/scripts/wt.sh"
assert_ok T0
mv "$repo/scripts/wt.sh.bak" "$repo/scripts/wt.sh"

echo change >> "$repo/app.ts"; git -C "$repo" add app.ts
assert_deny 'No wt.sh gate stamp'
make_stamp T1
assert_ok 'T1 after stamp'
echo post-stamp >> "$repo/app.ts"; git -C "$repo" add app.ts
assert_deny 'differs from the wt.sh stamp'

git -C "$repo" reset -q --hard HEAD
echo auth-change >> "$repo/backend/src/auth/session.ts"; git -C "$repo" add backend/src/auth/session.ts
make_stamp T1
assert_deny 'requires T2'

# A lander waives only the T1 commit stamp, not T2.
rm -f "$repo/data-scratch/gate-stamps/main.json"
cat > "$repo/scripts/land.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$repo/scripts/land.sh"
git -C "$repo" add scripts/land.sh && git -C "$repo" commit -qm 'add lander fixture'
git -C "$repo" reset -q --hard HEAD
echo lander-t1 >> "$repo/app.ts"; git -C "$repo" add app.ts
assert_ok 'T1 with lander and no stamp'
git -C "$repo" reset -q --hard HEAD
echo lander-t2 >> "$repo/backend/src/auth/session.ts"; git -C "$repo" add backend/src/auth/session.ts
assert_deny 'No wt.sh gate stamp'
echo 'hook tier tests passed'
