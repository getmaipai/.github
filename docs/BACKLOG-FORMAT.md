# Backlog and issues

Dev tier. Full text of the backlog and issue rules. Load before editing `docs/BACKLOG.md`, filing an issue, or refreshing the status dashboard.

## Issues: file noticed bugs and ideas

Bugs and ideas noticed mid-task get filed as GitHub Issues in that repo,
even when not being fixed now. GitHub Issues are the tracker of record for
getmaipai repos (they mirror to Gitea automatically). Jesse's Gitea remains
the tracker for homelab matters. File through the maipai plugin's
`issue` skill: it searches open issues first and comments on a match
instead of filing a duplicate.

## Issues: write like a person

**Write issue bodies like a person describing the problem, not a bot filling
out a template.** A bug report says what happened and what you expected to
happen instead, in plain words a non-engineer could follow. A feature
request says what someone wants and why it'd help, not a spec. The title
and opening line should make sense to Jesse on his phone with zero context
loaded. Technical detail (stack traces, logs, exact repro steps, file/line
pointers) is welcome, but goes underneath the plain-language summary, not
instead of it. The same AI writing standards as everywhere else apply here
too (see Writing style above): no em dashes, no filler vocabulary, no
robotic "as an AI" phrasing, no listing symptoms without ever saying what's
actually wrong in a sentence a person would say out loud.

## Issues: enforced structurally

**This is enforced structurally, not by memory.** `.github/ISSUE_TEMPLATE/`
in this repo (`bug_report.yml`, `feature_request.yml`) is GitHub's
org-wide default: any repo in the org without its own issue templates
(every repo, currently) serves these automatically, so the plain-language
prompts show up for human contributors and AI sessions alike, on GitHub's
side, with no per-repo copy to keep in sync. A repo only needs its own
templates if it genuinely needs different fields; if so, keep the same
plain-language framing.

## Backlog: BACKLOG.md tracks build status

Issues track bugs and one-off requests; **`docs/BACKLOG.md` tracks build
status** - what's built and what's missing, per area, in every repo. One
definition, no second parallel system (no GitHub Project, no custom fields):
a visual status dashboard reads this file directly, so it has to stay real.

## Backlog: every repo keeps one, in Home's shape

**Every repo keeps a `docs/BACKLOG.md`**, in the shape `home`'s already
uses: scannable, not narrative (the reasoning and decision history live in
`docs/dev.md`, linked where useful); size-tagged **S** (a session or
less), **M** (a real slice, days), **L** (a platform-level capability,
needs its own design pass first); organized under `## Area` headings that
reflect how that repo actually breaks down (a package category, a
subsystem, a chapter of the platform plan); `- [ ]`/`- [x]` per item.

## Backlog: update in the same commit

**Update it in the same commit as the change that closes or opens a
gap.** A BACKLOG.md that drifts from what `main` actually does is worse
than not having one, because the dashboard trusts it.

## Backlog: item template

**Item template**, so a `- [ ]` is pickup-ready for any AI agent, not just
a session that already has this conversation's context: a one-line
objective, file/dir pointers, an existing file or pattern to mirror,
acceptance criteria, what's explicitly out of scope, and the exact exit
check (`scripts/check.sh` or a named test). Anything bigger than one item
gets a short design note in `docs/dev.md` first, then gets chunked into
BACKLOG items - never a new spec-file system invented per feature.

## Backlog: the dashboard is a derived view

**The dashboard is a derived view, never a second source.** The
`status-dashboard` skill (`getmaipai/.github`) parses every repo's
BACKLOG.md into a colored, phase-grouped status page; run it whenever a
BACKLOG.md changes, at latest before the session ends. This is an
instruction, not a hook: judging whether status actually changed needs
contextual reading, the same reason code-review-before-commit stays a
soft gate instead of a script.
