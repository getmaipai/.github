#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<< "$input")
[ -n "$command" ] || exit 0
unquoted=$(sed -E 's/"[^"]*"//g; s/'"'"'[^'"'"']*'"'"'//g' <<< "$command")
commit_re='(^|[;&|]|&&)\s*git(\s+-[A-Za-z0-9=._/-]+(\s+[^ ;&|-][^ ;&|]*)?)*\s+commit\b'
grep -qE "$commit_re" <<< "$unquoted" || exit 0
grep -qE -- '--amend\b' <<< "$unquoted" && exit 0
cwd=$(jq -r '.cwd // empty' <<< "$input"); cwd=${cwd:-$PWD}
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -x "$root/scripts/wt.sh" ] || { printf '%s' "$input" | bash "$(dirname "$0")/require-gate-before-commit-legacy.sh"; exit $?; }
session=$(jq -r '.session_id // empty' <<< "$input"); [ -n "$session" ] || exit 0
files=$(git -C "$cwd" diff --cached --name-only)
all_flag=0
if grep -qE 'git\s+commit\b.*(^|[[:space:]])(-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$)' <<< "$unquoted"; then
  all_flag=1
  files+=$'\n'"$(git -C "$cwd" diff --name-only)"
fi
files=$(sed '/^$/d' <<< "$files")
[ -n "$files" ] || exit 0
deny() { jq -n --arg reason "$1" '{decision:"deny",reason:$reason}' >&2; exit 2; }
tier=$(cd "$cwd" && bash scripts/wt.sh tier $files 2>/dev/null | tail -1)
case "$tier" in T0) exit 0;; T1|T2) :;; *) deny "Could not classify the staged files. Run 'bash scripts/wt.sh tier' from the repository, fix the issue, and retry.";; esac
name=${MAIPAI_WT_SESSION:-$(git -C "$root" branch --show-current)}
name=${name#wt/}
stamp="${MAIPAI_WT_DATA:-$root/data-scratch}/gate-stamps/$name.json"
[ -f "$stamp" ] || deny "No wt.sh gate stamp exists for '$name'. Run 'bash scripts/wt.sh check' and retry."
read -r stamped rc < <(node -e 'const j=require(process.argv[1]);console.log(j.tier,j.exitCode)' "$stamp")
epoch=$(stat -f %m "$stamp" 2>/dev/null || stat -c %Y "$stamp" 2>/dev/null)
age=$(( $(date +%s)-epoch ))
(( age >= 0 && age < 1800 )) || deny "The wt.sh stamp is over 30 minutes old. Run 'bash scripts/wt.sh check' and retry."
[ "$rc" = 0 ] || deny "The last wt.sh check failed with exit code $rc. Fix the failure, run 'bash scripts/wt.sh check', and retry."
if [ "$tier" = T2 ] && [ "$stamped" != T2 ]; then deny "This commit requires T2, but the stamp is $stamped. Run 'bash scripts/wt.sh check T2' and retry."; fi
if [ "$tier" = T1 ] && [ "$stamped" != T1 ] && [ "$stamped" != T2 ]; then deny "This commit requires T1, but the stamp is $stamped. Run 'bash scripts/wt.sh check T1' and retry."; fi
while IFS= read -r path; do
  [ -n "$path" ] || continue
  expected=$(node -e 'const j=require(process.argv[1]);process.stdout.write(j.manifest?.[process.argv[2]]||"")' "$stamp" "$path")
  if [ "$all_flag" = 1 ]; then
    if [ -L "$root/$path" ]; then actual=$(readlink -n "$root/$path" | git -C "$root" hash-object --stdin)
    elif [ -e "$root/$path" ]; then actual=$(git -C "$root" hash-object -- "$path")
    else actual=0000000000000000000000000000000000000000; fi
  else actual=$(git -C "$root" rev-parse ":$path" 2>/dev/null || echo 0000000000000000000000000000000000000000); fi
  [ -n "$expected" ] && [ "$actual" = "$expected" ] || deny "$path differs from the wt.sh stamp. Run 'bash scripts/wt.sh check' and retry."
done <<< "$files"
