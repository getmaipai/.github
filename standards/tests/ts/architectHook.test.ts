// ARCH-GATE-01: require-architect-verdict.sh (plugin/hooks/scripts/).
// Spawns the hook for real with a PreToolUse payload against a scratch git
// repo under a temp dir (never the real checkout, never global git config).
import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

const HOOK = join(import.meta.dir, "..", "..", "..", "plugin", "hooks", "scripts", "require-architect-verdict.sh");

function git(cwd: string, ...args: string[]): string {
  const proc = Bun.spawnSync(["git", ...args], { cwd, stdout: "pipe", stderr: "pipe" });
  if (proc.exitCode !== 0) throw new Error(`git ${args.join(" ")} failed: ${proc.stderr.toString()}`);
  return proc.stdout.toString();
}

function put(dir: string, rel: string, body: string) {
  const p = join(dir, rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, body);
}

function makeRepo(withRules = true): string {
  const dir = mkdtempSync(join(tmpdir(), "architect-hook-test-"));
  git(dir, "init", "-q", "-b", "main");
  git(dir, "config", "user.name", "Architect Hook Test");
  git(dir, "config", "user.email", "architect-hook-test@example.com");
  put(dir, "src/app.ts", "v1\n");
  put(dir, "backend/chat/turn.ts", "v1\n");
  put(dir, "docs/BACKLOG.md", "- [ ] one\n");
  if (withRules) {
    put(dir, "docs/design/RULES.md", "# Rules\n\n## Chat turn\n\nRecord: [x](../plans/x.md)\nGoverns: backend/chat/**, docs/chat/*.md\n\n1. A rule.\n");
    put(dir, "docs/plans/x.md", "# X\n\n## Supersedes\n\nNothing.\n");
  }
  git(dir, "add", "-A");
  git(dir, "commit", "-q", "-m", "initial");
  return dir;
}

function run(dir: string, command: string) {
  const proc = Bun.spawnSync(["bash", HOOK], { cwd: dir, stdin: Buffer.from(JSON.stringify({ tool_input: { command }, cwd: dir })), stdout: "pipe", stderr: "pipe" });
  return { exitCode: proc.exitCode, stderr: proc.stderr.toString() };
}

function verdict(dir: string, item: string, v: string, opts: { ageHours?: number; sha?: string } = {}) {
  const ts = new Date(Date.now() - (opts.ageHours ?? 0) * 3600_000).toISOString().replace(/\.\d+Z$/, "Z");
  put(dir, `data-scratch/architect/${item}.verdict`, `item: ${item}\nverdict: ${v}\nrules: 1\nsha256: ${opts.sha ?? "none"}\ntimestamp: ${ts}\nmodel: sonnet\n`);
}

