// RUN-GUARD-01 and RELIABILITY-PREVENT-09: `gate-lock.sh heavy`, the two machine-wide slots for heavy runs, the load and
// memory wait, the background priority, and the memory cap and cleanup on the run's own process group. Fake load, memory
// and resident-size readers come through the script's env overrides; the state lives in a scratch XDG_STATE_HOME.
import { describe, expect, test } from "bun:test";
import { chmodSync, existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const GATE_LOCK = join(import.meta.dir, "..", "..", "bin", "gate-lock.sh");
const scratch = () => mkdtempSync(join(tmpdir(), "heavy-run-test-"));
const base = (state: string, extra: Record<string, string> = {}) => ({
  ...process.env, XDG_STATE_HOME: state, GATE_HEAVY_POLL_SECONDS: "0.2", GATE_HEAVY_SAMPLE_SECONDS: "0.2", GATE_HEAVY_NOTE_SECONDS: "1",
  GATE_HEAVY_LOAD_CMD: "echo 1", GATE_HEAVY_FREE_CMD: "echo 80", ...extra,
}) as Record<string, string>;
const heavy = (state: string, label: string, cmd: string[], extra: Record<string, string> = {}, flags: string[] = []) =>
  Bun.spawn(["bash", GATE_LOCK, "heavy", label, ...flags, "--", ...cmd], { env: base(state, extra), stdout: "pipe", stderr: "pipe" });
async function done(proc: ReturnType<typeof heavy>) {
  const [out, err] = await Promise.all([new Response(proc.stdout).text(), new Response(proc.stderr).text()]);
  return { code: await proc.exited, out, err };
}
const alive = (pid: number) => { try { process.kill(pid, 0); return true; } catch { return false; } };

describe("waiting", () => {
  test("a busy computer holds the run back with a plain message, and gives up without starting it", async () => {
    const state = scratch(); const marker = join(state, "ran");
    const r = await done(heavy(state, "t-load", ["touch", marker], { GATE_HEAVY_LOAD_CMD: "echo 31", GATE_HEAVY_MAX_WAIT_SECONDS: "2" }));
    expect(r.code).toBe(75);
    expect(r.err).toContain("the computer is busy (load 31, limit 20)");
    expect(r.err).toContain("Nothing was started");
    expect(existsSync(marker)).toBe(false);
  });

  test("low free memory holds it back the same way", async () => {
    const state = scratch();
    const r = await done(heavy(state, "t-mem", ["true"], { GATE_HEAVY_FREE_CMD: "echo 12", GATE_HEAVY_MAX_WAIT_SECONDS: "1" }));
    expect(r.code).toBe(75);
    expect(r.err).toContain("low on free memory (12% free, need 25%)");
  });

  test("it starts by itself once the load clears", async () => {
    const state = scratch(); const flag = join(state, "load");
    writeFileSync(flag, "40");
    const proc = heavy(state, "t-clear", ["echo", "ran"], { GATE_HEAVY_LOAD_CMD: `cat ${flag}`, GATE_HEAVY_MAX_WAIT_SECONDS: "20" });
    await Bun.sleep(700); writeFileSync(flag, "2");
    const r = await done(proc);
    expect(r.code).toBe(0); expect(r.out).toContain("ran"); expect(r.err).toContain("is waiting to start");
  });

  test("only two run at once machine-wide; a third waits for a slot", async () => {
    const state = scratch();
    const a = heavy(state, "t-a", ["sleep", "4"]); const b = heavy(state, "t-b", ["sleep", "4"]);
    await Bun.sleep(800);
    const c = await done(heavy(state, "t-c", ["true"], { GATE_HEAVY_MAX_WAIT_SECONDS: "1" }));
    expect(c.code).toBe(75); expect(c.err).toContain("both heavy-run slots are in use");
    a.kill(); b.kill(); await a.exited; await b.exited;
    const d = await done(heavy(state, "t-d", ["echo", "after"]));
    expect(d.code).toBe(0);
  });
});

describe("priority and exit codes", () => {
  test("the command starts through taskpolicy -b", async () => {
    const state = scratch(); const fake = join(state, "taskpolicy"); const log = join(state, "args");
    writeFileSync(fake, `#!/bin/sh\necho "$@" > ${log}\nshift\nexec "$@"\n`); chmodSync(fake, 0o755);
    const r = await done(heavy(state, "t-prio", ["echo", "hi"], { GATE_HEAVY_TASKPOLICY: fake }));
    expect(r.code).toBe(0); expect(readFileSync(log, "utf8").trim()).toBe("-b echo hi");
  });

  test("the command's own exit code comes back, and the slot is freed", async () => {
    const state = scratch();
    expect((await done(heavy(state, "t-rc", ["sh", "-c", "exit 7"]))).code).toBe(7);
    expect((await done(heavy(state, "t-rc2", ["true"]))).code).toBe(0);
  });

  test("a heavy run inside a heavy run just runs", async () => {
    const state = scratch();
    const r = await done(heavy(state, "t-outer", ["bash", GATE_LOCK, "heavy", "t-inner", "--", "echo", "nested"], { GATE_HEAVY_SLOTS: "1" }));
    expect(r.code).toBe(0); expect(r.out).toContain("nested");
  });
});

describe("memory cap and cleanup on the run's own group", () => {
  test("a group over the cap is stopped by its group id and nothing outside it is touched", async () => {
    const state = scratch();
    const outside = Bun.spawn(["sleep", "30"]);
    // 5 GB per process in the group: the command's shell plus its two sleeps is over an 8 GB cap.
    const rss = `ps -ax -o pgid=,command= | awk -v g=$GATE_HEAVY_PGID '$1 == g {n++} END {print n * 5000000}'`;
    const r = await done(heavy(state, "t-cap", ["sh", "-c", "sleep 30 & sleep 30 & wait"], { GATE_HEAVY_RSS_CMD: rss }));
    expect(r.code).toBe(137);
    expect(r.err).toContain("over its 8 GB limit");
    expect(alive(outside.pid)).toBe(true);
    outside.kill();
  });

  test("--mem-gb sets the cap for one run", async () => {
    const state = scratch();
    const rss = `ps -ax -o pgid=,command= | awk -v g=$GATE_HEAVY_PGID '$1 == g {n++} END {print n * 5000000}'`;
    const r = await done(heavy(state, "t-cap2", ["sh", "-c", "sleep 3 & wait"], { GATE_HEAVY_RSS_CMD: rss }, ["--mem-gb", "40"]));
    expect(r.code).toBe(0); expect(r.err).toContain("limit 40 GB");
  });

  test("helpers a finished run left behind are gone when it ends", async () => {
    const state = scratch(); const pidFile = join(state, "helper.pid");
    const r = await done(heavy(state, "t-clean", ["sh", "-c", `sleep 60 & echo $! > ${pidFile}`]));
    expect(r.code).toBe(0);
    const pid = Number(readFileSync(pidFile, "utf8").trim());
    await Bun.sleep(300);
    expect(alive(pid)).toBe(false);
  });
});
