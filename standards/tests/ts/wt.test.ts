import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { spawn, spawnSync } from "node:child_process";

const scratch = mkdtempSync(join(tmpdir(), "maipai-wt-test-"));
const repoRoot = join(import.meta.dir, "../../..");
const script = join(repoRoot, "standards/bin/wt.sh");
// These tests exercise wt.sh itself; the heavy-run guard (load wait, memory cap) has its own tests in heavyRun.test.ts.
process.env.MAIPAI_HEAVY = "0";
const repoEnv = { WT_T2_GLOBS: "backend/src/auth/* spec/schemas/*", WT_TEST_HOOK: "scripts/wt-tests.sh" };
const fixture = join(scratch, "demo");
const bare = join(scratch, "origin.git");
const data = join(scratch, "session-data");
const socket = `wt-test-${process.pid}-${Date.now()}`;
const run = (args: string[], env: Record<string, string> = {}) => spawnSync("bash", [script, ...args], {
  cwd: fixture,
  encoding: "utf8",
  env: { ...process.env, ...repoEnv, MAIPAI_WT_DATA: data, MAIPAI_WT_TMUX_SOCKET: socket, MAIPAI_WT_SESSION: "", ...env },
});

beforeAll(() => {
  mkdirSync(fixture, { recursive: true });
  spawnSync("git", ["init", "--bare", bare], { stdio: "inherit" });
  spawnSync("git", ["init", "-b", "main", fixture], { stdio: "inherit" });
  spawnSync("git", ["-C", fixture, "config", "user.name", "Test User"]);
  spawnSync("git", ["-C", fixture, "config", "user.email", "test@example.invalid"]);
  writeFileSync(join(fixture, "README.md"), "fixture\n");
  mkdirSync(join(fixture, "scripts"), { recursive: true });
  writeFileSync(join(fixture, "scripts", "check.sh"), "#!/usr/bin/env bash\necho '== scope: fixture'\n");
  writeFileSync(join(fixture, "scripts", "wt-tests.sh"), "#!/usr/bin/env bash\nprintf '%s\\n' \"$@\" > \"$MAIPAI_WT_DATA/tests-ran.txt\"\n");
  mkdirSync(join(fixture, "backend"), { recursive: true });
  writeFileSync(join(fixture, "backend", "package.json"), JSON.stringify({ dependencies: { "@maipai/ui": "file:../../commons-tags/ui-ui-v9.9.9/ui" } }));
  spawnSync("git", ["-C", fixture, "add", "."]);
  spawnSync("git", ["-C", fixture, "commit", "-m", "initial"]);
  spawnSync("git", ["-C", fixture, "remote", "add", "origin", bare]);
  spawnSync("git", ["-C", fixture, "push", "-u", "origin", "main"]);
});

afterAll(() => {
  spawnSync("tmux", ["-L", socket, "kill-server"], { stdio: "ignore" });
  rmSync(scratch, { recursive: true, force: true });
});

