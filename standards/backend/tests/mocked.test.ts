import { test } from "bun:test";
import { mock } from "bun:test";
mock.module("../src/lib/apps.ts", () => ({}));
test("t", () => {});
