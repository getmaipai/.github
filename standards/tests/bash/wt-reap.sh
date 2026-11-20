#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
wt_script="$repo_root/standards/bin/wt.sh"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
main="$scratch/main"
origin="$scratch/origin.git"
data="$scratch/session-data"
shim="$scratch/bin"
mkdir -p "$main" "$shim"
git init --bare "$origin" >/dev/null
git init -b main "$main" >/dev/null
git -C "$main" config user.name Tester
git -C "$main" config user.email tester@example.invalid
printf 'base\n' > "$main/.gitignore"
printf 'base\n' > "$main/README.md"
git -C "$main" add .
git -C "$main" commit -qm base
git -C "$main" remote add origin "$origin"
git -C "$main" push -qu origin main
# Prevent real tmux or lsof state from affecting these isolated fixtures.
printf '#!/usr/bin/env bash\nexit 1\n' > "$shim/tmux"
printf '#!/usr/bin/env bash\nexit 0\n' > "$shim/lsof"
chmod +x "$shim/tmux" "$shim/lsof"

make_worktree() {
  local name="$1" branch="wt/$1" path="$scratch/wt-$1"
  git -C "$main" worktree add -qb "$branch" "$path" origin/main
  path="$(cd "$path" && pwd -P)"
  mkdir -p "$data/sessions"
  cat > "$data/sessions/$name.json" <<JSON
{"owner":"tester","pid":99999999,"tmux":"","created":"2020-01-01T00:00:00.000Z","branch":"$branch","path":"$path"}
JSON
  touch -t 202001010000 "$data/sessions/$name.json"
  touch -t 202001010000 "$data/sessions/$name.beat"
  printf '%s' "$path"
}

reap() {
  (cd "$main" && env PATH="$shim:$PATH" XDG_STATE_HOME="$scratch/state" MAIPAI_WT_DATA="$data" MAIPAI_WT_REAP_AGE=0 MAIPAI_WT_REAP_QUIET=60 bash "$wt_script" reap "$@")
}
age_tree() {
  local path="$1" gitdir
  gitdir="$(git -C "$path" rev-parse --absolute-git-dir)"
  find "$path" "$gitdir" -exec touch -t 202001010000 {} +
}
assert_kept() {
  local path="$1"
  git -C "$main" worktree list --porcelain | grep -Fq "worktree $path"
}
assert_removed() {
  local path="$1"
  ! git -C "$main" worktree list --porcelain | grep -Fq "worktree $path" || { cat "$data/reaped.md" >&2; return 1; }
}

# Landed clean worktrees may contain ignored disposable build and development data.
path="$(make_worktree disposable)"
cat > "$path/.gitignore" <<'IGNORE'
data/
ort/
gate-stamps/
.eslintcache
node_modules/
.cache/
dist/
coverage/
.turbo/
*.log
IGNORE
git -C "$path" add .gitignore
git -C "$path" -c user.name=Tester -c user.email=tester@example.invalid commit -qm ignore-rules
git -C "$main" push -qu origin "wt/disposable:main"
git -C "$main" fetch -q origin
mkdir -p "$path/data" "$path/ort" "$path/gate-stamps" "$path/node_modules/pkg" "$path/.cache" "$path/dist" "$path/coverage" "$path/.turbo"
printf 'db' > "$path/data/dev.db"
printf 'model' > "$path/ort/model"
printf 'stamp' > "$path/gate-stamps/gate.json"
printf 'cache' > "$path/.eslintcache"
printf 'module' > "$path/node_modules/pkg/index.js"
printf 'cache' > "$path/.cache/cache"
printf 'dist' > "$path/dist/out"
printf 'coverage' > "$path/coverage/out"
printf 'turbo' > "$path/.turbo/cache"
printf 'log' > "$path/run.log"
age_tree "$path"
touch -t 202001010000 "$data/sessions/disposable.beat"
reap >/dev/null
assert_removed "$path"
[[ ! -e "$data/sessions/disposable.json" ]]

# An unlanded commit remains even when its worktree is otherwise clean.
path="$(make_worktree unlanded)"
printf 'new commit\n' > "$path/new.txt"
git -C "$path" add new.txt
git -C "$path" -c user.name=Tester -c user.email=tester@example.invalid commit -qm unlanded
age_tree "$path"
touch -t 202001010000 "$data/sessions/unlanded.beat"
reap >/dev/null
assert_kept "$path"

git -C "$main" worktree remove --force "$path"
git -C "$main" branch -D wt/unlanded >/dev/null
rm -f "$data/sessions/unlanded.json" "$data/sessions/unlanded.beat"

# Tracked and untracked changes always remain.
path="$(make_worktree dirty)"
printf 'keep\n' > "$path/untracked.txt"
age_tree "$path"
touch -t 202001010000 "$data/sessions/dirty.beat"
reap >/dev/null
assert_kept "$path"

git -C "$main" worktree remove --force "$path"
git -C "$main" branch -D wt/dirty >/dev/null
rm -f "$data/sessions/dirty.json" "$data/sessions/dirty.beat"

# Unknown ignored content remains and is named in reaped.md.
path="$(make_worktree unknown)"
printf 'important\n' > "$path/.gitignore"
git -C "$path" add .gitignore
git -C "$path" -c user.name=Tester -c user.email=tester@example.invalid commit -qm ignore-unknown
git -C "$main" push -qu origin wt/unknown:main
git -C "$main" fetch -q origin
mkdir -p "$path/important"
printf 'keep\n' > "$path/important/item.txt"
age_tree "$path"
touch -t 202001010000 "$data/sessions/unknown.beat"
reap >/dev/null
assert_kept "$path"
grep -Fq 'kept: unknown ignored paths (important/item.txt)' "$data/reaped.md" || { cat "$data/reaped.md" >&2; exit 1; }

# A fresh heartbeat and a worktree that contains the current directory stay.
path="$(make_worktree heartbeat)"
touch "$data/sessions/heartbeat.beat"
age_tree "$path"
reap >/dev/null
assert_kept "$path"

path="$(make_worktree current)"
age_tree "$path"
touch -t 202001010000 "$data/sessions/current.beat"
(cd "$path" && env PATH="$shim:$PATH" XDG_STATE_HOME="$scratch/state" MAIPAI_WT_DATA="$data" MAIPAI_WT_REAP_AGE=0 MAIPAI_WT_REAP_QUIET=60 bash "$wt_script" reap >/dev/null)
assert_kept "$path"

# Dry-run reports a candidate but leaves the worktree and session file in place.
path="$(make_worktree dryrun)"
age_tree "$path"
touch -t 202001010000 "$data/sessions/dryrun.beat"
out="$(reap --dry-run 2>&1)"
assert_kept "$path"
[[ -e "$data/sessions/dryrun.json" ]]
grep -Fq "would remove worktree $path" <<< "$out"

printf 'wt-reap.sh: all cases passed\n'
