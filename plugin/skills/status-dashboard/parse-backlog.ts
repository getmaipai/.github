#!/usr/bin/env bun
// Parses a repo's docs/BACKLOG.md into per-area status rollups.
// Usage: bun run parse-backlog.ts <repo> <path-to-repo-root>
// Prints one JSON object to stdout: { repo, phase, areas: [...] }

import { readFileSync, existsSync } from "fs";
import { join } from "path";

const PHASE_BY_REPO: Record<string, string> = {
  home: "Hub",
  bot: "Robot parity",
  go: "Go",
  catalog: "Catalog (infra)",
  stack: "Stack (foundation)",
};

type Item = { checked: boolean; text: string };
type Area = {
  area: string;
  done: number;
  open: number;
  status: "green" | "yellow" | "red" | "gray";
  built: string[];
  missing: string[];
  waiting: string[];
};

// An open item is "waiting on Jesse" when its own text says so - never
// inferred, always the item's own explicit marker, so a false positive
// means the BACKLOG row itself is miswritten, not this parser guessing.
// "Open question" alone is too broad - it's also used for questions a
// bench or a design pass resolves, not just Jesse's own; "Jesse's
// call"/"owner's call" is this doc's own deliberate, reliable marker
// for "needs Jesse specifically" (confirmed: every "open question"
// instance that really needs Jesse also carries one of these two).
// A trailing number ("owner's call 5") is a citation to an already-
// made, numbered decision recorded elsewhere, not a live pending
// question - found live 2026-09-25, REFERENCE-UPDATES-01's own nested
// item cites "owner's call 5: 'default for a child is...'" with the
// decision quoted right there, already answered, only the build left.
// A word boundary after "call" excludes "calling"/"callback" and the
// like - matched literally, not just the substring "call".
export const WAITING_RE = /jesse['’]?s call\b(?!\s*\d)|owner['’]?s call\b(?!\s*\d)/i;

// The item's own lead-in: everything up to its first " - " separator
// (the doc's own consistent convention, bolded title or not - "**Title**
// (tag) - body" and "(N) body (tag) - body" both use it), capped so an
// item with no dash at all doesn't scan its entire body. Replaces a
// flat character-count slice, which either cut into unrelated body
// prose (a false positive) or missed a long bold title (a false
// negative) - found live 2026-09-25 reviewing this file against real
// BACKLOG.md text.
const LEAD_IN_CAP = 300;
export function leadIn(text: string): string {
  const dash = text.indexOf(" - ");
  const cut = dash === -1 ? text.length : dash;
  return text.slice(0, Math.min(cut, LEAD_IN_CAP));
}

function shortLabel(raw: string): string {
  let text = raw.trim();
  // Prefer a **bolded** lead-in as the label if present.
  const bold = text.match(/^\*\*(.+?)\*\*/);
  if (bold) return bold[1].trim().replace(/[.:]$/, "");
  // A bold marker can open here and close on a later (unread) line; strip
  // the stray opener rather than leaving a literal "**" in the label.
  text = text.replace(/^\*\*/, "");
  // Otherwise take up to the first sentence break or a length cap.
  const period = text.indexOf(". ");
  if (period > 0 && period < 100) return text.slice(0, period).trim();
  return text.length > 90 ? text.slice(0, 87).trim() + "..." : text.trim();
}

export function parseBacklogText(raw: string): Area[] {
  const lines = raw.split("\n");

  const areas: Area[] = [];
  let current: { name: string; items: Item[] } | null = null;
  const sections: { name: string; items: Item[] }[] = [];

  for (const line of lines) {
    const heading = line.match(/^## (.+)$/);
    if (heading) {
      if (current) sections.push(current);
      current = { name: heading[1].trim(), items: [] };
      continue;
    }
    // Leading whitespace is allowed - a nested checklist line ("  - [ ]
    // (1) ...", a sub-piece of a parent item split out for separate
    // tracking) is its own item too, not prose to fold into the parent
    // and not invisible to the counts. Found live 2026-09-25: this
    // parser previously required zero indent, so every nested item in
    // every BACKLOG.md silently vanished from both the done/open
    // counts and (once it existed) the waiting-item detection below -
    // REFERENCE-UPDATES-01's own nested owner's-call sub-item was the
    // review's confirmed repro.
    const item = line.match(/^\s*- \[([ xX])\]\s*(.+)$/);
    if (item && current) {
      current.items.push({ checked: item[1].toLowerCase() === "x", text: item[2] });
      continue;
    }
    // A wrapped continuation line (indented, not a new item/heading): fold
    // it into the item text so a truncated label isn't cut mid-sentence.
    // Every checklist line, nested or not, already matched and `continue`d
    // above, so anything reaching here is real prose, never a checkbox to
    // guard against re-matching.
    const continuation = line.match(/^\s{4,}(\S.*)$/);
    if (continuation && current && current.items.length) {
      const last = current.items[current.items.length - 1];
      last.text += " " + continuation[1].trim();
    }
  }
  if (current) sections.push(current);

  for (const s of sections) {
    const done = s.items.filter((i) => i.checked);
    const open = s.items.filter((i) => !i.checked);
    // An empty/meta section (no checkbox items at all - a blank review-queue
    // table, a preamble) isn't a real status to show on the dashboard.
    if (done.length === 0 && open.length === 0) continue;
    const status: Area["status"] = open.length === 0 ? "green" : done.length === 0 ? "red" : "yellow";

    // Only the item's own lead-in counts - a mention of "Jesse's call"
    // or "owner's call" buried deep in an item's body is usually
    // recording a PAST decision on some sub-point, not saying this
    // still-open item is itself blocked on one now (found live:
    // CHAT-20's own still-open item records a 2026-09-13 "Jesse's
    // call" about chip text, unrelated to why the item is still open).
    const waiting = open.filter((i) => WAITING_RE.test(leadIn(i.text)));

    areas.push({
      area: s.name,
      done: done.length,
      open: open.length,
      status,
      built: done.slice(0, 2).map((i) => shortLabel(i.text)),
      missing: open.slice(0, 2).map((i) => shortLabel(i.text)),
      waiting: waiting.map((i) => shortLabel(i.text)),
    });
  }

  return areas;
}

// Guarded so importing this module (the test file does) never runs the
// CLI path or touches argv/exit.
if (import.meta.main) {
  const [repo, repoRoot] = process.argv.slice(2);
  if (!repo || !repoRoot) {
    console.error("Usage: bun run parse-backlog.ts <repo-name> <repo-root-path>");
    process.exit(1);
  }

  const backlogPath = join(repoRoot, "docs", "BACKLOG.md");
  if (!existsSync(backlogPath)) {
    console.error(`No docs/BACKLOG.md at ${backlogPath}`);
    process.exit(1);
  }

  const areas = parseBacklogText(readFileSync(backlogPath, "utf8"));
  console.log(JSON.stringify({ repo, phase: PHASE_BY_REPO[repo] ?? repo, areas }, null, 2));
}
