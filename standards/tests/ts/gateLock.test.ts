// GATE-LOCK-01: standards/bin/gate-lock.sh, the machine-wide full-gate
// mutex every repo's scripts/check.sh takes before a non-docs scope
// (docs/DECISIONS.md, 2026-09-27). Spawns the real script with bash,
// against a scratch XDG_STATE_HOME this file creates under its own temp
// dir, so a run never reads or writes the real
// ~/.local/state/maipai/gate-lock/ that live gates on this machine are
// using. The poll interval and wait allowance are shortened through the
// script's own env overrides so the suite runs in seconds.
import { describe, expect, test } from "bun:test";
import { chmodSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const GATE_LOCK = join(import.meta.dir, "..", "..", "bin", "gate-lock.sh");

interface Result {
  exitCode: number;
  stdout: string;
  stderr: string;
}

/** A scratch state home. Caller owns cleanup via the returned dir. */
function makeStateHome(): string {
  return mkdtempSync(join(tmpdir(), "gate-lock-test-"));
}

function lockDir(stateHome: string): string {
  return join(stateHome, "maipai", "gate-lock");
}

function env(stateHome: string, extra: Record<string, string> = {}): Record<string, string> {
  return { ...process.env, XDG_STATE_HOME: stateHome, GATE_LOCK_POLL_SECONDS: "0.2", ...extra } as Record<string, string>;
}

function run(stateHome: string, args: string[], extra: Record<string, string> = {}): Result {
  const proc = Bun.spawnSync(["bash", GATE_LOCK, ...args], { env: env(stateHome, extra), stdout: "pipe", stderr: "pipe" });
  return { exitCode: proc.exitCode ?? -1, stdout: proc.stdout.toString(), stderr: proc.stderr.toString() };
}

/** Runs a bash snippet in the background with $G pointing at the real
 * script. The snippet's own shell is the lock's owning process (the
 * script records its parent's PID), the way check.sh is in real use. */
function spawnShell(stateHome: string, script: string) {
  return Bun.spawn(["bash", "-c", script], { env: env(stateHome, { G: GATE_LOCK }), stdout: "pipe", stderr: "pipe" });
}

/** A millisecond wall-clock stamp from inside a bash snippet (macOS
 * `date` has no %N). */
const STAMP = `$(perl -MTime::HiRes=time -e 'printf "%.3f", time')`;

async function waitFor(predicate: () => boolean, timeoutMs = 10_000): Promise<void> {
  const start = Date.now();
  while (!predicate()) {
    if (Date.now() - start > timeoutMs) throw new Error("timed out waiting for condition");
    await Bun.sleep(50);
  }
}

function logLines(path: string): string[] {
  return existsSync(path) ? readFileSync(path, "utf8").trim().split("\n").filter(Boolean) : [];
}

describe("GATE-LOCK-01: gate-lock.sh, the machine-wide full-gate mutex", () => {
  test("(a) acquire on a free lock succeeds at once and records who holds it", () => {
    const home = makeStateHome();
    try {
      const started = Date.now();
      const result = run(home, ["acquire", "home-111", "ITEM-01"]);
      expect(result.exitCode).toBe(0);
      expect(result.stdout.trim()).toBe("acquired");
      expect(Date.now() - started).toBeLessThan(2000);

      const holder = readFileSync(join(lockDir(home), "holder"), "utf8").trim().split("\t");
      expect(holder[0]).toBe("home-111");
      expect(holder[1]).toBe("ITEM-01");
      expect(Number(holder[2])).toBe(process.pid); // the caller's PID, never the exited script's own
      expect(holder[3]).toMatch(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/);
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("(b) a second acquire while the first holds queues, and only gets the lock after the first releases", async () => {
    const home = makeStateHome();
    const log = join(home, "order.log");
    try {
      const a = spawnShell(
        home,
        `bash "$G" acquire gate-a ITEM-A >/dev/null || exit 1
         echo "a-acquired ${STAMP}" >> "${log}"
         sleep 1.5
         echo "a-releasing ${STAMP}" >> "${log}"
         bash "$G" release gate-a >/dev/null`,
      );
      await waitFor(() => logLines(log).length === 1);

      const b = spawnShell(
        home,
        `echo "b-requested ${STAMP}" >> "${log}"
         bash "$G" acquire gate-b ITEM-B >/dev/null || exit 1
         echo "b-acquired ${STAMP}" >> "${log}"
         bash "$G" release gate-b >/dev/null`,
      );
      // While A still holds, B is visibly on the queue, not spinning unrecorded.
      await waitFor(() => run(home, ["status"]).stdout.includes("gate-b"));
      const midWait = run(home, ["status"]).stdout;
      expect(midWait).toContain("held: gate-a");
      expect(midWait).toMatch(/queue:\n {2}gate-b\tITEM-B\t/);

      expect(await a.exited).toBe(0);
      expect(await b.exited).toBe(0);

      const lines = logLines(log);
      console.log(`gate-lock (b) order log:\n  ${lines.join("\n  ")}`);
      expect(lines.map((l) => l.split(" ")[0])).toEqual(["a-acquired", "b-requested", "a-releasing", "b-acquired"]);
      const at = Object.fromEntries(lines.map((l) => [l.split(" ")[0], Number(l.split(" ")[1])]));
      expect(at["b-acquired"]).toBeGreaterThanOrEqual(at["a-releasing"]);
      expect(at["b-acquired"] - at["b-requested"]).toBeGreaterThan(1.0); // B really waited out A's hold
      expect(run(home, ["status"]).stdout.trim()).toBe("free");
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("(b) waiters are served first come, first served", async () => {
    const home = makeStateHome();
    const log = join(home, "fifo.log");
    try {
      const a = spawnShell(
        home,
        `bash "$G" acquire fifo-a >/dev/null || exit 1
         echo "a" >> "${log}"
         sleep 1.5
         bash "$G" release fifo-a >/dev/null`,
      );
      await waitFor(() => logLines(log).length === 1);
      const b = spawnShell(home, `bash "$G" acquire fifo-b >/dev/null || exit 1; echo b >> "${log}"; sleep 0.5; bash "$G" release fifo-b >/dev/null`);
      await waitFor(() => run(home, ["status"]).stdout.includes("fifo-b"));
      const c = spawnShell(home, `bash "$G" acquire fifo-c >/dev/null || exit 1; echo c >> "${log}"; bash "$G" release fifo-c >/dev/null`);

      expect(await a.exited).toBe(0);
      expect(await b.exited).toBe(0);
      expect(await c.exited).toBe(0);
      expect(logLines(log)).toEqual(["a", "b", "c"]);
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("one queued gate per lane is enforced across lock classes with a named refusal", async () => {
    const home = makeStateHome();
    const fullDir = lockDir(home);
    const frontendDir = join(home, "maipai", "gate-lock-frontend");
    try {
      mkdirSync(fullDir, { recursive: true });
      mkdirSync(frontendDir, { recursive: true });
      writeFileSync(join(fullDir, "holder"), `full-holder\t\t${process.pid}\t2026-09-27T00:00:00Z\n`);
      writeFileSync(join(frontendDir, "holder"), `frontend-holder\t\t${process.pid}\t2026-09-27T00:00:00Z\n`);

      const first = spawnShell(home,
        `bash "$G" acquire first-waiter FIRST codex-a >/dev/null || exit 1; bash "$G" release first-waiter >/dev/null`,
      );
      await waitFor(() => logLines(join(home, "maipai", "gate-lanes", "queue")).some((l) => l.startsWith("codex-a\tfirst-waiter\tFIRST\t")));

      const second = Bun.spawnSync(["bash", GATE_LOCK, "acquire", "second-waiter", "SECOND", "codex-a"], {
        env: env(home, { GATE_LOCK_NAME: "frontend" }), stdout: "pipe", stderr: "pipe",
      });
      expect(second.exitCode).toBe(1);
      expect(second.stderr.toString()).toContain("lane codex-a already has queued gate first-waiter (item FIRST)");

      // A distinct lane may queue in the other lock class.
      const third = spawnShell(home,
        `export GATE_LOCK_NAME=frontend; bash "$G" acquire third-waiter THIRD codex-b >/dev/null || exit 1; bash "$G" release third-waiter >/dev/null`,
      );
      await waitFor(() => logLines(join(home, "maipai", "gate-lanes", "queue")).some((l) => l.startsWith("codex-b\tthird-waiter\tTHIRD\t")));
      expect(run(home, ["status"]).stdout).toContain("full-holder");
      expect(run(home, ["release", "full-holder"]).exitCode).toBe(0);
      expect(run(home, ["release", "frontend-holder"], { GATE_LOCK_NAME: "frontend" }).exitCode).toBe(0);
      expect(await first.exited).toBe(0);
      expect(await third.exited).toBe(0);
      expect(logLines(join(home, "maipai", "gate-lanes", "queue"))).toEqual([]);
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("(b) four gates started at the same instant never overlap: each one's in/out pair closes before the next opens", async () => {
    const home = makeStateHome();
    const log = join(home, "mutex.log");
    try {
      const gates = ["m1", "m2", "m3", "m4"].map((name) =>
        spawnShell(home, `bash "$G" acquire ${name} >/dev/null || exit 1; echo "in ${name}" >> "${log}"; sleep 0.3; echo "out ${name}" >> "${log}"; bash "$G" release ${name} >/dev/null`),
      );
      for (const gate of gates) expect(await gate.exited).toBe(0);
      const lines = logLines(log);
      expect(lines).toHaveLength(8);
      for (let i = 0; i < lines.length; i += 2) {
        const name = lines[i].split(" ")[1];
        expect(lines[i]).toBe(`in ${name}`);
        expect(lines[i + 1]).toBe(`out ${name}`);
      }
      expect(run(home, ["status"]).stdout.trim()).toBe("free");
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("(c) an empty holder record (a claimant that died mid-write) is reclaimed, not left to wedge every gate", () => {
    const home = makeStateHome();
    try {
      mkdirSync(lockDir(home), { recursive: true });
      writeFileSync(join(lockDir(home), "holder"), "");
      const result = run(home, ["acquire", "home-777"]);
      expect(result.exitCode).toBe(0);
      expect(result.stderr).toContain("reclaiming an empty holder record");
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("an unwritable state directory fails acquire at once instead of hanging", () => {
    const home = makeStateHome();
    try {
      chmodSync(home, 0o500);
      const started = Date.now();
      const result = run(home, ["acquire", "home-888"]);
      expect(result.exitCode).toBe(1);
      expect(result.stderr).toContain("cannot write the lock state");
      expect(Date.now() - started).toBeLessThan(2000);
    } finally {
      chmodSync(home, 0o700);
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("(c) a holder whose PID is dead is reclaimed as stale without waiting", async () => {
    const home = makeStateHome();
    try {
      const doomed = Bun.spawn(["sleep", "60"]);
      const deadPid = doomed.pid;
      doomed.kill();
      await doomed.exited;

      mkdirSync(lockDir(home), { recursive: true });
      writeFileSync(join(lockDir(home), "holder"), `crashed-gate\tITEM-X\t${deadPid}\t2026-09-27T00:00:00Z\n`);
      expect(run(home, ["status"]).stdout).toContain(`stale, pid ${deadPid} not running`);

      const started = Date.now();
      const result = run(home, ["acquire", "home-222"]);
      expect(result.exitCode).toBe(0);
      expect(result.stdout.trim()).toBe("acquired");
      expect(result.stderr).toContain(`reclaiming a stale lock held by crashed-gate (pid ${deadPid} is not running)`);
      expect(Date.now() - started).toBeLessThan(2000);
      expect(readFileSync(join(lockDir(home), "holder"), "utf8")).toStartWith("home-222\t");
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("(c) a waiter killed while queued does not hold up the next one", () => {
    const home = makeStateHome();
    try {
      mkdirSync(lockDir(home), { recursive: true });
      const deadPid = Bun.spawnSync(["bash", "-c", "echo $$"]).stdout.toString().trim();
      writeFileSync(join(lockDir(home), "queue"), `killed-waiter\t\t2026-09-27T00:00:00Z\t${deadPid}\n`);
      const result = run(home, ["acquire", "home-333"]);
      expect(result.exitCode).toBe(0);
      expect(readFileSync(join(lockDir(home), "queue"), "utf8")).toBe("");
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("(d) release by a label that does not hold the lock is refused and leaves the holder in place", () => {
    const home = makeStateHome();
    try {
      expect(run(home, ["acquire", "home-444"]).exitCode).toBe(0);
      const refused = run(home, ["release", "someone-else"]);
      expect(refused.exitCode).not.toBe(0);
      expect(refused.stderr.trim()).toBe("refused: held by home-444, not someone-else");
      expect(run(home, ["status"]).stdout).toContain("held: home-444");

      const released = run(home, ["release", "home-444"]);
      expect(released.exitCode).toBe(0);
      expect(released.stdout.trim()).toBe("released");
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("(e) status reports free, then the holder record once held", () => {
    const home = makeStateHome();
    try {
      const free = run(home, ["status"]);
      expect(free.exitCode).toBe(0);
      expect(free.stdout.trim()).toBe("free");

      expect(run(home, ["acquire", "home-555", "ITEM-05"]).exitCode).toBe(0);
      const held = run(home, ["status"]);
      expect(held.exitCode).toBe(0);
      expect(held.stdout).toMatch(new RegExp(`^held: home-555\\tITEM-05\\t${process.pid}\\t`));
      expect(held.stdout).not.toContain("queue:");
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });

  test("a wait past its allowance gives up with exit 1, says how long and where, and leaves the queue", () => {
    const home = makeStateHome();
    try {
      mkdirSync(lockDir(home), { recursive: true });
      // A live holder (this test process) that never releases.
      writeFileSync(join(lockDir(home), "holder"), `stuck-gate\t\t${process.pid}\t2026-09-27T00:00:00Z\n`);
      const result = run(home, ["acquire", "home-666"], { GATE_LOCK_PER_POSITION_SECONDS: "1" });
      expect(result.exitCode).toBe(1);
      expect(result.stderr).toMatch(/gave up after \d+s at queue position 1 \(allowance 1s\)/);
      expect(readFileSync(join(lockDir(home), "queue"), "utf8")).toBe("");
      expect(readFileSync(join(lockDir(home), "holder"), "utf8")).toStartWith("stuck-gate\t");
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });
  test("GATE-SPEED-01: a named lock class (frontend) is free while the machine-wide lock is held, and queues only behind its own class", () => {
    const home = makeStateHome();
    try {
      expect(run(home, ["acquire", "home-main", "BACKEND"]).exitCode).toBe(0);
      const frontend = run(home, ["acquire", "home-fe", "FRONTEND"], { GATE_LOCK_NAME: "frontend" });
      expect(frontend.exitCode).toBe(0);
      expect(frontend.stdout).toContain("acquired");
      expect(existsSync(join(home, "maipai", "gate-lock-frontend", "holder"))).toBe(true);
      // The machine-wide holder is untouched, and a second frontend gate is refused its class lock.
      expect(readFileSync(join(lockDir(home), "holder"), "utf8")).toStartWith("home-main\t");
      const second = run(home, ["acquire", "home-fe2"], { GATE_LOCK_NAME: "frontend", GATE_LOCK_PER_POSITION_SECONDS: "1" });
      expect(second.exitCode).toBe(1);
    } finally {
      rmSync(home, { recursive: true, force: true });
    }
  });
});