describe("wt.sh worktree lifecycle", () => {
  const commons = join(scratch, "commons");
  const tags = join(scratch, "commons-tags");
  const bunBin = join(scratch, "bun-bin");
  const ensure = join(commons, "scripts", "ensure-tag.sh");
  const tagCalls = join(scratch, "ensure-tag-calls.txt");
  const withTagSetup = (body: string) => {
    mkdirSync(join(commons, "scripts"), { recursive: true });
    mkdirSync(bunBin, { recursive: true });
    rmSync(join(tags, "ui-ui-v9.9.9"), { recursive: true, force: true });
    writeFileSync(join(bunBin, "bun"), "#!/usr/bin/env bash\nexit 0\n", { mode: 0o755 });
    writeFileSync(ensure, body, { mode: 0o755 });
    rmSync(tagCalls, { force: true });
  };
  const tagEnv = { WT_INSTALL_DIRS: "backend", MAIPAI_COMMONS_DIR: commons, PATH: `${bunBin}:${process.env.PATH}`, MAIPAI_WT_DATA: data };

  test("start creates each missing pinned commons tag once before install", () => {
    withTagSetup(`#!/usr/bin/env bash\nprintf '%s %s\\n' "$1" "$2" >> '${tagCalls}'\nmkdir -p '${tags}/'"$1-$2"\n`);
    const first = run(["start", "tagfirst"], tagEnv);
    expect(first.status).toBe(0);
    expect(readFileSync(tagCalls, "utf8")).toBe("ui ui-v9.9.9\n");
    const firstName = first.stdout.trim().split("/").at(-1)!.replace(/^demo-/, "");
    expect(run(["done", "--abandon"], { MAIPAI_WT_SESSION: firstName }).status).toBe(0);

    const second = run(["start", "tagsecond"], tagEnv);
    expect(second.status).toBe(0);
    expect(readFileSync(tagCalls, "utf8")).toBe("ui ui-v9.9.9\n");
    const secondName = second.stdout.trim().split("/").at(-1)!.replace(/^demo-/, "");
    expect(run(["done", "--abandon"], { MAIPAI_WT_SESSION: secondName }).status).toBe(0);
  });

  test("start removes its worktree and branch when commons tag creation fails", () => {
    withTagSetup("#!/usr/bin/env bash\nexit 1\n");
    const failed = run(["start", "tagfail"], tagEnv);
    expect(failed.status).not.toBe(0);
    expect(failed.stderr).toContain("wt: could not create the commons tag worktree ui-ui-v9.9.9; fetch the commons repo");
    const worktrees = spawnSync("git", ["-C", fixture, "worktree", "list", "--porcelain"], { encoding: "utf8" }).stdout;
    expect(worktrees).not.toMatch(/worktree .*\/wt\/demo-/);
    expect(spawnSync("git", ["-C", fixture, "branch", "--list", "wt/*"], { encoding: "utf8" }).stdout.trim()).toBe("");
  });

  test("start and done remove the worktree, branch, and session file", () => {
    const started = run(["start", "x"]);
    expect(started.status).toBe(0);
    const path = started.stdout.trim();
    expect(path).toContain("/wt/demo-");
    expect(readFileSync(join(data, "sessions", `${path.split("/").at(-1)!.replace(/^demo-/, "")}.json`), "utf8")).toContain('"branch": "wt/');

    const finished = run(["done"]);
    expect(finished.status).toBe(0);
    expect(spawnSync("git", ["-C", fixture, "worktree", "list", "--porcelain"], { encoding: "utf8" }).stdout).not.toContain(`worktree ${path}`);
    const branches = spawnSync("git", ["-C", fixture, "branch", "--list", "wt/*"], { encoding: "utf8" }).stdout.trim();
    expect(branches).toBe("");
    expect(spawnSync("find", [join(data, "sessions"), "-name", "*.json"], { encoding: "utf8" }).stdout.trim()).toBe("");
  });

  test("port leases the first available port and records a session", () => {
    const result = run(["port"], { MAIPAI_WT_SESSION: "test-session" });
    expect(result.status).toBe(0);
    // The first free port in 8800-8899: another live session (a dev server, a Codex backend) may hold 8800.
    const port = result.stdout.trim();
    expect(port).toMatch(/^88\d\d$/);
    expect(readFileSync(join(data, "ports", `${port}.lease`), "utf8")).toContain("test-session");
  });

  test("check classifies docs, then stamps the selected tier and HEAD", () => {
    const started = run(["start", "check"]);
    expect(started.status).toBe(0);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    writeFileSync(join(path, "NOTE.md"), "note\n");
    // Invoke this checkout's script with the fixture worktree as its cwd.
    const checked = spawnSync("bash", [script, "check"], { cwd: path, encoding: "utf8", env: { ...process.env, ...repoEnv, MAIPAI_WT_DATA: data, MAIPAI_WT_SESSION: name } });
    expect(checked.status).toBe(0);
    const stamp = JSON.parse(readFileSync(join(data, "gate-stamps", `${name}.json`), "utf8"));
    expect(stamp.tier).toBe("T0");
    expect(stamp.head).toBe(spawnSync("git", ["-C", path, "rev-parse", "HEAD"], { encoding: "utf8" }).stdout.trim());
    expect(run(["done", "--abandon"], { MAIPAI_WT_SESSION: name }).status).toBe(0);
  });

  test("T1 check runs check.sh --pre and then the repo's test hook with the changed files", () => {
    const started = run(["start", "hook"]);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    mkdirSync(join(path, "lib"), { recursive: true });
    writeFileSync(join(path, "lib/thing.ts"), "code\n");
    const checked = spawnSync("bash", [script, "check"], { cwd: path, encoding: "utf8", env: { ...process.env, ...repoEnv, MAIPAI_WT_DATA: data, MAIPAI_WT_SESSION: name } });
    expect(checked.status).toBe(0);
    expect(readFileSync(join(data, "tests-ran.txt"), "utf8")).toContain("lib/thing.ts");
    expect(JSON.parse(readFileSync(join(data, "gate-stamps", `${name}.json`), "utf8")).tier).toBe("T1");
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("T1 selects tests that import the changed module, not tests that only say its name", () => {
    const started = run(["start", "sel"]);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    const put = (rel: string, body: string) => { mkdirSync(join(path, rel, ".."), { recursive: true }); writeFileSync(join(path, rel), body); };
    const spec = (imp: string) => `import { test } from "bun:test";\n${imp}\ntest("t", () => {});\n`;
    put("backend/src/lib/apps.test.ts", spec(""));
    put("backend/tests/relative.test.ts", spec('import { apps } from "../src/lib/apps";'));
    put("backend/tests/alias.test.ts", spec('import { apps } from "lib/apps.js";'));
    put("backend/tests/mocked.test.ts", spec('import { mock } from "bun:test";\nmock.module("../src/lib/apps.ts", () => ({}));'));
    put("backend/tests/words.test.ts", spec('const label = "apps";'));
    put("backend/tests/other.test.ts", spec('import { x } from "../src/lib/appsettings";'));
    spawnSync("git", ["-C", path, "add", "backend"]);
    spawnSync("git", ["-C", path, "commit", "-qm", "apps tests"]);
    // The tests are already on origin/main; only apps.ts changes in this branch.
    spawnSync("git", ["-C", path, "push", "-q", "origin", "HEAD:main"]);
    spawnSync("git", ["-C", path, "fetch", "-q", "origin"]);
    put("backend/src/lib/apps.ts", "export const apps = 1;\n");
    spawnSync("git", ["-C", path, "add", "backend"]);
    spawnSync("git", ["-C", path, "commit", "-qm", "apps module"]);
    const env = { ...process.env, ...repoEnv, WT_TEST_HOOK: "", WT_TEST_WORKSPACES: "backend", MAIPAI_WT_DATA: data, MAIPAI_WT_SESSION: name };
    const checked = spawnSync("bash", [script, "check"], { cwd: path, encoding: "utf8", env });
    const out = checked.stdout;
    expect(out).toContain("4 selected");
    for (const t of ["src/lib/apps.test.ts", "tests/relative.test.ts", "tests/alias.test.ts", "tests/mocked.test.ts"]) expect(out).toContain(t);
    expect(out).toContain("imports ../src/lib/apps");
    expect(out).not.toContain("words.test.ts");
    expect(out).not.toContain("other.test.ts");
    const capped = spawnSync("bash", [script, "check"], { cwd: path, encoding: "utf8", env: { ...env, MAIPAI_WT_T1_CAP: "2" } });
    expect(capped.stdout).toContain("2 more tests also match and are NOT run");
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("a file that is already staged still lands in the stamp manifest", () => {
    const started = run(["start", "staged"]);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    writeFileSync(join(path, "NOTE.md"), "note\n");
    spawnSync("git", ["-C", path, "add", "NOTE.md"]);
    const checked = spawnSync("bash", [script, "check"], { cwd: path, encoding: "utf8", env: { ...process.env, ...repoEnv, MAIPAI_WT_DATA: data, MAIPAI_WT_SESSION: name } });
    expect(checked.status).toBe(0);
    expect(Object.keys(JSON.parse(readFileSync(join(data, "gate-stamps", `${name}.json`), "utf8")).manifest)).toContain("NOTE.md");
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("without MAIPAI_WT_DATA the stamp lands inside the worktree, where the commit hook reads it", () => {
    const started = run(["start", "stampdir"]);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    writeFileSync(join(path, "NOTE.md"), "note\n");
    const env = { ...process.env, ...repoEnv, MAIPAI_WT_SESSION: "", MAIPAI_WT_DATA: "" } as Record<string, string>;
    delete env.MAIPAI_WT_DATA;
    const checked = spawnSync("bash", [script, "check"], { cwd: path, encoding: "utf8", env });
    expect(checked.status).toBe(0);
    expect(JSON.parse(readFileSync(join(path, "data-scratch/gate-stamps", `${name}.json`), "utf8")).tier).toBe("T0");
    // A second check must not list the first stamp as a changed file (data-scratch is not ignored here).
    expect(spawnSync("bash", [script, "check"], { cwd: path, encoding: "utf8", env }).status).toBe(0);
    const manifest = JSON.parse(readFileSync(join(path, "data-scratch/gate-stamps", `${name}.json`), "utf8")).manifest;
    expect(Object.keys(manifest)).toEqual(["NOTE.md"]);
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("tier classifies explicit paths and the branch diff", () => {
    expect(run(["tier", "README.md", "docs/guide.md"]).stdout.trim()).toBe("T0");
    expect(run(["tier", "backend/src/auth/session.ts"]).stdout.trim()).toBe("T2");
    expect(run(["tier", "backend/src/other.ts"]).stdout.trim()).toBe("T1");
    expect(run(["tier", "spec/schemas/record.json"]).stdout.trim()).toBe("T2");
    expect(run(["tier", "scripts/check.sh"]).stdout.trim()).toBe("T2");
    expect(run(["tier", "docs/api/openapi.json"]).stdout.trim()).toBe("T1");
    // GATE-FAST-01 (2026-10-16): pins, lockfiles and plans are T1; only RULES.md and the gate itself are always T2.
    expect(run(["tier", "ui/package.json"]).stdout.trim()).toBe("T1");
    expect(run(["tier", "docs/plans/anything.md"]).stdout.trim()).toBe("T0");
    expect(run(["tier", "docs/design/RULES.md"]).stdout.trim()).toBe("T2");
    expect(run(["tier", "scripts/wt.sh"]).stdout.trim()).toBe("T2");
    const started = run(["start", "tier"]);
    const path = started.stdout.trim();
    writeFileSync(join(path, "backend-change.ts"), "code\n");
    expect(spawnSync("bash", [script, "tier"], { cwd: path, encoding: "utf8", env: { ...process.env, ...repoEnv, MAIPAI_WT_DATA: data } }).stdout.trim()).toBe("T1");
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("tmux creates only a session on its private socket and done kills it", () => {
    const started = run(["start", "tmux"]);
    expect(started.status).toBe(0);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    const created = run(["tmux", "dev"], { MAIPAI_WT_SESSION: name });
    expect(created.status).toBe(0);
    const tmuxName = created.stdout.trim();
    expect(tmuxName).toBe(`demo-${name}-dev`);
    expect(spawnSync("tmux", ["-L", socket, "has-session", "-t", tmuxName]).status).toBe(0);
    expect(run(["done"], { MAIPAI_WT_SESSION: name }).status).toBe(0);
    expect(spawnSync("tmux", ["-L", socket, "has-session", "-t", tmuxName]).status).not.toBe(0);
  });

  describe("reaper is report-only unless a worktree is provably dead", () => {
    const realGit = spawnSync("bash", ["-c", "command -v git"], { encoding: "utf8" }).stdout.trim();
    const shimDir = join(scratch, "git-shim");
    const calls = join(scratch, "git-calls.txt");
    const startDead = (slug: string) => {
      const started = run(["start", slug]);
      expect(started.status).toBe(0);
      const path = started.stdout.trim();
      const name = path.split("/").at(-1)!.replace(/^demo-/, "");
      const file = join(data, "sessions", `${name}.json`);
      const rec = JSON.parse(readFileSync(file, "utf8"));
      rec.pid = 999999999;
      writeFileSync(file, JSON.stringify(rec));
      return { path, name, file };
    };
    // Make a worktree look 2 days idle: every file, its git state and its heartbeat.
    const age = (w: { path: string; name: string }) => {
      const gitdir = spawnSync(realGit, ["-C", w.path, "rev-parse", "--absolute-git-dir"], { encoding: "utf8" }).stdout.trim();
      for (const dir of [w.path, gitdir]) spawnSync("find", [dir, "-exec", "touch", "-t", "202001010000", "{}", "+"]);
      spawnSync("touch", ["-t", "202001010000", join(data, "sessions", `${w.name}.beat`)]);
    };
    const reap = (env: Record<string, string> = {}) => run(["reap"], { MAIPAI_WT_REAP_AGE: "0", ...env });
    const listed = () => spawnSync("git", ["-C", fixture, "worktree", "list", "--porcelain"], { encoding: "utf8" }).stdout;
    const cleanup = (w: { path: string; name: string; file: string }) => {
      spawnSync("git", ["-C", fixture, "worktree", "remove", "--force", w.path]);
      spawnSync("git", ["-C", fixture, "branch", "-D", `wt/${w.name}`]);
      rmSync(w.file, { force: true });
      rmSync(join(data, "sessions", `${w.name}.beat`), { force: true });
    };

    test("dead pid but recent activity: untouched, uncommitted work preserved, never add or commit", () => {
      const w = startDead("active");
      writeFileSync(join(w.path, "wip.txt"), "keep this\n");
      mkdirSync(shimDir, { recursive: true });
      writeFileSync(join(shimDir, "git"), `#!/usr/bin/env bash\nprintf '%s\\n' "$*" >> '${calls}'\nexec '${realGit}' "$@"\n`, { mode: 0o755 });
      rmSync(calls, { force: true });
      const out = reap({ PATH: `${shimDir}:${process.env.PATH}` });
      expect(out.status).toBe(0);
      expect(readFileSync(join(w.path, "wip.txt"), "utf8")).toBe("keep this\n");
      expect(listed()).toContain(`worktree ${w.path}`);
      expect(spawnSync(realGit, ["-C", w.path, "log", "--author=MaiPai Reaper", "--oneline"], { encoding: "utf8" }).stdout).toBe("");
      expect(spawnSync(realGit, ["-C", fixture, "show-ref", "--verify", `refs/heads/wip/${w.name}`]).status).not.toBe(0);
      const seen = existsSync(calls) ? readFileSync(calls, "utf8") : "";
      expect(seen.length).toBeGreaterThan(0);
      expect(seen).not.toMatch(/(^|\s)(add|commit|stash|reset|checkout|clean|branch -f|branch -D|update-ref)(\s|$)/m);
      expect(seen).not.toMatch(/worktree remove.*(--force|-f)(\s|$)/);
      cleanup(w);
    });

    test("a clean merged worktree with no activity is removed", () => {
      const w = startDead("cleanold");
      age(w);
      expect(reap().status).toBe(0);
      expect(listed()).not.toContain(`worktree ${w.path}`);
      expect(existsSync(w.file)).toBe(false);
    }, 15000); // reap runs git per worktree; 5s is too tight on a loaded machine

    test("a dirty old worktree is reported, not removed or committed", () => {
      const w = startDead("dirtyold");
      writeFileSync(join(w.path, "lost-work.txt"), "keep this\n");
      age(w);
      expect(reap().status).toBe(0);
      expect(readFileSync(join(w.path, "lost-work.txt"), "utf8")).toBe("keep this\n");
      expect(listed()).toContain(`worktree ${w.path}`);
      const report = readFileSync(join(data, "reaped.md"), "utf8");
      expect(report).toContain(w.name);
      expect(report).toContain("uncommitted, untracked or ignored files");
      expect(spawnSync(realGit, ["-C", w.path, "log", "--author=MaiPai Reaper", "--oneline"], { encoding: "utf8" }).stdout).toBe("");
      cleanup(w);
    });

    test("an ignored file keeps the worktree; a pure cache does not", () => {
      const w = startDead("ignored");
      writeFileSync(join(w.path, ".gitignore"), ".env\nnode_modules/\n");
      spawnSync(realGit, ["-C", w.path, "add", ".gitignore"]);
      spawnSync(realGit, ["-C", w.path, "-c", "user.name=T", "-c", "user.email=t@example.invalid", "commit", "-qm", "ignore"]);
      spawnSync(realGit, ["-C", fixture, "push", "-q", "origin", `wt/${w.name}:main`]);
      spawnSync(realGit, ["-C", fixture, "fetch", "-q", "origin"]);
      mkdirSync(join(w.path, "node_modules"), { recursive: true });
      writeFileSync(join(w.path, "node_modules", "x.js"), "cache\n");
      writeFileSync(join(w.path, ".env"), "SECRET=1\n");
      age(w);
      expect(reap().status).toBe(0);
      expect(listed()).toContain(`worktree ${w.path}`);
      expect(readFileSync(join(w.path, ".env"), "utf8")).toBe("SECRET=1\n");
      expect(readFileSync(join(data, "reaped.md"), "utf8")).toContain("ignored files");
      rmSync(join(w.path, ".env"));
      age(w);
      expect(reap().status).toBe(0);
      expect(listed()).not.toContain(`worktree ${w.path}`);
      spawnSync(realGit, ["-C", fixture, "reset", "-q", "--hard", "origin/main"]);
    });

    test("a quiet window under 60 s is clamped, so fresh work is kept", () => {
      const w = startDead("clamp");
      expect(reap({ MAIPAI_WT_REAP_QUIET: "0" }).status).toBe(0);
      expect(listed()).toContain(`worktree ${w.path}`);
      cleanup(w);
    });

    test("without tmux on PATH nothing is removed", () => {
      const w = startDead("notmux");
      age(w);
      const bareDir = join(scratch, "no-tmux-bin");
      mkdirSync(bareDir, { recursive: true });
      for (const tool of ["git", "bash", "env", "dirname", "basename", "cat", "mkdir", "od", "awk", "grep", "tail", "cut", "sleep", "ls", "head", "tr", "find", "date", "rm", "touch", "wc", "sed", "lsof", "node", "sort", "uniq", "kill"]) {
        // A version manager's node may be a shim that breaks when linked elsewhere; link the binary it runs.
        const lookup = tool === "node" ? "node -p process.execPath" : `command -v ${tool}`;
        const found = spawnSync("bash", ["-c", lookup], { encoding: "utf8" }).stdout.trim();
        if (found) spawnSync("ln", ["-sf", found, join(bareDir, tool)]);
      }
      const out = reap({ PATH: bareDir });
      expect(out.status).toBe(0);
      expect(listed()).toContain(`worktree ${w.path}`);
      expect(readFileSync(join(data, "reaped.md"), "utf8")).toContain("tmux is not on PATH");
      cleanup(w);
    });

    test("a fresh heartbeat or a live process keeps an otherwise clean old worktree", () => {
      const w = startDead("beating");
      expect(reap({ MAIPAI_WT_REAP_QUIET: "60" }).status).toBe(0);
      expect(listed()).toContain(`worktree ${w.path}`);
      const proc = spawn("sleep", ["30"], { cwd: w.path });
      try {
        age(w);
        expect(reap().status).toBe(0);
        expect(listed()).toContain(`worktree ${w.path}`);
        expect(readFileSync(join(data, "reaped.md"), "utf8")).toContain("working directory inside");
      } finally { proc.kill(); }
      cleanup(w);
    });
  });
});

describe("session files that are empty, truncated or garbage", () => {
  const bad: Record<string, Buffer | string> = {
    empty: "",
    truncated: '{"owner": "x", "pid": 12, "path"',
    binary: Buffer.from([0, 255, 254, 1, 2, 3, 128, 0, 0, 77]),
  };
  for (const [kind, content] of Object.entries(bad)) {
    test(`${kind} file: start and reap skip it, name it, and leave its session alone`, () => {
      mkdirSync(join(data, "sessions"), { recursive: true });
      const badFile = join(data, "sessions", `clever-badger-${kind}.json`);
      writeFileSync(badFile, content);
      const started = run(["start", `after${kind}`]);
      expect(started.status).toBe(0);
      expect(started.stderr).toContain(badFile);
      expect(started.stderr).toContain("unreadable");
      const path = started.stdout.trim();
      const name = path.split("/").at(-1)!.replace(/^demo-/, "");
      const reaped = run(["reap"], { MAIPAI_WT_REAP_AGE: "0" });
      expect(reaped.status).toBe(0);
      expect(existsSync(badFile)).toBe(true);
      expect(readFileSync(join(data, "reaped.md"), "utf8")).toContain(`clever-badger-${kind} | ${badFile} | kept: session file unreadable`);
      // The healthy session is still usable and finishes normally.
      expect(run(["done"], { MAIPAI_WT_SESSION: name }).status).toBe(0);
      rmSync(badFile, { force: true });
    });
  }

  test("a corrupt own session file gives a plain error for run and tmux, and done still cleans up", () => {
    const started = run(["start", "ownbad"]);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    const file = join(data, "sessions", `${name}.json`);
    writeFileSync(file, "");
    const brief = join(scratch, "brief-ownbad.md");
    writeFileSync(brief, "x\n");
    const ran = run(["run", "p", brief], { MAIPAI_WT_SESSION: name });
    expect(ran.status).not.toBe(0);
    expect(ran.stderr).toContain("unreadable");
    expect(run(["done"], { MAIPAI_WT_SESSION: name }).status).toBe(0);
    expect(existsSync(file)).toBe(false);
  });

  test("20 concurrent writers never leave an empty or invalid session file", () => {
    mkdirSync(join(data, "sessions"), { recursive: true });
    const probe = `
      source '${script}'
      f="$(session_file race)"
      write_session race wt/race /tmp/race ""
      ( for i in $(seq 1 60); do
          if [[ ! -s "$f" ]] || ! session_ok "$f"; then echo BAD; fi
        done ) > "${scratch}/race-reader.txt" &
      reader=$!
      for i in $(seq 1 20); do
        ( for j in 1 2; do write_session race wt/race /tmp/race ""; set_run_state race "state$i"; done ) &
      done
      wait
      session_ok "$f" && echo FINAL_OK
    `;
    const out = spawnSync("bash", ["-c", probe], {
      cwd: fixture, encoding: "utf8",
      env: { ...process.env, ...repoEnv, MAIPAI_WT_DATA: data, MAIPAI_WT_SOURCE_ONLY: "1" },
    });
    expect(out.stdout).toContain("FINAL_OK");
    expect(readFileSync(join(scratch, "race-reader.txt"), "utf8")).not.toContain("BAD");
    const leftovers = spawnSync("bash", ["-c", `ls '${join(data, "sessions")}' | grep 'race.json.tmp' || true`], { encoding: "utf8" }).stdout.trim();
    expect(leftovers).toBe("");
    rmSync(join(data, "sessions", "race.json"), { force: true });
  }, 120000);
});

describe("wt.sh land gate stamp", () => {
  const originMain = () => spawnSync("git", ["--git-dir", bare, "rev-parse", "main"], { encoding: "utf8" }).stdout.trim();
  // A worktree with one committed file; `file` decides the tier (docs T0, other code T1).
  const session = (slug: string, file: string) => {
    const started = run(["start", slug]);
    if (started.status !== 0 || !started.stdout.trim()) throw new Error(`wt.sh start failed: ${started.stderr}`);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    mkdirSync(join(path, file, ".."), { recursive: true });
    writeFileSync(join(path, file), `${slug}\n`);
    spawnSync("git", ["-C", path, "add", file]);
    spawnSync("git", ["-C", path, "commit", "-m", slug], { env: { ...process.env, GIT_AUTHOR_NAME: "T", GIT_AUTHOR_EMAIL: "t@example.invalid", GIT_COMMITTER_NAME: "T", GIT_COMMITTER_EMAIL: "t@example.invalid" } });
    const sh = (args: string[]) => spawnSync("bash", [script, ...args], { cwd: path, encoding: "utf8", env: { ...process.env, ...repoEnv, MAIPAI_WT_DATA: data, MAIPAI_WT_SESSION: name } });
    const stampPath = join(data, "gate-stamps", `${name}.json`);
    const edit = (fn: (s: any) => void) => { const s = JSON.parse(readFileSync(stampPath, "utf8")); fn(s); writeFileSync(stampPath, JSON.stringify(s)); };
    return { path, name, sh, stampPath, edit };
  };
  const refused = (r: { status: number | null; stderr: string }, text: string, next: string) => {
    expect(r.status).not.toBe(0);
    expect(r.stderr).toContain(text);
    expect(r.stderr).toContain(next);
  };

  test("hands land to the repo lander without pushing", () => {
    const before = originMain();
    writeFileSync(join(fixture, "scripts/land.sh"), "#!/usr/bin/env bash\nprintf 'land.sh called with: %s\\n' \"$*\"\nexit 0\n");
    spawnSync("chmod", ["+x", join(fixture, "scripts/land.sh")]);
    const landed = run(["land", "--detach"]);
    expect(landed.status).toBe(0);
    expect(landed.stdout).toContain("land.sh called with: --detach");
    expect(originMain()).toBe(before);
    rmSync(join(fixture, "scripts/land.sh"));
  });

  test("refuses with the exact next command when no stamp exists", () => {
    const before = originMain();
    const s = session("nostamp", "docs/nostamp.md");
    refused(s.sh(["land"]), "no gate stamp", `MAIPAI_WT_SESSION=${s.name} bash scripts/wt.sh check`);
    expect(originMain()).toBe(before);
    s.sh(["done", "--abandon"]);
  });

  test("refuses a failed, too-weak, stale, or drifted stamp, then lands after a fresh green check", () => {
    const before = originMain();
    const s = session("stamped", "tools/stamped.ts");
    expect(s.sh(["check"]).status).toBe(0);
    const good = readFileSync(s.stampPath, "utf8");
    const next = `MAIPAI_WT_SESSION=${s.name} bash scripts/wt.sh check`;

    s.edit((j) => { j.exitCode = 1; });
    refused(s.sh(["land"]), "check for session", next);

    writeFileSync(s.stampPath, good);
    s.edit((j) => { j.tier = "T0"; });
    refused(s.sh(["land"]), "need tier T1", `${next} T1`);

    writeFileSync(s.stampPath, good);
    s.edit((j) => { j.created = new Date(Date.now() - 241 * 60 * 1000).toISOString(); });
    refused(s.sh(["land"]), "only 4 hours counts", next);

    writeFileSync(s.stampPath, good);
    writeFileSync(join(s.path, "tools/stamped.ts"), "changed after the check\n");
    spawnSync("git", ["-C", s.path, "commit", "-am", "drift"], { env: { ...process.env, GIT_AUTHOR_NAME: "T", GIT_AUTHOR_EMAIL: "t@example.invalid", GIT_COMMITTER_NAME: "T", GIT_COMMITTER_EMAIL: "t@example.invalid" } });
    refused(s.sh(["land"]), "changed since the gate stamp", next);
    expect(originMain()).toBe(before);

    expect(s.sh(["check"]).status).toBe(0);
    const landed = s.sh(["land"]);
    expect(landed.status).toBe(0);
    expect(originMain()).not.toBe(before);
  }, 30000);

  test("a stronger stamp than needed lands", () => {
    const s = session("stronger", "docs/stronger.md");
    expect(s.sh(["check", "T1"]).status).toBe(0);
    expect(JSON.parse(readFileSync(s.stampPath, "utf8")).tier).toBe("T1");
    expect(s.sh(["land"]).status).toBe(0);
  }, 30000);
});


describe("wt.sh run and wait", () => {
  const fakeCodex = (body: string) => {
    const bin = join(scratch, `fake-codex-${Math.random().toString(36).slice(2)}`);
    writeFileSync(bin, `#!/usr/bin/env bash\n${body}\n`, { mode: 0o755 });
    return bin;
  };

  test("a finished run writes EXIT=0 and wait reports DONE", () => {
    const started = run(["start", "runok"]);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    const brief = join(scratch, "brief-ok.md");
    writeFileSync(brief, "do the thing\n");
    const launched = run(["run", "codex", brief], { MAIPAI_WT_SESSION: name, MAIPAI_WT_POLL: "1", MAIPAI_CODEX_BIN: fakeCodex("cat >/dev/null; echo built") });
    expect(launched.status).toBe(0);
    expect(launched.stdout).toContain(`demo-${name}-codex`);
    expect(launched.stdout).toContain("DONE");
    expect(launched.stdout).toContain("built");
    const record = JSON.parse(readFileSync(join(data, "sessions", `${name}.json`), "utf8"));
    expect(record.runState).toBe("DONE");
    expect(record.tmux).toBe(`demo-${name}-codex`);
    expect(typeof record.owner).toBe("string");
    const detached = run(["run", "--detach", "again", brief], { MAIPAI_WT_SESSION: name, MAIPAI_CODEX_BIN: fakeCodex("cat >/dev/null; echo two") });
    expect(detached.stdout).toContain("next: bash scripts/wt.sh wait");
    expect(run(["wait", `demo-${name}-again`, "30"], { MAIPAI_WT_POLL: "1" }).stdout).toContain("DONE");
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("run passes -s workspace-write by default, respects a binary override, and never grants full access", () => {
    const started = run(["start", "runsbx"]);
    const name = started.stdout.trim().split("/").at(-1)!.replace(/^demo-/, "");
    const brief = join(scratch, "brief-sbx.md");
    writeFileSync(brief, "argv\n");
    const argvFile = join(scratch, `argv-${name}.txt`);
    const recorder = fakeCodex(`cat >/dev/null; printf '%s\\n' "$@" > '${argvFile}'`);
    const defaulted = run(["run", "codex", brief], { MAIPAI_WT_SESSION: name, MAIPAI_WT_POLL: "1", MAIPAI_CODEX_BIN: recorder });
    expect(defaulted.stdout).toContain("DONE");
    const argv = readFileSync(argvFile, "utf8").split("\n");
    expect(argv[0]).toBe("exec");
    expect(argv.slice(argv.indexOf("-s"), argv.indexOf("-s") + 2)).toEqual(["-s", "workspace-write"]);
    expect(argv.join(" ")).not.toMatch(/danger|full-access|bypass|yolo|full-auto/);
    const script_ = readFileSync(script, "utf8");
    expect(script_).toContain('MAIPAI_TEST_NO_PORTS=1 \\"$bin\\" exec -s workspace-write');
    expect(script_).not.toMatch(/danger-full-access|dangerously|--yolo|bypass-approvals/);
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("a bin with arguments or shell characters is refused, and the sandbox flag cannot be removed", () => {
    const started = run(["start", "runbin"]);
    const name = started.stdout.trim().split("/").at(-1)!.replace(/^demo-/, "");
    const brief = join(scratch, "brief-bin.md");
    writeFileSync(brief, "x\n");
    for (const bad of ["codex --dangerously-bypass-approvals-and-sandbox", "codex;id", "codex'x", 'codex"x', "co$dex", "a&b", "a|b", "a<b", "a>b", "a`b`"]) {
      const out = run(["run", "--detach", "bad", brief], { MAIPAI_WT_SESSION: name, MAIPAI_CODEX_BIN: bad });
      expect(out.status).not.toBe(0);
      expect(out.stderr).toContain("wrapper script");
    }
    const argvFile = join(scratch, `argv-bin-${name}.txt`);
    const rec = fakeCodex(`cat >/dev/null; printf '%s\\n' "$@" > '${argvFile}'`);
    expect(run(["run", "ok", brief], { MAIPAI_WT_SESSION: name, MAIPAI_WT_POLL: "1", MAIPAI_CODEX_BIN: rec }).stdout).toContain("DONE");
    expect(readFileSync(argvFile, "utf8")).toContain("workspace-write");
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  }, 60000);

  test("a brief filename with a quote or shell character is refused", () => {
    const started = run(["start", "runbrief"]);
    const name = started.stdout.trim().split("/").at(-1)!.replace(/^demo-/, "");
    for (const file of ["it's.md", "a;b.md", "a$b.md"]) {
      const brief = join(scratch, file);
      writeFileSync(brief, "x\n");
      const out = run(["run", "--detach", "q", brief], { MAIPAI_WT_SESSION: name, MAIPAI_CODEX_BIN: fakeCodex("cat >/dev/null") });
      expect(out.status).not.toBe(0);
      expect(out.stderr).toContain("brief path");
    }
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("wait prints git status and the diffstat of the worktree after DONE", () => {
    const started = run(["start", "rundiff"]);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    const brief = join(scratch, "brief-diff.md");
    writeFileSync(brief, "x\n");
    const out = run(["run", "codex", brief], { MAIPAI_WT_SESSION: name, MAIPAI_WT_POLL: "1", MAIPAI_CODEX_BIN: fakeCodex(`cat >/dev/null; echo edited >> README.md; echo new > fresh.txt`) });
    expect(out.stdout).toContain("DONE");
    expect(out.stdout).toContain("worktree changes");
    expect(out.stdout).toContain(" M README.md");
    expect(out.stdout).toContain("?? fresh.txt");
    expect(out.stdout).toMatch(/README\.md \| 1 \+/);
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("a missing tmux or node names /opt/homebrew/bin when it is there", () => {
    const started = run(["start", "runpath"]);
    const name = started.stdout.trim().split("/").at(-1)!.replace(/^demo-/, "");
    const brief = join(scratch, "brief-path.md");
    writeFileSync(brief, "x\n");
    const bare_ = join(scratch, "pathless");
    mkdirSync(bare_, { recursive: true });
    for (const tool of ["git", "bash", "env", "dirname", "basename", "cat", "mkdir", "od", "awk", "grep", "tail", "cut", "sleep", "ls", "head", "tr"]) {
      const found = spawnSync("bash", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim();
      if (found) spawnSync("ln", ["-sf", found, join(bare_, tool)]);
    }
    const out = run(["run", "codex", brief], { MAIPAI_WT_SESSION: name, PATH: bare_ });
    expect(out.status).not.toBe(0);
    expect(out.stderr).toMatch(/tmux is (not on PATH but exists at \/opt\/homebrew\/bin\/tmux|required)/);
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  });

  test("a failing run reports FAILED and a killed session reports DIED", () => {
    const started = run(["start", "runbad"]);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    const brief = join(scratch, "brief-bad.md");
    writeFileSync(brief, "fail\n");
    run(["run", "--detach", "codex", brief], { MAIPAI_WT_SESSION: name, MAIPAI_CODEX_BIN: fakeCodex("cat >/dev/null; exit 3") });
    const failed = run(["wait", `demo-${name}-codex`, "30"], { MAIPAI_WT_POLL: "1" });
    expect(failed.status).not.toBe(0);
    expect(failed.stdout).toContain("FAILED (exit 3)");
    run(["run", "--detach", "slow", brief], { MAIPAI_WT_SESSION: name, MAIPAI_CODEX_BIN: fakeCodex("cat >/dev/null; sleep 60") });
    spawnSync("tmux", ["-L", socket, "kill-session", "-t", `demo-${name}-slow`]);
    const died = run(["wait", `demo-${name}-slow`, "30"], { MAIPAI_WT_POLL: "1" });
    expect(died.stdout).toContain("DIED");
    const timedOut = (() => {
      run(["run", "--detach", "hang", brief], { MAIPAI_WT_SESSION: name, MAIPAI_CODEX_BIN: fakeCodex("cat >/dev/null; sleep 60") });
      return run(["wait", `demo-${name}-hang`, "2"], { MAIPAI_WT_POLL: "1" });
    })();
    expect(timedOut.stdout).toContain("TIMEOUT");
    run(["done", "--abandon"], { MAIPAI_WT_SESSION: name });
  }, 60000);
});

describe("wt.sh done never discards unlanded work", () => {
  const gitEnv = { ...process.env, GIT_AUTHOR_NAME: "T", GIT_AUTHOR_EMAIL: "t@example.invalid", GIT_COMMITTER_NAME: "T", GIT_COMMITTER_EMAIL: "t@example.invalid" };
  const session = (slug: string) => {
    const started = run(["start", slug]);
    if (started.status !== 0 || !started.stdout.trim()) throw new Error(`wt.sh start failed: ${started.stderr}`);
    const path = started.stdout.trim();
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    const branch = `wt/${name}`;
    const sh = (args: string[]) => spawnSync("bash", [script, ...args], { cwd: path, encoding: "utf8", env: { ...process.env, ...repoEnv, MAIPAI_WT_DATA: data, MAIPAI_WT_SESSION: name } });
    const commit = (file: string) => {
      writeFileSync(join(path, file), `${slug}\n`);
      spawnSync("git", ["-C", path, "add", file]);
      spawnSync("git", ["-C", path, "commit", "-m", `${slug} ${file}`], { env: gitEnv });
      return spawnSync("git", ["-C", path, "rev-parse", "--short", "HEAD"], { encoding: "utf8" }).stdout.trim();
    };
    const hasWorktree = () => spawnSync("git", ["-C", fixture, "worktree", "list", "--porcelain"], { encoding: "utf8" }).stdout.includes(`worktree ${path}\n`);
    const hasBranch = () => spawnSync("git", ["-C", fixture, "show-ref", "--verify", "--quiet", `refs/heads/${branch}`]).status === 0;
    return { path, name, sh, commit, hasWorktree, hasBranch };
  };

  test("an unlanded commit: done refuses, names the commit and both ways forward, and keeps branch and worktree", () => {
    const s = session("unlanded");
    const sha = s.commit("unlanded.txt");
    const r = s.sh(["done"]);
    expect(r.status).not.toBe(0);
    expect(r.stderr).toContain(sha);
    expect(r.stderr).toContain("unlanded unlanded.txt");
    expect(r.stderr).toContain("wt.sh land");
    expect(r.stderr).toContain("--abandon");
    expect(s.hasWorktree()).toBe(true);
    expect(s.hasBranch()).toBe(true);
    expect(existsSync(join(data, "sessions", `${s.name}.json`))).toBe(true);
    expect(s.sh(["done", "--abandon"]).status).toBe(0);
  });

  test("uncommitted or untracked changes: done refuses and keeps them", () => {
    const s = session("dirty");
    writeFileSync(join(s.path, "untracked.txt"), "keep me\n");
    const r = s.sh(["done"]);
    expect(r.status).not.toBe(0);
    expect(r.stderr).toContain("untracked.txt");
    expect(r.stderr).toContain("--abandon");
    expect(s.hasWorktree()).toBe(true);
    expect(readFileSync(join(s.path, "untracked.txt"), "utf8")).toBe("keep me\n");
    expect(s.sh(["done", "--abandon"]).status).toBe(0);
  });

  test("a landed branch: done removes the worktree and branch", () => {
    const s = session("landed");
    s.commit("landed.txt");
    expect(spawnSync("git", ["-C", s.path, "push", "origin", "HEAD:main"]).status).toBe(0);
    const r = s.sh(["done"]);
    expect(r.status).toBe(0);
    expect(s.hasWorktree()).toBe(false);
    expect(s.hasBranch()).toBe(false);
  });

  test("a rebased equivalent commit on main: done removes the worktree without --abandon", () => {
    const s = session("rebased");
    const original = s.commit("rebased.txt");
    expect(spawnSync("git", ["-C", s.path, "push", "origin", "HEAD:refs/heads/rebased-source"]).status).toBe(0);
    const clone = join(scratch, "rebased-main");
    expect(spawnSync("git", ["clone", bare, clone], { encoding: "utf8" }).status).toBe(0);
    spawnSync("git", ["-C", clone, "config", "user.name", "Test User"]);
    spawnSync("git", ["-C", clone, "config", "user.email", "test@example.invalid"]);
    expect(spawnSync("git", ["-C", clone, "cherry-pick", original], { encoding: "utf8" }).status).toBe(0);
    const rebased = spawnSync("git", ["-C", clone, "rev-parse", "--short", "HEAD"], { encoding: "utf8" }).stdout.trim();
    expect(rebased).not.toBe(original);
    expect(spawnSync("git", ["-C", clone, "push", "origin", "HEAD:main"], { encoding: "utf8" }).status).toBe(0);

    const r = s.sh(["done"]);
    expect(r.status).toBe(0);
    expect(s.hasWorktree()).toBe(false);
    expect(s.hasBranch()).toBe(false);
  }, 30000);

  // The recorded session path can differ from the path git reports only in symlink or trailing-slash form.
  const recordAltPath = (s: { path: string; name: string }, form: "slash" | "symlink") => {
    const file = join(data, "sessions", `${s.name}.json`);
    const rec = JSON.parse(readFileSync(file, "utf8"));
    if (form === "slash") rec.path = `${s.path}/`;
    else {
      const link = join(scratch, `link-${s.name}`);
      symlinkSync(dirname(s.path), link);
      rec.path = join(link, basename(s.path));
    }
    writeFileSync(file, JSON.stringify(rec));
  };

  for (const form of ["slash", "symlink"] as const) {
    test(`a rebased commit with the recorded path in ${form} form: done removes the worktree, then the branch`, () => {
      const s = session(`rebased${form}`);
      const original = s.commit(`rebased${form}.txt`);
      expect(spawnSync("git", ["-C", s.path, "push", "origin", `HEAD:refs/heads/src-${form}`]).status).toBe(0);
      const clone = join(scratch, `rebased-main-${form}`);
      expect(spawnSync("git", ["clone", bare, clone], { encoding: "utf8" }).status).toBe(0);
      spawnSync("git", ["-C", clone, "config", "user.name", "Test User"]);
      spawnSync("git", ["-C", clone, "config", "user.email", "test@example.invalid"]);
      expect(spawnSync("git", ["-C", clone, "cherry-pick", original], { encoding: "utf8" }).status).toBe(0);
      expect(spawnSync("git", ["-C", clone, "push", "origin", "HEAD:main"], { encoding: "utf8" }).status).toBe(0);
      recordAltPath(s, form);
      const r = s.sh(["done"]);
      expect(r.stderr).not.toContain("cannot delete branch");
      expect(r.status).toBe(0);
      expect(s.hasWorktree()).toBe(false);
      expect(s.hasBranch()).toBe(false);
    }, 30000);

    test(`an unlanded commit with the recorded path in ${form} form is still refused`, () => {
      const s = session(`unlanded${form}`);
      const sha = s.commit(`unlanded${form}.txt`);
      recordAltPath(s, form);
      const r = s.sh(["done"]);
      expect(r.status).not.toBe(0);
      expect(r.stderr).toContain("done refused");
      expect(r.stderr).toContain(sha);
      expect(s.hasWorktree()).toBe(true);
      expect(s.hasBranch()).toBe(true);
      expect(s.sh(["done", "--abandon"]).status).toBe(0);
    });
  }

  test("land with an untracked file: lands, keeps the worktree, and says so", () => {
    const s = session("landuntracked");
    s.commit("landuntracked.txt");
    expect(s.sh(["check"]).status).toBe(0);
    writeFileSync(join(s.path, "notes.txt"), "keep me\n");
    const r = s.sh(["land"]);
    expect(r.status).toBe(0);
    expect(r.stderr).toContain("every commit is on origin/main");
    expect(r.stderr).toContain("notes.txt");
    expect(r.stderr).toContain("landed on origin/main; the worktree was kept");
    expect(s.hasWorktree()).toBe(true);
    expect(s.sh(["done", "--abandon"]).status).toBe(0);
  }, 30000);

  test("wt.sh's own gate stamp is not work: done removes the worktree where data-scratch is not ignored", () => {
    const s = session("ownstamp");
    mkdirSync(join(s.path, "data-scratch", "gate-stamps"), { recursive: true });
    writeFileSync(join(s.path, "data-scratch", "gate-stamps", `${s.name}.json`), "{}\n");
    expect(s.sh(["done"]).status).toBe(0);
    expect(s.hasWorktree()).toBe(false);
  });

  test("other files under data-scratch are still work: done refuses", () => {
    const s = session("scratchnote");
    mkdirSync(join(s.path, "data-scratch", "gate-stamps"), { recursive: true });
    writeFileSync(join(s.path, "data-scratch", "gate-stamps", `${s.name}.json`), "{}\n");
    writeFileSync(join(s.path, "data-scratch", "notes.md"), "keep me\n");
    const r = s.sh(["done"]);
    expect(r.status).not.toBe(0);
    expect(r.stderr).toContain("data-scratch/notes.md");
    expect(r.stderr).not.toContain("gate-stamps");
    expect(s.hasWorktree()).toBe(true);
    expect(s.sh(["done", "--abandon"]).status).toBe(0);
  });

  test("--abandon: done removes an unlanded, dirty worktree and its branch", () => {
    const s = session("abandon");
    s.commit("abandon.txt");
    writeFileSync(join(s.path, "scratch.txt"), "x\n");
    const r = s.sh(["done", "--abandon"]);
    expect(r.status).toBe(0);
    expect(s.hasWorktree()).toBe(false);
    expect(s.hasBranch()).toBe(false);
    expect(existsSync(join(data, "sessions", `${s.name}.json`))).toBe(false);
  });

  test("a corrupt own record still refuses unlanded work, and --abandon still cleans up", () => {
    const s = session("corruptunlanded");
    s.commit("c.txt");
    const file = join(data, "sessions", `${s.name}.json`);
    writeFileSync(file, "");
    expect(s.sh(["done"]).status).not.toBe(0);
    expect(s.hasBranch()).toBe(true);
    expect(s.sh(["done", "--abandon"]).status).toBe(0);
    expect(s.hasWorktree()).toBe(false);
    expect(existsSync(file)).toBe(false);
  });

  test("an unknown argument is refused", () => {
    const s = session("badarg");
    const r = s.sh(["done", "--force"]);
    expect(r.status).toBe(2);
    expect(s.hasWorktree()).toBe(true);
    s.sh(["done", "--abandon"]);
  });
});
