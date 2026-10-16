#!/usr/bin/env bash
# One-worktree-per-session workflow, shared by every getmaipai repo (workflow redesign
# 3.1, 3.2, 3.5). A repo does not copy this file: its scripts/wt.sh sets the per-repo
# settings below and runs this one. Settings (all optional, space-separated lists):
#   WT_INSTALL_DIRS      directories where `wt.sh start` runs `bun install --frozen-lockfile`
#   WT_T2_GLOBS          `case` patterns for risky paths (tier T2); everything else is T1
#   WT_TEST_WORKSPACES   directories whose `*.test.ts(x)` files T1 may run, each from inside
#                        its own directory (default: none)
#   WT_TEST_HOOK         executable (relative to the repo root) that runs the T1 tests itself,
#                        given the changed files; replaces the bun test discovery
#   WT_PIN_REMINDER      text printed after a landing that changed a pin
set -euo pipefail

WT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "wt: not inside a Git worktree; run this command from a repository checkout." >&2; exit 2; }
WT_COMMON="$(git rev-parse --git-common-dir)"
case "$WT_COMMON" in /*) ;; *) WT_COMMON="$(cd "$WT_COMMON" && pwd)" ;; esac
WT_MAIN="$(cd "$WT_COMMON/.." && pwd)"
WT_REPO="$(basename "$WT_MAIN")"
WT_PARENT="$(dirname "$WT_MAIN")"
WT_DATA="${MAIPAI_WT_DATA:-$WT_MAIN/data-scratch}"
WT_SESSION_DIR="$WT_DATA/sessions"
WT_PORT_DIR="$WT_DATA/ports"
# The commit-gate hook reads the stamp from the worktree it commits in, so the stamp
# lives there (removed with the worktree); sessions and ports are shared in the main checkout.
WT_STAMP_DIR="${MAIPAI_WT_DATA:-$WT_ROOT/data-scratch}/gate-stamps"
WT_INSTALL_DIRS="${WT_INSTALL_DIRS:-}"
WT_T2_GLOBS="${WT_T2_GLOBS:-}"
WT_TEST_WORKSPACES="${WT_TEST_WORKSPACES:-}"
WT_TEST_HOOK="${WT_TEST_HOOK:-}"
WT_ADJECTIVES=(amber brisk calm clever eager fair gentle happy keen lucky mild nimble quiet swift)
WT_ANIMALS=(badger falcon heron otter panda robin tiger yak)

err() { echo "wt: $1" >&2; exit "${2:-1}"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || err "$1 is required; install it and retry."; }
valid_name() { [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]; }
rand_index() { od -An -N4 -tu4 /dev/urandom | awk -v n="$1" 'NR == 1 {print $1 % n; exit}'; }
make_name() { echo "${WT_ADJECTIVES[$(rand_index "${#WT_ADJECTIVES[@]}")]}-${WT_ANIMALS[$(rand_index "${#WT_ANIMALS[@]}")]}-$1"; }

session_file() { printf '%s/%s.json' "$WT_SESSION_DIR" "$1"; }
read_json() { node -e 'const fs=require("fs");let j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(j[process.argv[2]]??""))' "$1" "$2"; }
write_session() {
  local name="$1" branch="$2" path="$3" tmux="${4:-}"
  mkdir -p "$WT_SESSION_DIR"
  node - "$name" "$branch" "$path" "$tmux" "${MAIPAI_WT_PID:-$PPID}" <<'NODE' > "$(session_file "$name")"
const [name, branch, path, tmux, pid] = process.argv.slice(2);
const owner = process.env.CLAUDE_CODE_SESSION_ID || process.env.CLAUDE_SESSION_ID || process.env.CODEX_SESSION_ID || "codex";
console.log(JSON.stringify({owner, pid: Number(pid), tmux: tmux || null, created: new Date().toISOString(), branch, path}, null, 2));
NODE
}
tmux_cmd() { if [[ -n "${MAIPAI_WT_TMUX_SOCKET:-}" ]]; then tmux -L "$MAIPAI_WT_TMUX_SOCKET" "$@"; else tmux "$@"; fi; }
current_session_name() {
  local branch name
  branch="$(git -C "$WT_ROOT" branch --show-current)"
  if [[ "$branch" == wt/* ]]; then echo "${branch#wt/}"
  else name="$(basename "$WT_ROOT")"; name="${name#"$WT_REPO"-}"; echo "$name"; fi
}

cmd_start() {
  [[ $# == 1 ]] || err "start needs one slug; use: wt.sh start <slug>." 2
  local slug="$1"; valid_name "$slug" || err "slug '$slug' has unsupported characters; use letters, digits, and hyphens."
  cmd_reap
  need_cmd git
  git -C "$WT_ROOT" fetch origin || err "could not fetch origin; check network access and retry."
  local name branch path
  name="$(make_name "$slug")"; branch="wt/${name%-$slug}-$slug"; path="$WT_PARENT/wt/$WT_REPO-$name"
  [[ ! -e "$path" ]] || err "worktree path already exists: $path; choose another slug or clean up that worktree."
  ! git -C "$WT_MAIN" show-ref --verify --quiet "refs/heads/$branch" || err "branch already exists: $branch; choose another slug or remove the stale branch."
  mkdir -p "$(dirname "$path")"
  git -C "$WT_MAIN" worktree add -b "$branch" "$path" origin/main >&2 || err "could not create worktree from origin/main; inspect Git output and retry."
  # Pinned file dependencies and cross-repo doc links are relative to the repository's
  # parent. The workflow keeps worktrees one level deeper, so expose the sibling
  # checkouts at that level without changing shared pin state.
  local sib
  for sib in commons-tags commons .github home stack catalog bot go; do
    if [[ -d "$WT_PARENT/$sib" && ! -e "$WT_PARENT/wt/$sib" ]]; then ln -s "$WT_PARENT/$sib" "$WT_PARENT/wt/$sib"; fi
  done
  local d
  for d in $WT_INSTALL_DIRS; do
    if [[ -d "$path/$d" ]]; then
      if ! (cd "$path/$d" && bun install --frozen-lockfile); then
        git -C "$WT_MAIN" worktree remove --force "$path" >/dev/null 2>&1 || true
        git -C "$WT_MAIN" branch -D "$branch" >/dev/null 2>&1 || true
        err "bun install failed in $d; fix the install error, then rerun wt.sh start $slug."
      fi
    fi
  done
  write_session "$name" "$branch" "$path"
  printf '%s\n' "$path"
}

cmd_tmux() {
  [[ $# == 1 ]] || err "tmux needs one purpose name; use: wt.sh tmux <purpose>." 2
  local purpose="$1" name f branch path actual worktree_name candidate candidate_pid matches=()
  valid_name "$purpose" || err "purpose '$purpose' has unsupported characters; use letters, digits, and hyphens."
  name="${MAIPAI_WT_SESSION:-$(current_session_name)}"; f="$(session_file "$name")"
  if [[ ! -f "$f" ]]; then
    for candidate in "$WT_SESSION_DIR"/*.json; do
      [[ -f "$candidate" ]] || continue
      candidate_pid="$(read_json "$candidate" pid)"
      [[ "$candidate_pid" == "${MAIPAI_WT_PID:-$PPID}" ]] && matches+=("$candidate")
    done
    if (( ${#matches[@]} == 1 )); then f="${matches[0]}"; name="$(basename "$f" .json)"; fi
  fi
  [[ -f "$f" ]] || err "no session file for this worktree; run wt.sh start <slug> and enter its worktree first."
  need_cmd tmux
  branch="$(read_json "$f" branch)"; path="$(read_json "$f" path)"
  worktree_name="$(basename "$path")"; worktree_name="${worktree_name#"$WT_REPO"-}"
  actual="$WT_REPO-$worktree_name-$purpose"
  if tmux_cmd has-session -t "$actual" >/dev/null 2>&1; then err "tmux session '$actual' already exists; use its existing session or choose another purpose name."; fi
  tmux_cmd new-session -d -s "$actual" -c "$path" || err "could not create tmux session '$actual'; check tmux and retry."
  write_session "$name" "$branch" "$path" "$actual"
  printf '%s\n' "$actual"
}

# Standard Codex launch (replaces hand-typed tmux and watcher steps): one owned tmux session
# runs `codex exec` on the brief and the log always ends in an EXIT= line, so `wt.sh wait`
# can report the finish. Run `wait` as a background command and the harness wakes you.
# set_run_state <session-name> <state>: lets a status pane show running/DONE/FAILED/DIED/TIMEOUT per run.
set_run_state() {
  local f; f="$(session_file "$1")"; [[ -f "$f" ]] || return 0
  node - "$f" "$2" <<'NODE'
const fs = require("fs"); const [f, state] = process.argv.slice(2);
const j = JSON.parse(fs.readFileSync(f, "utf8")); j.runState = state; j.runStateAt = new Date().toISOString();
fs.writeFileSync(f, JSON.stringify(j, null, 2) + "\n");
NODE
}
run_log() { printf '%s/runs/%s.log' "$WT_DATA" "$1"; }
cmd_run() {
  local detach=0; if [[ "${1:-}" == --detach ]]; then detach=1; shift; fi
  [[ $# == 2 ]] || err "run needs a purpose and a brief file; use: wt.sh run [--detach] <purpose> <brief-file>." 2
  local purpose="$1" brief="$2" name f path actual log bin
  valid_name "$purpose" || err "purpose '$purpose' has unsupported characters; use letters, digits, and hyphens."
  [[ -f "$brief" ]] || err "brief '$brief' not found; write the complete brief first (see the dispatch skill)."
  brief="$(cd "$(dirname "$brief")" && pwd)/$(basename "$brief")"
  name="${MAIPAI_WT_SESSION:-$(current_session_name)}"; f="$(session_file "$name")"
  [[ -f "$f" ]] || err "no session file for '$name'; run wt.sh start <slug> first and export MAIPAI_WT_SESSION."
  need_cmd tmux
  path="$(read_json "$f" path)"
  actual="$WT_REPO-${name}-$purpose"
  tmux_cmd has-session -t "$actual" >/dev/null 2>&1 && err "tmux session '$actual' already exists; wait for it or pick another purpose name."
  mkdir -p "$WT_DATA/runs"; log="$(run_log "$actual")"; : > "$log"
  bin="${MAIPAI_CODEX_BIN:-codex}"
  tmux_cmd new-session -d -s "$actual" -c "$path" "$bin exec -C '$path' - < '$brief' > '$log' 2>&1; echo EXIT=\$? >> '$log'" \
    || err "could not create tmux session '$actual'; check tmux and retry."
  write_session "$name" "$(read_json "$f" branch)" "$path" "$actual"
  set_run_state "$name" running
  printf 'session %s\nlog %s\n' "$actual" "$log"
  # Default: block until the run ends and print the verdict, so one background command both launches
  # and reports (nothing to forget). --detach returns at once; then run `wt.sh wait <session>` yourself.
  if (( detach )); then printf 'next: bash scripts/wt.sh wait %s   (run as a background command)\n' "$actual"; else cmd_wait "$actual" "${MAIPAI_WT_RUN_TIMEOUT:-3600}"; fi
}

# wait <tmux-session> [timeout-seconds, default 3600]: blocks, then prints one verdict line
# (DONE, FAILED, DIED or TIMEOUT), the log tail and the report's gate lines.
cmd_wait() {
  [[ $# -ge 1 && $# -le 2 ]] || err "wait needs a session name and an optional timeout; use: wt.sh wait <tmux-session> [seconds]." 2
  local actual="$1" limit="${2:-3600}" log waited=0 verdict code
  log="$(run_log "$actual")"; [[ -f "$log" ]] || err "no run log for '$actual'; start it with wt.sh run."
  while :; do
    if grep -q '^EXIT=' "$log"; then code="$(grep '^EXIT=' "$log" | tail -1 | cut -d= -f2)"
      [[ "$code" == 0 ]] && verdict="DONE" || verdict="FAILED (exit $code)"; break; fi
    if ! tmux_cmd has-session -t "$actual" >/dev/null 2>&1; then verdict="DIED (tmux session gone, no EXIT line)"; break; fi
    if (( waited >= limit )); then verdict="TIMEOUT after ${limit}s (still running; attach or kill it)"; break; fi
    sleep "${MAIPAI_WT_POLL:-5}"; waited=$((waited + ${MAIPAI_WT_POLL:-5}))
  done
  local sf; for sf in "$WT_SESSION_DIR"/*.json; do
    [[ -f "$sf" && "$(read_json "$sf" tmux)" == "$actual" ]] && set_run_state "$(basename "$sf" .json)" "${verdict%% *}"
  done
  echo "codex run $actual: $verdict"
  echo "-- last log lines"; tail -n 8 "$log"
  if ls "$WT_MAIN"/data-scratch/reports/*.md >/dev/null 2>&1; then
    echo "-- newest report gate lines"
    grep -i -h -E 'gate|pass|fail' "$(ls -t "$WT_MAIN"/data-scratch/reports/*.md | head -1)" | head -8 || true
  fi
  [[ "$verdict" == DONE ]]
}

cmd_port() {
  mkdir -p "$WT_PORT_DIR"
  local p file
  for p in $(seq 8800 8899); do
    file="$WT_PORT_DIR/$p.lease"
    if [[ -e "$file" ]]; then
      local oldpid; oldpid="$(awk 'NR==1 {print $1}' "$file" 2>/dev/null || true)"
      if [[ -n "$oldpid" ]] && kill -0 "$oldpid" 2>/dev/null; then continue; fi
      rm -f "$file"
    fi
    if ! (echo >/dev/tcp/127.0.0.1/$p) >/dev/null 2>&1; then
      if (set -o noclobber; printf '%s %s\n' "${MAIPAI_WT_PID:-$PPID}" "${MAIPAI_WT_SESSION:-$(current_session_name)}" > "$file") 2>/dev/null; then
        printf '%s\n' "$p"; return 0
      fi
    fi
  done
  err "no free port in 8800-8899; stop an unused server or release a stale lease."
}

changed_files() {
  local base="$1"
  git -C "$WT_ROOT" diff --name-only "$base"...HEAD
  git -C "$WT_ROOT" diff --name-only
  git -C "$WT_ROOT" diff --cached --name-only
  git -C "$WT_ROOT" ls-files --others --exclude-standard
}

classify_tier() {
  local files=() f t2=0 all_docs=1 t2globs=() glob
  set -f; read -r -a t2globs <<< "$WT_T2_GLOBS"; set +f
  if (( $# )); then files=("$@")
  else
    local base
    base="$(git -C "$WT_ROOT" merge-base HEAD origin/main 2>/dev/null)" || err "cannot find merge-base with origin/main; fetch origin/main and retry."
    while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done < <({ git -C "$WT_ROOT" diff --cached --name-only; changed_files "$base"; } | sort -u)
  fi
  for f in ${files[@]+"${files[@]}"}; do
    case "$f" in docs/api/*) all_docs=0;; *.md|docs/*|screenshots/*|*.png|*.jpg|*.jpeg|*.webp|*.avif|*.gif) :;; *) all_docs=0;; esac
    # Always risky: the gate itself, pins and lockfiles, the worktree scripts, design rules and plans.
    case "$f" in docs/design/RULES.md|docs/plans/*|scripts/check.sh|scripts/wt.sh|package.json|*/package.json|bun.lock|*/bun.lock|*/uv.lock|*/pyproject.toml) t2=1;; esac
    for glob in ${t2globs[@]+"${t2globs[@]}"}; do
      # shellcheck disable=SC2254
      case "$f" in $glob) t2=1;; esac
    done
  done
  if (( t2 )); then echo T2; elif (( all_docs )) && (( ${#files[@]} )); then echo T0; else echo T1; fi
}

cmd_tier() { printf '%s\n' "$(classify_tier "$@")"; }

# T1 tests: the test files that sit beside, or mention the name of, a changed file.
# Each workspace has its own bunfig preload, so its tests run from inside it.
run_beside_tests() {
  local tests=() f dir testfile base_name ws group line rc=0 uniq
  for f in "$@"; do
    dir="$(dirname "$f")"
    base_name="$(basename "$f")"; base_name="${base_name%.*}"
    for testfile in "$WT_ROOT/$dir"/*.test.ts "$WT_ROOT/$dir"/*.test.tsx; do [[ -f "$testfile" ]] && tests+=("${testfile#"$WT_ROOT"/}"); done
    for ws in $WT_TEST_WORKSPACES; do
      [[ -d "$WT_ROOT/$ws" ]] || continue
      while IFS= read -r testfile; do [[ -n "$testfile" ]] && tests+=("$ws/${testfile#./}"); done < <(cd "$WT_ROOT/$ws" && grep -rlF --include='*.test.ts' --include='*.test.tsx' --exclude-dir=node_modules -e "$base_name" . 2>/dev/null || true)
    done
  done
  for ws in $WT_TEST_WORKSPACES; do
    group=()
    for testfile in ${tests[@]+"${tests[@]}"}; do
      if [[ "$ws" == . ]]; then group+=("./$testfile"); elif [[ "$testfile" == "$ws/"* ]]; then group+=("./${testfile#"$ws"/}"); fi
    done
    (( ${#group[@]} )) || continue
    uniq=()
    while IFS= read -r line; do uniq+=("$line"); done < <(printf '%s\n' "${group[@]}" | sort -u)
    (cd "$WT_ROOT/$ws" && bun test "${uniq[@]}") || rc=$?
  done
  return "$rc"
}

cmd_check() {
  local requested="${1:-}" base name tier auto_tier rc=0 sha
  [[ $# -le 1 ]] || err "check accepts at most one tier; use: wt.sh check [T0|T1|T2]." 2
  base="$(git -C "$WT_ROOT" merge-base HEAD origin/main 2>/dev/null)" || err "cannot find merge-base with origin/main; fetch origin/main and retry."
  name="${MAIPAI_WT_SESSION:-$(current_session_name)}"; [[ -n "$name" ]] || name="$(git -C "$WT_ROOT" branch --show-current | sed 's#^wt/##')"
  local files=() f
  while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done < <(changed_files "$base" | sort -u)
  auto_tier="$(classify_tier ${files[@]+"${files[@]}"})"
  tier="$auto_tier"
  if [[ -n "$requested" ]]; then
    requested="$(printf '%s' "$requested" | tr '[:lower:]' '[:upper:]')"
    [[ "$requested" =~ ^T[012]$ ]] || err "unknown tier '$requested'; use T0, T1, or T2."
    local auto_rank=1 requested_rank=1
    [[ "$auto_tier" == T0 ]] && auto_rank=0
    [[ "$auto_tier" == T2 ]] && auto_rank=2
    [[ "$requested" == T0 ]] && requested_rank=0
    [[ "$requested" == T2 ]] && requested_rank=2
    if (( requested_rank > auto_rank )); then tier="$requested"
    elif (( requested_rank < auto_rank )); then echo "wt: requested $requested is below diff-required $auto_tier; running $auto_tier."
    fi
  fi
  local script="$WT_ROOT/scripts/check.sh"
  local check_env=("MAIPAI_COMMONS_DIR=$WT_PARENT/commons" "MAIPAI_STANDARDS_DIR=$WT_PARENT/.github")
  if [[ "$tier" == T0 ]]; then env "${check_env[@]}" bash "$script" --docs || rc=$?
  elif [[ "$tier" == T1 ]]; then
    env "${check_env[@]}" bash "$script" --pre || rc=$?
    if (( rc == 0 )); then
      if [[ -n "$WT_TEST_HOOK" ]]; then
        (cd "$WT_ROOT" && env "${check_env[@]}" bash "$WT_TEST_HOOK" ${files[@]+"${files[@]}"}) || rc=$?
      else run_beside_tests ${files[@]+"${files[@]}"} || rc=$?; fi
    fi
  else env "${check_env[@]}" bash "$script" || rc=$?; fi
  sha="$(git -C "$WT_ROOT" rev-parse HEAD)"
  mkdir -p "$WT_STAMP_DIR"
  node - "$tier" "$sha" "$rc" "$WT_ROOT" ${files[@]+"${files[@]}"} <<'NODE' > "$WT_STAMP_DIR/$name.json"
const cp=require("child_process");
const [tier, head, code, root, ...files] = process.argv.slice(2);
const manifest=Object.fromEntries(files.map(p=>{try{return [p,cp.execFileSync("git",["-C",root,"hash-object","--",p],{encoding:"utf8"}).trim()]}catch{return [p,"0000000000000000000000000000000000000000"]}}));
console.log(JSON.stringify({tier, head, exitCode:Number(code), created:new Date().toISOString(), manifest}, null, 2));
NODE
  return "$rc"
}

cmd_done() {
  [[ $# == 0 ]] || err "done takes no arguments; use the current worktree's session file." 2
  local branch path name f tmuxname
  name="${MAIPAI_WT_SESSION:-$(current_session_name)}"; f="$(session_file "$name")"
  if [[ ! -f "$f" ]]; then
    local candidate candidate_pid matches=()
    for candidate in "$WT_SESSION_DIR"/*.json; do
      [[ -f "$candidate" ]] || continue
      candidate_pid="$(read_json "$candidate" pid)"
      [[ "$candidate_pid" == "${MAIPAI_WT_PID:-$PPID}" ]] && matches+=("$candidate")
    done
    if (( ${#matches[@]} == 1 )); then f="${matches[0]}"; name="$(basename "$f" .json)"; fi
  fi
  if [[ -f "$f" ]]; then
    branch="$(read_json "$f" branch)"; path="$(read_json "$f" path)"; tmuxname="$(read_json "$f" tmux)"
  else branch="$(git -C "$WT_ROOT" branch --show-current)"; path="$WT_ROOT"; tmuxname=""; fi
  if [[ -n "$tmuxname" ]] && command -v tmux >/dev/null 2>&1; then tmux_cmd kill-session -t "$tmuxname" >/dev/null 2>&1 || true; fi
  if [[ "$path" != "$WT_MAIN" ]] && git -C "$WT_MAIN" worktree list --porcelain | grep -Fqx "worktree $path"; then git -C "$WT_MAIN" worktree remove --force "$path" || err "could not remove worktree '$path'; resolve its Git state and retry wt.sh done."; fi
  if [[ "$branch" == wt/* ]] && git -C "$WT_MAIN" show-ref --verify --quiet "refs/heads/$branch"; then git -C "$WT_MAIN" branch -D "$branch" >/dev/null || err "could not delete branch '$branch'; remove it manually after checking its work is landed."; fi
  rm -f "$f"
  find "$WT_PORT_DIR" -type f -name '*.lease' -exec grep -lF "$name" {} \; -delete 2>/dev/null || true
}

cmd_reap() {
  mkdir -p "$WT_SESSION_DIR" "$WT_PORT_DIR"
  local f name pid tmuxname path branch alive dirty created age
  shopt -s nullglob
  for f in "$WT_SESSION_DIR"/*.json; do
    name="$(basename "$f" .json)"; pid="$(read_json "$f" pid)"; tmuxname="$(read_json "$f" tmux)"; path="$(read_json "$f" path)"; branch="$(read_json "$f" branch)"
    alive=0; [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && alive=1
    if [[ -n "$tmuxname" ]] && command -v tmux >/dev/null 2>&1 && tmux_cmd has-session -t "$tmuxname" >/dev/null 2>&1; then alive=1; fi
    (( alive )) && continue
    # A session's pid is the caller's shell, which can exit while the session lives on,
    # so only sessions older than the grace period (default 4 h) are ever reaped.
    created="$(read_json "$f" created)"
    age=$(( $(date +%s) - $(date -u -j -f '%Y-%m-%dT%H:%M:%S' "${created%.*}" +%s 2>/dev/null || date -u -d "$created" +%s 2>/dev/null || echo 0) ))
    (( age >= ${MAIPAI_WT_REAP_AGE:-14400} )) || continue
    if [[ ! -e "$path/.git" ]]; then rm -f "$f"; continue; fi
    dirty="$(git -C "$path" status --porcelain)"
    if [[ -z "$dirty" ]] && git -C "$WT_MAIN" merge-base --is-ancestor "$branch" origin/main 2>/dev/null; then
      git -C "$WT_MAIN" worktree remove "$path" && git -C "$WT_MAIN" branch -D "$branch" >/dev/null 2>&1 || true
      rm -f "$f"
    else
      git -C "$path" add -A
      if ! git -C "$path" diff --cached --quiet; then git -C "$path" -c user.name='MaiPai Reaper' -c user.email='reaper@localhost' commit -m "WIP: recover $name" >/dev/null || true; fi
      git -C "$path" branch -f "wip/$name" HEAD >/dev/null 2>&1 || true
      mkdir -p "$WT_DATA"
      printf '%s | %s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$name" "$path" >> "$WT_DATA/reaped.md"
      # Leave dirty/recovered worktree and session record for explicit recovery.
    fi
  done
  for f in "$WT_PORT_DIR"/*.lease; do
    pid="$(awk 'NR==1 {print $1}' "$f" 2>/dev/null || true)"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null || rm -f "$f"
  done
}

# Refuse to push unless this session's gate stamp is green, at least as strong as the
# changed files need, fresh (default 30 minutes), and about exactly the committed content.
require_gate_stamp() {
  local name="$1" stamp files=() f required tag="MAIPAI_WT_SESSION=$1 bash scripts/wt.sh check"
  stamp="$WT_STAMP_DIR/$name.json"
  [[ -f "$stamp" ]] || err "no gate stamp for session '$name' at $stamp, so nothing proves these commits were checked. Run: $tag"
  while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done < <(git -C "$WT_ROOT" diff --name-only origin/main...HEAD | sort -u)
  required="$(classify_tier ${files[@]+"${files[@]}"})"
  local verdict
  verdict="$(node - "$stamp" "$required" "${MAIPAI_WT_STAMP_MAX_AGE:-1800}" "$WT_ROOT" ${files[@]+"${files[@]}"} <<'NODE'
const cp = require("child_process"), fs = require("fs");
const [stampPath, required, maxAge, root, ...files] = process.argv.slice(2);
let s;
try { s = JSON.parse(fs.readFileSync(stampPath, "utf8")); } catch { console.log("unreadable"); process.exit(0); }
if (s.exitCode !== 0) { console.log("failed:" + s.exitCode); process.exit(0); }
const rank = { T0: 0, T1: 1, T2: 2 };
if (!(s.tier in rank) || rank[s.tier] < rank[required]) { console.log(`tier:${s.tier}:${required}`); process.exit(0); }
const age = (Date.now() - Date.parse(s.created)) / 1000;
if (!(age >= -60) || age > Number(maxAge)) { console.log("stale:" + Math.round(age)); process.exit(0); }
const manifest = s.manifest || {};
const stampFiles = Object.keys(manifest).sort(), want = [...files].sort();
const blob = (p) => { try { return cp.execFileSync("git", ["-C", root, "rev-parse", `HEAD:${p}`], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); } catch { return "0000000000000000000000000000000000000000"; } };
const drift = new Set(stampFiles.filter((p) => !want.includes(p)).concat(want.filter((p) => !stampFiles.includes(p))));
for (const p of stampFiles) if (want.includes(p) && manifest[p] !== blob(p)) drift.add(p);
if (drift.size) { console.log("content:" + [...drift].slice(0, 5).join(",")); process.exit(0); }
console.log("ok");
NODE
)"
  case "$verdict" in
    ok) return 0;;
    unreadable) err "gate stamp $stamp is not valid JSON, so it proves nothing. Run: $tag";;
    failed:*) err "the last check for session '$name' failed (exit code ${verdict#failed:}), so these commits are not safe to land. Fix the failures, then run: $tag";;
    tier:*) local pair="${verdict#tier:}"; err "the gate stamp covers tier ${pair%%:*} but the changed files need tier ${pair##*:}. Run: $tag ${pair##*:}";;
    stale:*) err "the gate stamp for session '$name' is ${verdict#stale:} seconds old and only 30 minutes counts. Run: $tag";;
    content:*) err "the committed files changed since the gate stamp was written (${verdict#content:}). Run: $tag";;
    *) err "could not verify the gate stamp ($verdict). Run: $tag";;
  esac
}

cmd_land() {
  [[ $# == 0 ]] || err "land takes no arguments; run it from the active worktree." 2
  need_cmd git
  git -C "$WT_ROOT" fetch origin || err "could not fetch origin; check network access and retry landing."
  local before after attempt changed_pin changed_pkg name d
  before="$(git -C "$WT_ROOT" rev-parse HEAD)"
  for attempt in 1 2 3; do
    git -C "$WT_ROOT" rebase origin/main || { git -C "$WT_ROOT" rebase --abort >/dev/null 2>&1 || true; err "rebase onto origin/main failed; resolve the conflict and rerun wt.sh land."; }
    after="$(git -C "$WT_ROOT" rev-parse HEAD)"
    if [[ "$after" != "$before" ]]; then
      # Package metadata or a lockfile moved in the rebase: refresh the installs before re-checking.
      changed_pkg="$(git -C "$WT_ROOT" diff --name-only "$before" "$after" | grep -E '(^|/)(package\.json|bun\.lock)$' || true)"
      if [[ -n "$changed_pkg" ]]; then
        for d in $WT_INSTALL_DIRS; do [[ -d "$WT_ROOT/$d" ]] && { (cd "$WT_ROOT/$d" && bun install --force) || err "bun install --force failed in $d after the rebase changed package metadata; fix the install error and rerun wt.sh land."; }; done
      fi
      cmd_check || err "checks failed after rebase; fix the failures before landing."
    fi
    name="${MAIPAI_WT_SESSION:-$(current_session_name)}"
    require_gate_stamp "$name"
    changed_pin="$(git -C "$WT_ROOT" diff origin/main...HEAD -- scripts/check.sh '*package.json' | grep -E '^[+-].*(core-v|ui-v|spec-v|std-v)' || true)"
    if git -C "$WT_ROOT" push origin HEAD:main; then
      [[ -z "$changed_pin" || -z "${WT_PIN_REMINDER:-}" ]] || echo "Reminder: $WT_PIN_REMINDER"
      cmd_done
      return 0
    fi
    if (( attempt < 3 )); then git -C "$WT_ROOT" fetch origin || err "push was rejected and fetch failed; retry wt.sh land after network access returns."; before="$(git -C "$WT_ROOT" rev-parse HEAD)"; fi
  done
  err "push to origin/main was rejected three times; inspect origin/main and rerun wt.sh land."
}

case "${1:-}" in
  start|land|check|done) "$(dirname "${BASH_SOURCE[0]}")/origin-guard.sh" "$WT_ROOT" || exit 1;; esac

case "${1:-}" in
  start) shift; cmd_start "$@";;
  tmux) shift; cmd_tmux "$@";;
  run) shift; cmd_run "$@";;
  wait) shift; cmd_wait "$@";;
  port) shift; [[ $# == 0 ]] || err "port takes no arguments; use: wt.sh port." 2; cmd_port;;
  check) shift; cmd_check "$@";;
  tier) shift; cmd_tier "$@";;
  land) shift; cmd_land "$@";;
  done) shift; cmd_done "$@";;
  reap) shift; [[ $# == 0 ]] || err "reap takes no arguments; use: wt.sh reap." 2; cmd_reap;;
  *) err "unknown or missing command '${1:-}'; use start, tmux, run, wait, port, check, land, done, or reap." 2;;
esac
