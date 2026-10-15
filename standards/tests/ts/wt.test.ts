import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const scratch = mkdtempSync(join(tmpdir(), "maipai-wt-test-"));
const repoRoot = join(import.meta.dir, "../../..");
const script = join(repoRoot, "standards/bin/wt.sh");
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
    expect(result.stdout.trim()).toBe("8800");
    expect(readFileSync(join(data, "ports", "8800.lease"), "utf8")).toContain("test-session");
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
    expect(run(["done"], { MAIPAI_WT_SESSION: name }).status).toBe(0);
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
    run(["done"], { MAIPAI_WT_SESSION: name });
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
    run(["done"], { MAIPAI_WT_SESSION: name });
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
    run(["done"], { MAIPAI_WT_SESSION: name });
  });

  test("tier classifies explicit paths and the branch diff", () => {
    expect(run(["tier", "README.md", "docs/guide.md"]).stdout.trim()).toBe("T0");
    expect(run(["tier", "backend/src/auth/session.ts"]).stdout.trim()).toBe("T2");
    expect(run(["tier", "backend/src/other.ts"]).stdout.trim()).toBe("T1");
    expect(run(["tier", "spec/schemas/record.json"]).stdout.trim()).toBe("T2");
    expect(run(["tier", "scripts/check.sh"]).stdout.trim()).toBe("T2");
    expect(run(["tier", "docs/api/openapi.json"]).stdout.trim()).toBe("T1");
    expect(run(["tier", "ui/package.json"]).stdout.trim()).toBe("T2");
    const started = run(["start", "tier"]);
    const path = started.stdout.trim();
    writeFileSync(join(path, "backend-change.ts"), "code\n");
    expect(spawnSync("bash", [script, "tier"], { cwd: path, encoding: "utf8", env: { ...process.env, ...repoEnv, MAIPAI_WT_DATA: data } }).stdout.trim()).toBe("T1");
    const name = path.split("/").at(-1)!.replace(/^demo-/, "");
    run(["done"], { MAIPAI_WT_SESSION: name });
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

  test("reap archives dirty dead work on wip and removes clean merged work", () => {
    const dirtyStart = run(["start", "recover"]);
    expect(dirtyStart.status).toBe(0);
    const dirtyPath = dirtyStart.stdout.trim();
    const dirtyName = dirtyPath.split("/").at(-1)!.replace(/^demo-/, "");
    writeFileSync(join(dirtyPath, "lost-work.txt"), "keep this\n");
    const dirtyFile = join(data, "sessions", `${dirtyName}.json`);
    const dirtyRecord = JSON.parse(readFileSync(dirtyFile, "utf8"));
    dirtyRecord.pid = 999999999;
    writeFileSync(dirtyFile, JSON.stringify(dirtyRecord));

    const cleanStart = run(["start", "clean"]);
    expect(cleanStart.status).toBe(0);
    const cleanPath = cleanStart.stdout.trim();
    const cleanName = cleanPath.split("/").at(-1)!.replace(/^demo-/, "");
    const cleanFile = join(data, "sessions", `${cleanName}.json`);
    const cleanRecord = JSON.parse(readFileSync(cleanFile, "utf8"));
    cleanRecord.pid = 999999999;
    writeFileSync(cleanFile, JSON.stringify(cleanRecord));

    expect(run(["reap"], { MAIPAI_WT_REAP_AGE: "0" }).status).toBe(0);
    expect(spawnSync("git", ["-C", fixture, "show-ref", "--verify", `refs/heads/wip/${dirtyName}`]).status).toBe(0);
    expect(readFileSync(join(dirtyPath, "lost-work.txt"), "utf8")).toBe("keep this\n");
    expect(readFileSync(join(data, "reaped.md"), "utf8")).toContain(dirtyName);
    expect(spawnSync("git", ["-C", fixture, "worktree", "list", "--porcelain"], { encoding: "utf8" }).stdout).toContain(`worktree ${dirtyPath}`);
    expect(spawnSync("git", ["-C", fixture, "worktree", "list", "--porcelain"], { encoding: "utf8" }).stdout).not.toContain(`worktree ${cleanPath}`);
    spawnSync("git", ["-C", fixture, "worktree", "remove", "--force", dirtyPath]);
    spawnSync("git", ["-C", fixture, "branch", "-D", `wt/${dirtyName}`, `wip/${dirtyName}`]);
    rmSync(dirtyFile, { force: true });
    rmSync(join(data, "sessions", `${cleanName}.json`), { force: true });
  });
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

  test("refuses with the exact next command when no stamp exists", () => {
    const before = originMain();
    const s = session("nostamp", "docs/nostamp.md");
    refused(s.sh(["land"]), "no gate stamp", `MAIPAI_WT_SESSION=${s.name} bash scripts/wt.sh check`);
    expect(originMain()).toBe(before);
    s.sh(["done"]);
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
    s.edit((j) => { j.created = new Date(Date.now() - 31 * 60 * 1000).toISOString(); });
    refused(s.sh(["land"]), "only 30 minutes counts", next);

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
    run(["done"], { MAIPAI_WT_SESSION: name });
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
    run(["done"], { MAIPAI_WT_SESSION: name });
  });
});
