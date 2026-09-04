// Round-trips every fixture in standards/fixtures/ through its generated
// Zod model. Mirrors home/spec's proof for the same reason: these schemas
// are consumed cross-repo (home/spec imports error-entry and privacy-row),
// so both generated model sets have to actually work, not just exist.
import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { ErrorEntry } from "../../gen/ts/error-entry.js";
import { LoggingLine } from "../../gen/ts/logging-line.js";
import { TraceSpan } from "../../gen/ts/trace-span.js";
import { Budget } from "../../gen/ts/budget.js";
import { PrivacyRow } from "../../gen/ts/privacy-row.js";

const FIXTURES_DIR = join(import.meta.dir, "..", "..", "fixtures");

function loadFixture(name: string): unknown {
  return JSON.parse(readFileSync(join(FIXTURES_DIR, name), "utf-8"));
}

describe("standards fixtures validate against their generated Zod models", () => {
  test("error-entry.example.json", () => {
    expect(() => ErrorEntry.parse(loadFixture("error-entry.example.json"))).not.toThrow();
  });
  test("logging-line.example.json", () => {
    expect(() => LoggingLine.parse(loadFixture("logging-line.example.json"))).not.toThrow();
  });
  test("trace-span.example.json", () => {
    expect(() => TraceSpan.parse(loadFixture("trace-span.example.json"))).not.toThrow();
  });
  test("budget.example.json", () => {
    expect(() => Budget.parse(loadFixture("budget.example.json"))).not.toThrow();
  });
  test("privacy-row.example.json", () => {
    expect(() => PrivacyRow.parse(loadFixture("privacy-row.example.json"))).not.toThrow();
  });
});

describe("a bad record is rejected, not silently accepted", () => {
  test("privacy row missing 'who' fails", () => {
    const bad = loadFixture("privacy-row.example.json") as Record<string, unknown>;
    delete bad.who;
    expect(() => PrivacyRow.parse(bad)).toThrow();
  });
});
