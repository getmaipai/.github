// GATE-HOOK-02: require-gate-before-commit.sh and mark-gate-checked.sh
// (plugin/hooks/scripts/) had no automated test at all before this -
// GATE-HOOK-01 landed on "found live" testing only. Spawns both
// scripts for real, with the real PreToolUse/PostToolUse JSON payloads
// on stdin, against a scratch git repo this file creates under its own
// temp dir (never the real checkout, never global git config). Proves
// the org's own "gate per push, not per commit" rule: one recorded
// check.sh run covers a batch of commits from the unchanged tree it
// ran against, but a tracked-file edit after that record forces a
// fresh one, naming the file.
import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync, symlinkSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const HOOKS_DIR = join(import.meta.dir, "..", "..", "..", "plugin", "hooks", "scripts");
const REQUIRE_GATE = join(HOOKS_DIR, "require-gate-before-commit.sh");
const MARK_GATE = join(HOOKS_DIR, "mark-gate-checked.sh");

function git(cwd: string, ...args: string[]): string {
  const proc = Bun.spawnSync(["git", ...args], { cwd, stdout: "pipe", stderr: "pipe" });
  if (proc.exitCode !== 0) throw new Error(`git ${args.join(" ")} failed: ${proc.stderr.toString()}`);
  return proc.stdout.toString();
}

interface HookResult {
  exitCode: number;
  stdout: string;
  stderr: string;
}

function runHook(script: string, payload: unknown, cwd: string): HookResult {
  const proc = Bun.spawnSync(["bash", script], { cwd, stdin: Buffer.from(JSON.stringify(payload)), stdout: "pipe", stderr: "pipe" });
  return { exitCode: proc.exitCode, stdout: proc.stdout.toString(), stderr: proc.stderr.toString() };
}

/** A scratch git repo with its own local (never global) identity, one
 * commit already on `main`. Caller owns cleanup via the returned dir. */
function makeScratchRepo(): string {
  const dir = mkdtempSync(join(tmpdir(), "gate-hook-test-"));
  git(dir, "init", "-q", "-b", "main");
  git(dir, "config", "user.name", "Gate Hook Test");
  git(dir, "config", "user.email", "gate-hook-test@example.com");
  writeFileSync(join(dir, "a.txt"), "a1\n");
  writeFileSync(join(dir, "b.txt"), "b1\n");
  writeFileSync(join(dir, "README.md"), "readme v1\n");
  git(dir, "add", "-A");
  git(dir, "commit", "-q", "-m", "initial");
  return dir;
}

/** Simulates `bash scripts/check.sh` passing with the given scope
 * (mark-gate-checked.sh's own PostToolUse payload shape), stamping the
 * repo for `sessionId`. */
function stampGate(dir: string, sessionId: string, scope: "full" | "docs"): HookResult {
  const command = scope === "docs" ? "bash scripts/check.sh --docs" : "bash scripts/check.sh";
  const stdout = scope === "docs" ? "== standards core passed\n" : "== scope: full (a workspace package.json or lockfile changed)\n== all checks passed\n";
  return runHook(MARK_GATE, { tool_input: { command }, cwd: dir, session_id: sessionId, tool_response: { exitCode: 0, stdout } }, dir);
}

function tryCommit(dir: string, sessionId: string, message: string): HookResult {
  return runHook(REQUIRE_GATE, { tool_input: { command: `git commit -m "${message}"` }, cwd: dir, session_id: sessionId }, dir);
}

function tryCommitAll(dir: string, sessionId: string, message: string): HookResult {
  return runHook(REQUIRE_GATE, { tool_input: { command: `git commit -a -m "${message}"` }, cwd: dir, session_id: sessionId }, dir);
}

