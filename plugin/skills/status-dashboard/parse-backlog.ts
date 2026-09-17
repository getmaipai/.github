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
};

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

function parseBacklog(path: string): Area[] {
  const raw = readFileSync(path, "utf8");
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
    const item = line.match(/^- \[([ xX])\]\s*(.+)$/);
    if (item && current) {
      current.items.push({ checked: item[1].toLowerCase() === "x", text: item[2] });
      continue;
    }
    // A wrapped continuation line (indented, not a new item/heading): fold
    // it into the item text so a truncated label isn't cut mid-sentence.
    // A nested checklist line (still "- [ ]"/"- [x]" once indent is
    // stripped) is its own item, not prose to merge - skip it here rather
    // than silently absorbing its checkbox state into the parent's text.
    const continuation = line.match(/^\s{4,}(\S.*)$/);
    if (continuation && !/^- \[[ xX]\]/.test(continuation[1]) && current && current.items.length) {
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

    areas.push({
      area: s.name,
      done: done.length,
      open: open.length,
      status,
      built: done.slice(0, 2).map((i) => shortLabel(i.text)),
      missing: open.slice(0, 2).map((i) => shortLabel(i.text)),
    });
  }

  return areas;
}

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

const areas = parseBacklog(backlogPath);
console.log(JSON.stringify({ repo, phase: PHASE_BY_REPO[repo] ?? repo, areas }, null, 2));