function withRepo(fn: (dir: string) => void, withRules = true) {
  const dir = makeRepo(withRules);
  try {
    fn(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

describe("ARCH-GATE-01: require-architect-verdict.sh", () => {
  test("allows a commit that touches no governed path", () =>
    withRepo((dir) => {
      put(dir, "src/app.ts", "v2\n");
      git(dir, "add", "src/app.ts");
      expect(run(dir, 'git commit -m "tweak"').exitCode).toBe(0);
    }));

  test("denies a design-surface commit with no verdict, naming the architect", () =>
    withRepo((dir) => {
      put(dir, "docs/BACKLOG.md", "- [ ] two\n");
      git(dir, "add", "docs/BACKLOG.md");
      const r = run(dir, 'git commit -m "ITEM-1: add"');
      expect(r.exitCode).toBe(2);
      expect(r.stderr).toContain("architect");
      expect(r.stderr).toContain("item id");
    }));

  test("denies a commit that touches a Governs glob path with no verdict", () =>
    withRepo((dir) => {
      put(dir, "backend/chat/turn.ts", "v2\n");
      git(dir, "add", "backend/chat/turn.ts");
      expect(run(dir, 'git commit -m "ITEM-2: change"').exitCode).toBe(2);
    }));

  test("allows a governed commit on a fresh APPROVED verdict named in the message", () =>
    withRepo((dir) => {
      put(dir, "backend/chat/turn.ts", "v2\n");
      git(dir, "add", "backend/chat/turn.ts");
      verdict(dir, "ITEM-3", "APPROVED");
      expect(run(dir, 'git commit -m "ITEM-3: change"').exitCode).toBe(0);
    }));

  test("allows a governed commit whose staged diff hash matches an APPROVED verdict", () =>
    withRepo((dir) => {
      put(dir, "docs/BACKLOG.md", "- [ ] three\n");
      git(dir, "add", "docs/BACKLOG.md");
      const sha = Bun.spawnSync(["bash", "-c", "git diff --cached | shasum -a 256 | cut -d' ' -f1"], { cwd: dir }).stdout.toString().trim();
      verdict(dir, "ITEM-4", "APPROVED", { sha });
      expect(run(dir, 'git commit -m "no id here"').exitCode).toBe(0);
    }));

  test("denies a stale APPROVED verdict", () =>
    withRepo((dir) => {
      put(dir, "backend/chat/turn.ts", "v2\n");
      git(dir, "add", "backend/chat/turn.ts");
      verdict(dir, "ITEM-5", "APPROVED", { ageHours: 30 });
      const r = run(dir, 'git commit -m "ITEM-5: change"');
      expect(r.exitCode).toBe(2);
      expect(r.stderr).toContain("stale");
    }));

  test("denies a REJECTED verdict", () =>
    withRepo((dir) => {
      put(dir, "backend/chat/turn.ts", "v2\n");
      git(dir, "add", "backend/chat/turn.ts");
      verdict(dir, "ITEM-6", "REJECTED");
      const r = run(dir, 'git commit -m "ITEM-6: change"');
      expect(r.exitCode).toBe(2);
      expect(r.stderr).toContain("REJECTED");
    }));

  test("denies a RULES.md edit without the owner line, allows it with one", () =>
    withRepo((dir) => {
      put(dir, "docs/design/RULES.md", "# Rules\n\n## Chat turn\n\nRecord: [x](../plans/x.md)\n\n1. Changed.\n");
      git(dir, "add", "docs/design/RULES.md");
      verdict(dir, "ITEM-7", "APPROVED");
      const denied = run(dir, 'git commit -m "ITEM-7: reword rule"');
      expect(denied.exitCode).toBe(2);
      expect(denied.stderr).toContain("Owner-approved:");
      expect(run(dir, 'git commit -m "reword rule" -m "Owner-approved: 2026-10-02"').exitCode).toBe(0);
    }));

  test("no-ops in a repo without docs/design/RULES.md", () =>
    withRepo((dir) => {
      put(dir, "docs/BACKLOG.md", "- [ ] two\n");
      git(dir, "add", "docs/BACKLOG.md");
      expect(run(dir, 'git commit -m "anything"').exitCode).toBe(0);
    }, false));

  test("ignores commands that are not commits, and a message that only mentions one", () =>
    withRepo((dir) => {
      put(dir, "docs/BACKLOG.md", "- [ ] two\n");
      git(dir, "add", "docs/BACKLOG.md");
      expect(run(dir, "git status").exitCode).toBe(0);
      expect(run(dir, 'echo "git commit later"').exitCode).toBe(0);
    }));

  test("a body line that mentions --amend does not bypass the gate", () =>
    withRepo((dir) => {
      put(dir, "docs/BACKLOG.md", "- [ ] two\n");
      git(dir, "add", "docs/BACKLOG.md");
      expect(run(dir, 'git commit -m "tweak\n--amend body"').exitCode).toBe(2);
      expect(run(dir, "git commit -F - <<'EOF'\ntweak\n--amend body\nEOF").exitCode).toBe(2);
    }));

  test("git -C <dir> and cd <dir> && target the repo they name", () =>
    withRepo((dir) => {
      put(dir, "docs/BACKLOG.md", "- [ ] two\n");
      git(dir, "add", "docs/BACKLOG.md");
      const other = mkdtempSync(join(tmpdir(), "architect-hook-other-"));
      try {
        git(other, "init", "-q", "-b", "main");
        const run2 = (command: string) => {
          const proc = Bun.spawnSync(["bash", HOOK], { cwd: other, stdin: Buffer.from(JSON.stringify({ tool_input: { command }, cwd: other })), stdout: "pipe", stderr: "pipe" });
          return proc.exitCode;
        };
        expect(run2(`git -C ${dir} commit -m "x"`)).toBe(2);
        expect(run2(`cd ${dir} && git commit -m "x"`)).toBe(2);
      } finally {
        rmSync(other, { recursive: true, force: true });
      }
    }));

  test("an item id inside a longer id or word does not satisfy a verdict", () =>
    withRepo((dir) => {
      put(dir, "docs/BACKLOG.md", "- [ ] two\n");
      git(dir, "add", "docs/BACKLOG.md");
      verdict(dir, "ARCH-1", "APPROVED");
      expect(run(dir, 'git commit -m "ARCH-12: other work"').exitCode).toBe(2);
      expect(run(dir, 'git commit -m "ARCH-1: this work"').exitCode).toBe(0);
    }));

  test("a ** glob also covers files directly under its prefix", () =>
    withRepo((dir) => {
      put(dir, "docs/design/RULES.md", "# Rules\n\n## Chat turn\n\nRecord: [x](../plans/x.md)\nGoverns: backend/**/*.ts\n");
      git(dir, "add", "docs/design/RULES.md");
      git(dir, "commit", "-q", "-m", "rules");
      put(dir, "backend/x.ts", "v2\n");
      git(dir, "add", "backend/x.ts");
      expect(run(dir, 'git commit -m "x"').exitCode).toBe(2);
    }));

  test("a here-string does not hide the commit, and cd with $HOME or ~ still finds the repo", () =>
    withRepo((dir) => {
      put(dir, "docs/BACKLOG.md", "- [ ] two\n");
      git(dir, "add", "docs/BACKLOG.md");
      expect(run(dir, 'read x <<< foo\ngit commit -m "a"').exitCode).toBe(2);
      const home = mkdtempSync(join(tmpdir(), "architect-hook-home-"));
      try {
        Bun.spawnSync(["ln", "-s", dir, join(home, "repo")]);
        const proc = Bun.spawnSync(["bash", HOOK], { cwd: tmpdir(), env: { ...process.env, HOME: home }, stdin: Buffer.from(JSON.stringify({ tool_input: { command: 'cd ~/repo && git commit -m "x"' }, cwd: tmpdir() })), stdout: "pipe", stderr: "pipe" });
        expect(proc.exitCode).toBe(2);
        const proc2 = Bun.spawnSync(["bash", HOOK], { cwd: tmpdir(), env: { ...process.env, HOME: home }, stdin: Buffer.from(JSON.stringify({ tool_input: { command: 'cd "$HOME/repo" && git commit -m "x"' }, cwd: tmpdir() })), stdout: "pipe", stderr: "pipe" });
        expect(proc2.exitCode).toBe(2);
      } finally {
        rmSync(home, { recursive: true, force: true });
      }
    }));
});
