// Regression coverage for three real bugs found live 2026-09-25 while
// building the "waiting on you" dashboard feature (see SKILL.md,
// "Waiting on you"). Each test reproduces the exact BACKLOG.md shape
// that broke, in the exact words.
import { describe, expect, test } from "bun:test";
import { parseBacklogText, leadIn, WAITING_RE } from "./parse-backlog";

function area(md: string) {
  const areas = parseBacklogText(`## Test area\n${md}`);
  expect(areas).toHaveLength(1);
  return areas[0]!;
}

describe("nested checklist sub-items are counted, not dropped", () => {
  test("a 2-space-indented sub-item is its own item", () => {
    const a = area(
      "- [ ] **REFERENCE-UPDATES-01: parent item** (S). Two pieces.\n" +
        '  - [ ] (1) A `reference.images` setting (owner\'s call 5: "default is X") - build later.\n' +
        "  - [x] (2) A reference field on the update projection. Landed in `6ee2653a`.\n",
    );
    // parent + 2 children = 3 items, 1 done (child 2) + 2 open (parent, child 1)
    expect(a.done).toBe(1);
    expect(a.open).toBe(2);
  });

  test("a genuinely non-checklist indented line still folds as a continuation", () => {
    const a = area(
      "- [ ] **Short title** (S). First sentence.\n" + "    A wrapped continuation line, not a checkbox.\n",
    );
    expect(a.open).toBe(1);
    expect(a.done).toBe(0);
  });
});

describe("WAITING_RE: a numbered citation to an already-made decision is not a pending question", () => {
  test("'owner's call 5' with the answer quoted inline does not match", () => {
    expect(WAITING_RE.test("owner's call 5: \"default for a child is Vikidia\"")).toBe(false);
  });

  test("'Jesse's call' with no trailing number still matches", () => {
    expect(WAITING_RE.test("(S, Jesse's call, not code)")).toBe(true);
  });

  test("a bare 'owner's call' with no number still matches", () => {
    expect(WAITING_RE.test("(S, owner's call)")).toBe(true);
  });
});

describe("WAITING_RE: word boundary after 'call'", () => {
  test("'owner's callback' does not match", () => {
    expect(WAITING_RE.test("owner's callback on this is pending")).toBe(false);
  });

  test("'Jesse's calling' does not match", () => {
    expect(WAITING_RE.test("Jesse's calling the shots here")).toBe(false);
  });
});

describe("WAITING_RE: curly apostrophe matches the same as straight", () => {
  test("typographic apostrophe (’) matches", () => {
    expect(WAITING_RE.test("(S, Jesse’s call)")).toBe(true);
  });
});

describe("leadIn: bounds the waiting-detection window to the item's own header", () => {
  test("a bold title with a short tag, dash-separated, is the whole lead-in", () => {
    expect(leadIn("**Resolve X** (S, Jesse's call) - the org's own rule conflicts with...")).toBe(
      "**Resolve X** (S, Jesse's call)",
    );
  });

  test("a mention of 'Jesse's call' recorded well past the first dash is out of the window", () => {
    const text =
      "**CHAT-20: title** (M). Frontend half: done, lane 8 item 2 - shipped 2026-09-13. " +
      "Chip text reduced, 2026-09-13 (Jesse's call).";
    expect(WAITING_RE.test(leadIn(text))).toBe(false);
  });

  test("an item's own real lead-in marker is still caught end to end", () => {
    const a = area("- [ ] **ASSIGNMENT.md legal review** (S, Jesse's call, not code) - the file is a draft.\n");
    expect(a.waiting).toEqual(["ASSIGNMENT.md legal review"]);
  });
});