describe("GATE-HOOK-02: the batch allowance on require-gate-before-commit.sh / mark-gate-checked.sh", () => {
  test("(a) two successive commits from one gated, unchanged tree are both allowed", () => {
    const dir = makeScratchRepo();
    try {
      const session = "batch-session";
      writeFileSync(join(dir, "a.txt"), "a2\n");
      writeFileSync(join(dir, "b.txt"), "b2\n");
      expect(stampGate(dir, session, "full").exitCode).toBe(0);

      git(dir, "add", "a.txt");
      const first = tryCommit(dir, session, "first");
      expect(first.exitCode).toBe(0);
      git(dir, "commit", "-q", "-m", "first"); // the hook only judges; this performs the real commit, moving HEAD.

      git(dir, "add", "b.txt");
      const second = tryCommit(dir, session, "second");
      expect(second.exitCode).toBe(0);
      git(dir, "commit", "-q", "-m", "second");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("(a) the same holds for a pre-gated deletion committed in a later, unchanged-tree commit", () => {
    const dir = makeScratchRepo();
    try {
      const session = "batch-delete-session";
      git(dir, "rm", "-q", "b.txt");
      expect(stampGate(dir, session, "full").exitCode).toBe(0);
      // b.txt's removal is already staged from the `git rm` above - no
      // further `git add` needed before the commit attempt.
      const result = tryCommit(dir, session, "remove b");
      expect(result.exitCode).toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("(b) editing a file the gate already saw dirty, again, after the stamp, is refused by name", () => {
    const dir = makeScratchRepo();
    try {
      const session = "redirty-session";
      writeFileSync(join(dir, "a.txt"), "a2\n");
      expect(stampGate(dir, session, "full").exitCode).toBe(0);

      // Edited AGAIN after the stamp - the gate proved "a2", not this.
      writeFileSync(join(dir, "a.txt"), "a3-ungated\n");
      git(dir, "add", "a.txt");
      const result = tryCommit(dir, session, "sneaks in a3");
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toContain("a.txt");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("(b) editing a file that was clean at stamp time is refused by name", () => {
    const dir = makeScratchRepo();
    try {
      const session = "clean-then-dirty-session";
      // Only b.txt is dirty at stamp time; a.txt matches HEAD.
      writeFileSync(join(dir, "b.txt"), "b2\n");
      expect(stampGate(dir, session, "full").exitCode).toBe(0);

      // a.txt was untouched (clean) when the gate ran; now it isn't.
      writeFileSync(join(dir, "a.txt"), "a-ungated\n");
      git(dir, "add", "a.txt");
      const result = tryCommit(dir, session, "sneaks in a clean-file edit");
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toContain("a.txt");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("(b) a brand-new file the gate never saw at all is refused by name", () => {
    const dir = makeScratchRepo();
    try {
      const session = "new-file-session";
      writeFileSync(join(dir, "a.txt"), "a2\n");
      expect(stampGate(dir, session, "full").exitCode).toBe(0);

      writeFileSync(join(dir, "c.txt"), "never gated\n");
      git(dir, "add", "c.txt");
      const result = tryCommit(dir, session, "sneaks in a whole new file");
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toContain("c.txt");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("(c) a docs-only commit against a docs-scope record is allowed", () => {
    const dir = makeScratchRepo();
    try {
      const session = "docs-session";
      writeFileSync(join(dir, "README.md"), "readme v2\n");
      expect(stampGate(dir, session, "docs").exitCode).toBe(0);

      git(dir, "add", "README.md");
      const result = tryCommit(dir, session, "docs tweak");
      expect(result.exitCode).toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("(c) a docs-scope record does not cover a code file - refused, not silently waved through", () => {
    const dir = makeScratchRepo();
    try {
      const session = "docs-scope-miss-session";
      writeFileSync(join(dir, "README.md"), "readme v2\n");
      writeFileSync(join(dir, "a.txt"), "a2\n");
      expect(stampGate(dir, session, "docs").exitCode).toBe(0);

      git(dir, "add", "a.txt");
      const result = tryCommit(dir, session, "code change under a docs stamp");
      expect(result.exitCode).toBe(2);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("(b) `git commit -a` sweeping in a post-stamp edit to a file the index still shows as clean is refused by name", () => {
    const dir = makeScratchRepo();
    try {
      const session = "commit-a-session";
      writeFileSync(join(dir, "b.txt"), "b2\n");
      git(dir, "add", "b.txt");
      expect(stampGate(dir, session, "full").exitCode).toBe(0);

      // a.txt is untouched at stamp time (clean); edited after, but
      // never `git add`ed - only `-a` would sweep it in. The index
      // alone reads it as still matching HEAD.
      writeFileSync(join(dir, "a.txt"), "a-ungated\n");
      const result = tryCommitAll(dir, session, "commit -a sweeps in the ungated edit");
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toContain("a.txt");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("(b) a tracked dangling symlink retargeted after the stamp is refused by name, not misread as deleted", () => {
    const dir = makeScratchRepo();
    try {
      const linkPath = join(dir, "link1");
      symlinkSync("/nonexistent/target1", linkPath);
      git(dir, "add", "link1");
      git(dir, "commit", "-q", "-m", "add dangling symlink");

      const session = "symlink-session";
      unlinkSync(linkPath);
      symlinkSync("/nonexistent/target2-at-stamp", linkPath);
      expect(stampGate(dir, session, "full").exitCode).toBe(0);

      unlinkSync(linkPath);
      symlinkSync("/nonexistent/target3-after-stamp", linkPath);
      const result = tryCommitAll(dir, session, "retarget the symlink after the stamp");
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toContain("link1");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("a repo's very first commit (unborn HEAD at stamp time) is not permanently blocked", () => {
    const dir = mkdtempSync(join(tmpdir(), "gate-hook-test-"));
    try {
      git(dir, "init", "-q", "-b", "main");
      git(dir, "config", "user.name", "Gate Hook Test");
      git(dir, "config", "user.email", "gate-hook-test@example.com");
      writeFileSync(join(dir, "a.txt"), "a1\n");

      const session = "unborn-head-session";
      expect(stampGate(dir, session, "full").exitCode).toBe(0);

      git(dir, "add", "a.txt");
      const result = tryCommit(dir, session, "the very first commit");
      expect(result.exitCode).toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  test("no stamp at all is refused, no scope covers a commit that never gated", () => {
    const dir = makeScratchRepo();
    try {
      writeFileSync(join(dir, "a.txt"), "a2\n");
      git(dir, "add", "a.txt");
      const result = tryCommit(dir, "never-gated-session", "no gate ever ran");
      expect(result.exitCode).toBe(2);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
