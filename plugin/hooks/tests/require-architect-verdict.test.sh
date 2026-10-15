#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$ROOT/plugin/hooks/scripts/require-architect-verdict.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
repo="$TMP/repo"
mkdir -p "$repo/docs/design" "$repo/docs/plans"
git init -q -b main "$repo"
git -C "$repo" config user.name Test
git -C "$repo" config user.email test@example.invalid
printf '# Rules\n' > "$repo/docs/design/RULES.md"
printf -- '- [ ] **ITEM-01** first row\n- [ ] **ITEM-02** second row\n' > "$repo/docs/BACKLOG.md"
git -C "$repo" add . && git -C "$repo" commit -qm init
run_hook() {
  printf '{"cwd":"%s","tool_input":{"command":"git commit -m test"}}' "$repo" | bash "$HOOK" >/dev/null 2>"$TMP/err"
}
assert_ok() { run_hook || { cat "$TMP/err"; echo "expected allow: $1" >&2; exit 1; }; }
assert_deny() { if run_hook; then echo "expected deny: $1" >&2; exit 1; fi; grep -q "verdict" "$TMP/err" || { cat "$TMP/err"; exit 1; }; }

# A checkbox flip commits with no verdict.
sed -i.bak 's/- \[ \] \*\*ITEM-01\*\*/- [x] **ITEM-01**/' "$repo/docs/BACKLOG.md"; rm "$repo/docs/BACKLOG.md.bak"
git -C "$repo" add docs/BACKLOG.md
assert_ok 'checkbox flip'
git -C "$repo" commit -qm flip

# A status edit on an existing row (still starts with "- [ ] **") passes.
sed -i.bak 's/second row/second row (in progress)/' "$repo/docs/BACKLOG.md"; rm "$repo/docs/BACKLOG.md.bak"
git -C "$repo" add docs/BACKLOG.md
assert_ok 'status edit'
git -C "$repo" commit -qm status

# A new backlog row is denied without a verdict.
printf -- '- [ ] **ITEM-03** third row\n' >> "$repo/docs/BACKLOG.md"
git -C "$repo" add docs/BACKLOG.md
assert_deny 'new backlog row'
git -C "$repo" reset -q --hard HEAD

# A new plan is denied without a verdict.
mkdir -p "$repo/docs/plans"
printf 'plan\n' > "$repo/docs/plans/x.md"
git -C "$repo" add docs/plans/x.md
assert_deny 'new plan'
git -C "$repo" reset -q --hard HEAD; rm -f "$repo/docs/plans/x.md"

# A design note is denied; a code path is not governed any more.
printf 'note\n' > "$repo/docs/design/note.md"
git -C "$repo" add docs/design/note.md
assert_deny 'design note'
git -C "$repo" reset -q --hard HEAD; rm -f "$repo/docs/design/note.md"
printf 'code\n' > "$repo/app.ts"
git -C "$repo" add app.ts
assert_ok 'code path'

# A fresh APPROVED verdict named in the message lets a new plan through.
git -C "$repo" reset -q --hard HEAD; rm -f "$repo/app.ts"
mkdir -p "$repo/docs/plans"
printf 'plan\n' > "$repo/docs/plans/x.md"
git -C "$repo" add docs/plans/x.md
mkdir -p "$repo/data-scratch/architect"
printf 'item: PLAN-X\nverdict: APPROVED\ntimestamp: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$repo/data-scratch/architect/PLAN-X.verdict"
printf '{"cwd":"%s","tool_input":{"command":"git commit -m \\"PLAN-X plan\\""}}' "$repo" | bash "$HOOK" >/dev/null 2>"$TMP/err" || { cat "$TMP/err"; echo 'expected allow with verdict' >&2; exit 1; }
echo 'architect hook tests passed'
