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
# wt.sh's own scratch inside a worktree is never work, even in a repo that does not ignore data-scratch/.
WT_OWN_SCRATCH=':(exclude)data-scratch/gate-stamps'
WT_INSTALL_DIRS="${WT_INSTALL_DIRS:-}"
WT_T2_GLOBS="${WT_T2_GLOBS:-}"
WT_TEST_WORKSPACES="${WT_TEST_WORKSPACES:-}"
WT_TEST_HOOK="${WT_TEST_HOOK:-}"
WT_ADJECTIVES=(amber brisk calm clever eager fair gentle happy keen lucky mild nimble quiet swift)
WT_ANIMALS=(badger falcon heron otter panda robin tiger yak)

err() { echo "wt: $1" >&2; exit "${2:-1}"; }
need_cmd() {
  command -v "$1" >/dev/null 2>&1 && return 0
  # Homebrew on Apple silicon lives outside the PATH a non-login shell sees; say so, never edit PATH silently.
  if [[ -x "/opt/homebrew/bin/$1" ]]; then
    err "$1 is not on PATH but exists at /opt/homebrew/bin/$1; run: export PATH=\"/opt/homebrew/bin:\$PATH\" and retry."
  fi
  err "$1 is required; install it and retry."
}
# The run command is one string handed to tmux's shell, so a bin or path with quote, expansion or
# redirection characters could change what runs. Reject them rather than escape them.
unsafe_chars() { [[ "$1" == *[\'\"\;\$\&\|\<\>\`\\]* || "$1" == *$'\n'* ]]; }
valid_name() { [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]; }
rand_index() { od -An -N4 -tu4 /dev/urandom | awk -v n="$1" 'NR == 1 {print $1 % n; exit}'; }
make_name() { echo "${WT_ADJECTIVES[$(rand_index "${#WT_ADJECTIVES[@]}")]}-${WT_ANIMALS[$(rand_index "${#WT_ANIMALS[@]}")]}-$1"; }

session_file() { printf '%s/%s.json' "$WT_SESSION_DIR" "$1"; }
# read_json <file> <field>: the field's value, or nothing when the file is missing, empty or not JSON. It never
# fails, so one corrupt session file cannot abort a command (set -e) for the other sessions.
read_json() { node -e 'try{const fs=require("fs");const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(String(j[process.argv[2]]??""))}catch{}' "$1" "$2" || true; }
# session_ok <file>: succeeds when the file is a readable JSON object. session_usable also says why it is skipped.
session_ok() { node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.exit(j&&typeof j==="object"&&!Array.isArray(j)?0:1)}catch{process.exit(1)}' "$1" 2>/dev/null; }
session_usable() {
  session_ok "$1" && return 0
  echo "wt: session file $1 is unreadable (empty, truncated or not JSON); skipping it. Delete it if its session is finished." >&2
  return 1
}
# Session files are only ever replaced whole: write a temp file in the same directory, then rename it over the
# live file. A reader or a second writer never sees a truncated file; with two writers the last rename wins.
atomic_write() {
  local f="$1" tmp; tmp="$f.tmp.$$.$RANDOM"
  if cat > "$tmp" && [[ -s "$tmp" ]]; then mv -f "$tmp" "$f"; else rm -f "$tmp"; return 1; fi
}
# Heartbeat: a file touched by start, run, wait, check and land. The reaper reads it as proof of life;
# the recorded pid (the short-lived shell that ran `start`) is never proof of anything.
beat() { [[ -n "${1:-}" ]] || return 0; mkdir -p "$WT_SESSION_DIR" 2>/dev/null && touch "$WT_SESSION_DIR/$1.beat" 2>/dev/null || true; }
write_session() {
  local name="$1" branch="$2" path="$3" tmux="${4:-}"
  mkdir -p "$WT_SESSION_DIR"; beat "$name"
  node - "$name" "$branch" "$path" "$tmux" "${MAIPAI_WT_PID:-$PPID}" <<'NODE' | atomic_write "$(session_file "$name")"
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
  install_origin_guard_hook
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
  local d commons
  commons="${MAIPAI_COMMONS_DIR:-$WT_PARENT/commons}"
  for d in $WT_INSTALL_DIRS; do
    if [[ -f "$path/$d/package.json" ]]; then
      while IFS=$'\t' read -r workspace tag folder; do
        [[ -n "$folder" ]] || continue
        [[ -e "$WT_PARENT/commons-tags/$folder" ]] && continue
        if ! bash "$commons/scripts/ensure-tag.sh" "$workspace" "$tag"; then
          git -C "$WT_MAIN" worktree remove --force "$path" >/dev/null 2>&1 || true
          git -C "$WT_MAIN" branch -D "$branch" >/dev/null 2>&1 || true
          err "could not create the commons tag worktree $folder; fetch the commons repo (git -C $commons fetch --tags) and rerun wt.sh start $slug."
        fi
      done < <(node - "$path/$d/package.json" <<'NODE'
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
for (const section of ["dependencies", "devDependencies", "optionalDependencies", "peerDependencies"]) {
  for (const value of Object.values(pkg[section] || {})) {
    if (typeof value !== "string") continue;
    const match = value.match(/^file:\.\.\/\.\.\/commons-tags\/([^/]+)\/([^/]+)$/);
    if (!match) continue;
    const [, folder, workspace] = match;
    const tag = folder.slice(workspace.length + 1);
    if (folder.startsWith(`${workspace}-${workspace}-`) && tag.startsWith(`${workspace}-`)) {
      console.log(`${workspace}\t${tag}\t${folder}`);
    }
  }
}
NODE
)
    fi
  done
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
      session_usable "$candidate" || continue
      candidate_pid="$(read_json "$candidate" pid)"
      [[ "$candidate_pid" == "${MAIPAI_WT_PID:-$PPID}" ]] && matches+=("$candidate")
    done
    if (( ${#matches[@]} == 1 )); then f="${matches[0]}"; name="$(basename "$f" .json)"; fi
  fi
  [[ -f "$f" ]] || err "no session file for this worktree; run wt.sh start <slug> and enter its worktree first."
  need_cmd tmux; need_cmd node
  session_ok "$f" || err "session file $f is unreadable (empty, truncated or not JSON); delete it and run wt.sh start <slug> again."
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
  beat "$1"
  session_usable "$f" || return 0
  node - "$f" "$2" <<'NODE' | atomic_write "$f" || true
const fs = require("fs"); const [f, state] = process.argv.slice(2);
let j; try { j = JSON.parse(fs.readFileSync(f, "utf8")); } catch { process.exit(1); }
j.runState = state; j.runStateAt = new Date().toISOString();
process.stdout.write(JSON.stringify(j, null, 2) + "\n");
NODE
}
beat_for_tmux() {
  local sf; for sf in "$WT_SESSION_DIR"/*.json; do
    [[ -f "$sf" ]] && session_ok "$sf" && [[ "$(read_json "$sf" tmux)" == "$1" ]] && beat "$(basename "$sf" .json)"
  done
  return 0
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
  need_cmd tmux; need_cmd node
  session_ok "$f" || err "session file $f is unreadable (empty, truncated or not JSON); delete it and run wt.sh start <slug> again."
  path="$(read_json "$f" path)"
  actual="$WT_REPO-${name}-$purpose"
  tmux_cmd has-session -t "$actual" >/dev/null 2>&1 && err "tmux session '$actual' already exists; wait for it or pick another purpose name."
  mkdir -p "$WT_DATA/runs"; log="$(run_log "$actual")"; : > "$log"
  # `codex exec` defaults to a read-only sandbox, which blocks every edit. Writes inside the worktree only
  # (owner's ruling, 2026-10-17): always workspace-write, never a full-access or bypass flag.
  # MAIPAI_CODEX_BIN replaces only the binary; the sandbox flag stays on the command line.
  bin="${MAIPAI_CODEX_BIN:-codex}"
  if unsafe_chars "$bin" || [[ "$bin" =~ [[:space:]] ]]; then
    err "MAIPAI_CODEX_BIN must be a program name or path only (no spaces, arguments, quotes or shell characters); put extra setup in a wrapper script and set MAIPAI_CODEX_BIN to its path."
  fi
  unsafe_chars "$brief" && err "brief path '$brief' has a quote or shell character; rename the file to letters, digits, dots, hyphens and underscores."
  unsafe_chars "$path" && err "worktree path '$path' has a quote or shell character; the run cannot be launched safely."
  tmux_cmd new-session -d -s "$actual" -c "$path" "MAIPAI_TEST_NO_PORTS=1 \"$bin\" exec -s workspace-write -C '$path' - < '$brief' > '$log' 2>&1; echo EXIT=\$? >> '$log'" \
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
    if ! tmux_cmd has-session -t "$actual" >/dev/null 2>&1; then
      # The run can finish between the EXIT check above and this one; look once more before calling it dead.
      if grep -q '^EXIT=' "$log"; then continue; fi
      verdict="DIED (tmux session gone, no EXIT line)"; break
    fi
    if (( waited >= limit )); then verdict="TIMEOUT after ${limit}s (still running; attach or kill it)"; break; fi
    beat_for_tmux "$actual"
    sleep "${MAIPAI_WT_POLL:-5}"; waited=$((waited + ${MAIPAI_WT_POLL:-5}))
  done
  local sf; for sf in "$WT_SESSION_DIR"/*.json; do
    [[ -f "$sf" ]] && session_ok "$sf" && [[ "$(read_json "$sf" tmux)" == "$actual" ]] && set_run_state "$(basename "$sf" .json)" "${verdict%% *}"
  done
  echo "codex run $actual: $verdict"
  echo "-- last log lines"; tail -n 8 "$log"
  if [[ "$verdict" == DONE ]]; then
    local wpath="" wsf; for wsf in "$WT_SESSION_DIR"/*.json; do
      [[ -f "$wsf" ]] && session_ok "$wsf" && [[ "$(read_json "$wsf" tmux)" == "$actual" ]] && { wpath="$(read_json "$wsf" path)"; break; }
    done
    if [[ -n "$wpath" && -d "$wpath" ]]; then
      echo "-- worktree changes (Codex leaves them uncommitted; you review, test and commit by file name)"
      git -C "$wpath" status --short || true
      git -C "$wpath" diff --stat HEAD || true
    fi
  fi
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
  git -C "$WT_ROOT" ls-files --others --exclude-standard -- . "$WT_OWN_SCRATCH"
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
    # Always risky: the design rules and the gate itself. Pins, lockfiles and plans are T1 since
    # 2026-10-16 (GATE-FAST-01): a pin bump ran 438 full gates in 8 days and found nothing a T1 did not.
    # classify_tier reports the full tier; blocking_tier decides what a land must prove (2026-10-23, Jesse).
    case "$f" in docs/design/RULES.md|scripts/check.sh|scripts/wt.sh) t2=1;; esac
    for glob in ${t2globs[@]+"${t2globs[@]}"}; do
      # shellcheck disable=SC2254
      case "$f" in $glob) t2=1;; esac
    done
  done
  if (( t2 )); then echo T2; elif (( all_docs )) && (( ${#files[@]} )); then echo T0; else echo T1; fi
}

# blocking_tier: the tier a check or land must pass inline. The full gate (T2) never blocks: a T2 diff
# needs the quick T1 check here, and the full gate runs after the land (home's post-land main gate,
# RELEASE-GATE-01). `wt.sh check T2` still runs the full gate on demand.
blocking_tier() {
  local t
  t="$(classify_tier "$@")"
  [[ "$t" == T2 ]] && t=T1
  echo "$t"
}

cmd_tier() { printf '%s\n' "$(classify_tier "$@")"; }

# T1 tests: the test files that sit beside, or mention the name of, a changed file.
# Each workspace has its own bunfig preload, so its tests run from inside it.
# select_tests <workspace-dir> <changed-file>: prints "<test path relative to the workspace>\t<reason>" lines.
# A changed TS/JS module selects its own sibling test plus every test that IMPORTS it (import, require,
# mock.module, vi.mock or dynamic import), resolving relative specifiers against the test's directory and
# matching path-like specifiers ('lib/apps', '@/lib/apps') by suffix. A bare name in a string or comment
# selects nothing. Other changed files (JSON, docs, config) fall back to a bare-name grep.
select_tests() {
  WT_SEL_ROOT="$WT_ROOT" node - "$1" "$2" <<'NODE'
const fs = require("fs"), path = require("path");
const [ws, changed] = process.argv.slice(2);
const root = process.env.WT_SEL_ROOT;
const wsAbs = path.join(root, ws), file = path.join(root, changed);
const isTest = (n) => /\.test\.(ts|tsx)$/.test(n);
const tests = [];
(function walk(d) {
  let ents; try { ents = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    if (e.name === "node_modules" || e.name === ".git") continue;
    const full = path.join(d, e.name);
    if (e.isDirectory()) walk(full); else if (isTest(e.name)) tests.push(full);
  }
})(wsAbs);
const rel = (t) => path.relative(wsAbs, t);
const out = new Map();
const add = (t, why) => { if (!out.has(t)) out.set(t, why); };
const ext = path.extname(file), stem = file.slice(0, file.length - ext.length), name = path.basename(stem);
if (isTest(file)) add(file, "the changed file is itself a test");
if (/^\.(ts|tsx|js|jsx|mts|cts|mjs)$/.test(ext)) {
  for (const x of [".test.ts", ".test.tsx"]) { const sib = stem + x; if (fs.existsSync(sib)) add(sib, "sibling test of " + path.basename(file)); }
  const targets = [stem]; if (name === "index") targets.push(path.dirname(file));
  const re = /(?:\bfrom\s*|\bimport\s*\(?\s*|\brequire\s*\(\s*|\bmock\.module\s*\(\s*|\bvi\.(?:mock|doMock)\s*\(\s*|\bjest\.mock\s*\(\s*)(['"])([^'"\n]+)\1/g;
  for (const t of tests) {
    if (out.has(t)) continue;
    const src = fs.readFileSync(t, "utf8"); let m; re.lastIndex = 0;
    while ((m = re.exec(src))) {
      let spec = m[2].replace(/\.(js|jsx|ts|tsx|mjs|mts)$/, "");
      let hit = false;
      if (spec.startsWith(".")) { const abs = path.resolve(path.dirname(t), spec); hit = targets.some((x) => abs === x); }
      else if (spec.includes("/")) {
        const s2 = spec.replace(/^(@|~|#)\//, "");
        hit = targets.some((x) => x.endsWith("/" + s2));
      }
      if (hit) { add(t, "imports " + m[2]); break; }
    }
  }
} else {
  const dir = path.dirname(file);
  for (const t of tests) if (path.dirname(t) === dir) add(t, "beside the changed file");
  for (const t of tests) if (!out.has(t) && fs.readFileSync(t, "utf8").includes(name)) add(t, "mentions '" + name + "' (non-TS change)");
}
for (const [t, why] of out) console.log(rel(t) + "\t" + why);
NODE
}

run_beside_tests() {
  local ws f line rc=0 cap="${MAIPAI_WT_T1_CAP:-60}" n i group t why
  local -a rows picked
  for ws in $WT_TEST_WORKSPACES; do
    [[ -d "$WT_ROOT/$ws" ]] || continue
    rows=()
    for f in "$@"; do
      [[ "$f" == "$ws/"* || "$ws" == . ]] || continue
      local relf="$f"; [[ "$ws" == . ]] || relf="$f"
      while IFS= read -r line; do [[ -n "$line" ]] && rows+=("$line"); done < <(select_tests "$ws" "$relf")
    done
    (( ${#rows[@]} )) || continue
    picked=(); group=()
    while IFS= read -r line; do picked+=("$line"); done < <(printf '%s\n' "${rows[@]}" | awk -F'\t' '!seen[$1]++')
    n=${#picked[@]}
    echo "== T1 tests in $ws: $n selected"
    i=0
    for line in "${picked[@]}"; do
      t="${line%%$'\t'*}"; why="${line#*$'\t'}"
      if (( i < cap )); then echo "   $t  ($why)"; group+=("./$t"); fi
      i=$((i + 1))
    done
    (( n > cap )) && echo "   $((n - cap)) more tests also match and are NOT run here (cap $cap, MAIPAI_WT_T1_CAP); run 'bash scripts/wt.sh check T2' for the full suite."
    # Same 20 s per-test timeout as scripts/gate/shardTests.ts (getmaipai/home#216): bun's 5 s default
    # failed the app port and stop-dev-home tests under gate load on 2026-10-23.
    (cd "$WT_ROOT/$ws" && heavy_run "$WT_REPO-tests" bun test --timeout 20000 "${group[@]}") || rc=$?
  done
  return "$rc"
}

cmd_check() {
  local requested="${1:-}" base name tier auto_tier rc=0 sha
  [[ $# -le 1 ]] || err "check accepts at most one tier; use: wt.sh check [T0|T1|T2]." 2
  base="$(git -C "$WT_ROOT" merge-base HEAD origin/main 2>/dev/null)" || err "cannot find merge-base with origin/main; fetch origin/main and retry."
  name="${MAIPAI_WT_SESSION:-$(current_session_name)}"; [[ -n "$name" ]] || name="$(git -C "$WT_ROOT" branch --show-current | sed 's#^wt/##')"
  beat "$name"
  local files=() f
  while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done < <(changed_files "$base" | sort -u)
  auto_tier="$(blocking_tier ${files[@]+"${files[@]}"})"
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
  if [[ "$tier" == T0 ]]; then env "${check_env[@]}" bash "$script" --docs || rc=$?  # docs only: light, no slot
  elif [[ "$tier" == T1 ]]; then
    heavy_run "$WT_REPO-pre" env "${check_env[@]}" bash "$script" --pre || rc=$?
    if (( rc == 0 )); then
      if [[ -n "$WT_TEST_HOOK" ]]; then
        (cd "$WT_ROOT" && heavy_run "$WT_REPO-tests" env "${check_env[@]}" bash "$WT_TEST_HOOK" ${files[@]+"${files[@]}"}) || rc=$?
      else run_beside_tests ${files[@]+"${files[@]}"} || rc=$?; fi
    fi
  else heavy_run "$WT_REPO-gate" env "${check_env[@]}" bash "$script" || rc=$?; fi
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

# refuse_unlanded <branch> <path>: exits with the evidence when removing this worktree or deleting this
# branch would lose work: a commit without a patch equivalent on freshly fetched origin/main, or an
# uncommitted or untracked file. A failed fetch judges against the last known origin/main, which can only refuse more.
refuse_unlanded() {
  local branch="$1" path="$2" removing=0 deleting=0 tip cherry_line cherry_sha commits="" dirty="" msg
  [[ "$path" != "$WT_MAIN" ]] && git -C "$WT_MAIN" worktree list --porcelain | grep -Fqx "worktree $path" && removing=1
  [[ "$branch" == wt/* ]] && git -C "$WT_MAIN" show-ref --verify --quiet "refs/heads/$branch" && deleting=1
  (( removing || deleting )) || return 0
  git -C "$WT_MAIN" fetch origin >/dev/null 2>&1 || echo "wt: could not fetch origin; judging against the last known origin/main." >&2
  git -C "$WT_MAIN" rev-parse --verify --quiet origin/main >/dev/null || err "origin/main is unknown, so nothing proves this work is landed; fetch origin, or discard it on purpose with: wt.sh done --abandon"
  for tip in $( (( removing )) && echo HEAD; (( ! removing && deleting )) && echo "refs/heads/$branch"); do
    while read -r cherry_line cherry_sha; do
      [[ "$cherry_line" == "+" ]] || continue
      commits+="$(git -C "$path" show -s --format='  %h %s' "$cherry_sha")"$'\n'
    done < <(git -C "$path" cherry origin/main "$tip")
  done
  (( removing )) && { dirty="$(git -C "$path" status --porcelain --untracked-files=all -- . "$WT_OWN_SCRATCH" 2>&1)" || dirty="git status failed in $path: $dirty"; }
  [[ -n "$commits$dirty" ]] || return 0
  if [[ -n "$commits" ]]; then msg="done refused, because removing this worktree would lose commits that are not on origin/main."
  else msg="done refused: every commit is on origin/main, but removing this worktree would delete the files below."; fi
  [[ -z "$commits" ]] || msg+=$'\n'"Commits on ${branch:-this worktree} not on origin/main:"$'\n'"$(printf '%s' "$commits" | awk '!seen[$0]++')"
  [[ -z "$dirty" ]] || msg+=$'\n'"Uncommitted or untracked files in $path:"$'\n'"$(printf '%s\n' "$dirty" | awk 'NR <= 20 {print "  " $0} END {if (NR > 20) print "  ... and " NR - 20 " more"}')"
  err "$msg
Either land them (commit any changes by file name, then run wt.sh land), or discard them on purpose: wt.sh done --abandon"
}

cmd_done() {
  local abandon=0
  while (( $# )); do
    case "$1" in --abandon) abandon=1;; *) err "done takes only --abandon; run it from the worktree to finish." 2;; esac
    shift
  done
  local branch path name f tmuxname
  name="${MAIPAI_WT_SESSION:-$(current_session_name)}"; f="$(session_file "$name")"
  if [[ ! -f "$f" ]]; then
    local candidate candidate_pid matches=()
    for candidate in "$WT_SESSION_DIR"/*.json; do
      [[ -f "$candidate" ]] || continue
      session_usable "$candidate" || continue
      candidate_pid="$(read_json "$candidate" pid)"
      [[ "$candidate_pid" == "${MAIPAI_WT_PID:-$PPID}" ]] && matches+=("$candidate")
    done
    if (( ${#matches[@]} == 1 )); then f="${matches[0]}"; name="$(basename "$f" .json)"; fi
  fi
  if [[ -f "$f" ]] && ! session_usable "$f"; then
    # Our own record is corrupt: finish from what git knows about this worktree, then drop the bad file.
    branch="$(git -C "$WT_ROOT" branch --show-current)"; path="$WT_ROOT"; tmuxname=""
  elif [[ -f "$f" ]]; then
    branch="$(read_json "$f" branch)"; path="$(read_json "$f" path)"; tmuxname="$(read_json "$f" tmux)"
  else branch="$(git -C "$WT_ROOT" branch --show-current)"; path="$WT_ROOT"; tmuxname=""; fi
  (( abandon )) || refuse_unlanded "$branch" "$path"
  if [[ -n "$tmuxname" ]] && command -v tmux >/dev/null 2>&1; then tmux_cmd kill-session -t "$tmuxname" >/dev/null 2>&1 || true; fi
  if [[ "$path" != "$WT_MAIN" ]] && git -C "$WT_MAIN" worktree list --porcelain | grep -Fqx "worktree $path"; then git -C "$WT_MAIN" worktree remove --force "$path" || err "could not remove worktree '$path'; resolve its Git state and retry wt.sh done."; fi
  if [[ "$branch" == wt/* ]] && git -C "$WT_MAIN" show-ref --verify --quiet "refs/heads/$branch"; then git -C "$WT_MAIN" branch -D "$branch" >/dev/null || err "could not delete branch '$branch'; remove it manually after checking its work is landed."; fi
  rm -f "$f"
  find "$WT_PORT_DIR" -type f -name '*.lease' -exec grep -lF "$name" {} \; -delete 2>/dev/null || true
}

# Directory holding the helper scripts. The repo wrappers run this file from a temp copy, so look
# beside it first and otherwise in the sibling .github checkout (the wrapper's own lookup).
std_bin() {
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -n "${WT_STD_BIN:-}" ]]; then echo "$WT_STD_BIN"; return; fi
  if [[ -f "$here/origin-guard.sh" ]]; then echo "$here"; return; fi
  local common; common="$(git rev-parse --git-common-dir)"
  case "$common" in /*) ;; *) common="$(cd "$common" && pwd)" ;; esac
  echo "$(cd "$common/.." && pwd)/../.github/standards/bin"
}

# heavy_run <label> <command...>: RUN-GUARD-01. Runs a heavy command (a gate, the beside tests) in one of the two machine-wide
# heavy slots, at background priority, with a memory cap on its own process group (gate-lock.sh heavy). MAIPAI_HEAVY_MEM_GB
# sets the cap (default: the gate-lock default); MAIPAI_HEAVY=0 runs the command directly.
heavy_run() {
  local label="$1"; shift
  if [[ "${MAIPAI_HEAVY:-1}" == 0 || ! -f "$(std_bin)/gate-lock.sh" ]]; then "$@"; return $?; fi
  local flags=(); [[ -n "${MAIPAI_HEAVY_MEM_GB:-}" ]] && flags=(--mem-gb "$MAIPAI_HEAVY_MEM_GB")
  bash "$(std_bin)/gate-lock.sh" heavy "$label" ${flags[@]+"${flags[@]}"} -- "$@"
}

# Installs a pre-push hook that runs origin-guard.sh, so a push from a checkout whose origin names
# another repo is refused even outside wt.sh. Shared by every worktree of the repo; a pre-push hook
# that is not ours is left alone.
install_origin_guard_hook() {
  local hooks="$WT_COMMON/hooks" hook guard
  hook="$hooks/pre-push"; guard="$(std_bin)/origin-guard.sh"
  mkdir -p "$hooks"
  if [[ -e "$hook" ]] && ! grep -q 'maipai-origin-guard' "$hook"; then
    echo "wt: $hook exists and is not the origin guard, so it was left as it is; add: bash $guard \"\$(git rev-parse --show-toplevel)\"" >&2
    return 0
  fi
  printf '#!/usr/bin/env bash\n# maipai-origin-guard (installed by wt.sh start)\nexec bash %q "$(git rev-parse --show-toplevel)"\n' "$guard" > "$hook"
  chmod +x "$hook"
}

# newest_within <seconds> <path>...: succeeds when any file under a path changed within the window.
# .git and node_modules are skipped for a worktree's own files; git state is checked separately.
recent_files() {
  local mins=$(( $1 / 60 )) out
  (( mins > 0 )) || return 0   # a window under a minute cannot prove quiet: count as recent
  out="$(find "$2" \( -name .git -o -name node_modules \) -prune -o -type f -mmin "-$mins" -print -quit 2>/dev/null)" || return 0  # unreadable: assume active
  [[ -n "$out" ]]
}
recent_path() {
  local mins=$(( $1 / 60 )) p out; shift
  (( mins > 0 )) || return 0
  for p in "$@"; do
    [[ -e "$p" ]] || continue
    out="$(find "$p" -maxdepth 0 -mmin "-$mins" -print 2>/dev/null)" || return 0
    [[ -n "$out" ]] && return 0
  done
  return 1
}
# live_reason <name> <path> <pid> <tmux>: prints why a worktree is NOT provably dead (empty = provably dead).
# Provably dead needs ALL of: pid gone, no tmux session (a missing tmux binary means "cannot prove", so keep), no
# heartbeat or file or git activity inside the quiet window (default 24 h, floor 60 s), no process with its cwd
# inside (an lsof failure means keep), a tree with no changes, untracked or ignored files (pure caches such as
# node_modules excepted) and a branch already on origin/main. Anything unknown or unreadable counts as alive.
live_reason() {
  local name="$1" path="$2" pid="$3" tmuxname="$4" quiet="${MAIPAI_WT_REAP_QUIET:-86400}" gitdir porcelain real lsout lsrc=0
  [[ "$quiet" =~ ^[0-9]+$ ]] || quiet=86400
  (( quiet >= 60 )) || quiet=60
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && { echo "recorded pid $pid is running"; return; }
  command -v tmux >/dev/null 2>&1 || { echo "tmux is not on PATH, so a live session cannot be ruled out"; return; }
  if [[ -n "$tmuxname" ]] && tmux_cmd has-session -t "$tmuxname" >/dev/null 2>&1; then echo "tmux session $tmuxname exists"; return; fi
  tmux_cmd has-session -t "$WT_REPO-$name" >/dev/null 2>&1 && { echo "tmux session $WT_REPO-$name exists"; return; }
  if [[ ! -e "$path/.git" ]]; then echo "worktree path is gone or not a worktree (record only)"; return; fi
  recent_path "$quiet" "$WT_SESSION_DIR/$name.beat" && { echo "heartbeat within the last ${quiet}s"; return; }
  recent_files "$quiet" "$path" && { echo "file modified within the last ${quiet}s, or the tree could not be read"; return; }
  gitdir="$(git -C "$path" rev-parse --absolute-git-dir 2>/dev/null)" || { echo "git state unreadable"; return; }
  recent_path "$quiet" "$gitdir/index" "$gitdir/HEAD" "$gitdir/logs/HEAD" && { echo "index, HEAD or reflog changed within the last ${quiet}s"; return; }
  command -v lsof >/dev/null 2>&1 || { echo "lsof missing, cannot rule out a running process"; return; }
  real="$(cd "$path" 2>/dev/null && pwd -P)" || { echo "worktree path unreadable"; return; }
  lsout="$(lsof -d cwd -Fn 2>/dev/null)" || lsrc=$?
  if (( lsrc != 0 )) && [[ -z "$lsout" ]]; then echo "lsof failed, cannot rule out a running process"; return; fi
  printf '%s\n' "$lsout" | WT_P="$real" awk 'substr($0,1,1)=="n" {d=substr($0,2); p=ENVIRON["WT_P"]; if (d==p || index(d, p "/")==1) f=1} END {exit !f}' && { echo "a process has its working directory inside"; return; }
  porcelain="$(git -C "$path" status --porcelain --ignored 2>/dev/null)" || { echo "git status failed"; return; }
  porcelain="$(printf '%s\n' "$porcelain" | grep -Ev '^!! (.*/)?(node_modules|__pycache__|\.pytest_cache|\.ruff_cache|\.turbo|\.vite)/$|^!! (.*/)?\.DS_Store$' || true)"
  [[ -z "$porcelain" ]] || { echo "uncommitted, untracked or ignored files ($(printf '%s\n' "$porcelain" | wc -l | tr -d ' ') paths; removal would delete them)"; return; }
  git -C "$WT_MAIN" merge-base --is-ancestor "$(read_json "$(session_file "$name")" branch)" origin/main 2>/dev/null || { echo "branch has commits not on origin/main"; return; }
}

# The reaper is report-only except for one case: a worktree that is provably dead (see live_reason) is removed
# with `git worktree remove` (no --force) and its merged branch deleted. It never adds, commits, stashes,
# resets or creates a ref in anyone's worktree. Candidates it keeps are listed in reaped.md with the evidence.
cmd_reap() {
  mkdir -p "$WT_SESSION_DIR" "$WT_PORT_DIR"
  local f name pid tmuxname path branch created age reason
  shopt -s nullglob
  for f in "$WT_SESSION_DIR"/*.json; do
    name="$(basename "$f" .json)"
    if ! session_usable "$f"; then
      # Cannot prove it dead, so its worktree is never touched; list the file for a person.
      mkdir -p "$WT_DATA"
      grep -qF "| $name | $f | kept: session file unreadable" "$WT_DATA/reaped.md" 2>/dev/null || \
        printf '%s | %s | %s | kept: session file unreadable (empty, truncated or not JSON)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$name" "$f" >> "$WT_DATA/reaped.md"
      continue
    fi
    pid="$(read_json "$f" pid)"; tmuxname="$(read_json "$f" tmux)"; path="$(read_json "$f" path)"; branch="$(read_json "$f" branch)"
    created="$(read_json "$f" created)"
    age=$(( $(date +%s) - $(date -u -j -f '%Y-%m-%dT%H:%M:%S' "${created%.*}" +%s 2>/dev/null || date -u -d "$created" +%s 2>/dev/null || echo 0) ))
    (( age >= ${MAIPAI_WT_REAP_AGE:-14400} )) || continue
    if [[ ! -e "$path/.git" ]]; then rm -f "$f" "$WT_SESSION_DIR/$name.beat"; continue; fi
    reason="$(live_reason "$name" "$path" "$pid" "$tmuxname")"
    if [[ -z "$reason" ]]; then
      git -C "$WT_MAIN" worktree remove "$path" >/dev/null 2>&1 && { git -C "$WT_MAIN" branch -d "$branch" >/dev/null 2>&1 || true; rm -f "$f" "$WT_SESSION_DIR/$name.beat"; }
    else
      mkdir -p "$WT_DATA"
      grep -qF "| $name | $path | kept: $reason" "$WT_DATA/reaped.md" 2>/dev/null || \
        printf '%s | %s | %s | kept: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$name" "$path" "$reason" >> "$WT_DATA/reaped.md"
    fi
  done
  for f in "$WT_PORT_DIR"/*.lease; do
    pid="$(awk 'NR==1 {print $1}' "$f" 2>/dev/null || true)"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null || rm -f "$f"
  done
  git -C "$WT_MAIN" worktree prune >/dev/null 2>&1 || true
  # Worktrees this script did not create (older lane worktrees) are listed, never removed:
  # clean ones whose branch is already on origin/main are safe for a person to remove.
  local wpath wbranch
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) wpath="${line#worktree }"; wbranch="";;
      "branch "*) wbranch="${line#branch refs/heads/}";;
      "")
        [[ -n "${wpath:-}" && "$wpath" != "$WT_MAIN" && "$wbranch" != wt/* && -n "$wbranch" ]] || { wpath=""; continue; }
        if [[ -z "$(git -C "$wpath" status --porcelain 2>/dev/null)" ]] && git -C "$WT_MAIN" merge-base --is-ancestor "$wbranch" origin/main 2>/dev/null; then
          echo "wt: removable worktree (clean, branch $wbranch already on origin/main): git -C $WT_MAIN worktree remove $wpath" >&2
        fi
        wpath="";;
    esac
  done < <(git -C "$WT_MAIN" worktree list --porcelain; echo)
}

# Refuse to push unless this session's gate stamp is green, at least as strong as the
# changed files need, fresh (default 4 hours, GATE-FAST-01 2026-10-16), and about exactly the committed content.
require_gate_stamp() {
  local name="$1" stamp files=() f required tag="MAIPAI_WT_SESSION=$1 bash scripts/wt.sh check"
  stamp="$WT_STAMP_DIR/$name.json"
  [[ -f "$stamp" ]] || err "no gate stamp for session '$name' at $stamp, so nothing proves these commits were checked. Run: $tag"
  while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done < <(git -C "$WT_ROOT" diff --name-only origin/main...HEAD | sort -u)
  required="$(blocking_tier ${files[@]+"${files[@]}"})"
  local verdict
  verdict="$(node - "$stamp" "$required" "${MAIPAI_WT_STAMP_MAX_AGE:-14400}" "$WT_ROOT" ${files[@]+"${files[@]}"} <<'NODE'
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
    stale:*) err "the gate stamp for session '$name' is ${verdict#stale:} seconds old and only 4 hours counts. Run: $tag";;
    content:*) err "the committed files changed since the gate stamp was written (${verdict#content:}). Run: $tag";;
    *) err "could not verify the gate stamp ($verdict). Run: $tag";;
  esac
}

cmd_land() {
  # A repo with a lander lands through it (Home, 2026-10-24): the lander runs the static check and the push.
  if [[ -x "$WT_ROOT/scripts/land.sh" ]]; then exec bash "$WT_ROOT/scripts/land.sh" "$@"; fi
  [[ $# == 0 ]] || err "land takes no arguments; run it from the active worktree." 2
  need_cmd git
  beat "${MAIPAI_WT_SESSION:-$(current_session_name)}"
  local dirty_files
  dirty_files="$(git -C "$WT_ROOT" status --porcelain --untracked-files=no)"
  [[ -z "$dirty_files" ]] || err "the worktree has uncommitted changes, so the rebase cannot run:
$dirty_files
Commit them by file name (git add -f for a tracked file under an ignored folder), or discard them, then rerun wt.sh land."
  git -C "$WT_ROOT" fetch origin || err "could not fetch origin; check network access and retry landing."
  local before after attempt changed_pin changed_pkg overlap name d
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
      # GATE-FAST-01 (2026-10-16): re-check only when the rebase could change the verdict,
      # that is, a pin moved or main touched a file this branch also changed. Otherwise the
      # stamp from the pre-rebase check still describes this branch's own changes.
      overlap="$(comm -12 <(git -C "$WT_ROOT" diff --name-only "$before" "$after" | sort -u) <(git -C "$WT_ROOT" diff --name-only origin/main...HEAD | sort -u) || true)"
      if [[ -n "$changed_pkg" || -n "$overlap" ]]; then
        cmd_check || err "checks failed after rebase; fix the failures before landing."
      else
        echo "rebase moved HEAD but touched none of this branch's files and no pin; keeping the gate stamp."
      fi
    fi
    name="${MAIPAI_WT_SESSION:-$(current_session_name)}"
    require_gate_stamp "$name"
    changed_pin="$(git -C "$WT_ROOT" diff origin/main...HEAD -- scripts/check.sh '*package.json' | grep -E '^[+-].*(core-v|ui-v|spec-v|std-v)' || true)"
    if git -C "$WT_ROOT" push origin HEAD:main; then
      [[ -z "$changed_pin" || -z "${WT_PIN_REMINDER:-}" ]] || echo "Reminder: $WT_PIN_REMINDER"
      # The push succeeded, so the land did too. done may still keep the worktree for untracked files
      # (land checks tracked files only); it runs in a subshell so its refusal cannot turn this into a failure.
      ( cmd_done ) || echo "wt: landed on origin/main; the worktree was kept for the files listed above. Run wt.sh done once they are handled." >&2
      return 0
    fi
    if (( attempt < 3 )); then git -C "$WT_ROOT" fetch origin || err "push was rejected and fetch failed; retry wt.sh land after network access returns."; before="$(git -C "$WT_ROOT" rev-parse HEAD)"; fi
  done
  err "push to origin/main was rejected three times; inspect origin/main and rerun wt.sh land."
}

# Tests source the functions without running a command.
[[ -n "${MAIPAI_WT_SOURCE_ONLY:-}" ]] && return 0

case "${1:-}" in
  start|land|check|done) "$(std_bin)/origin-guard.sh" "$WT_ROOT" || exit 1;; esac

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
