---
name: issue
description: File a bug, a feature request, or an idea as a GitHub issue in the current getmaipai repo, fast and without duplicates - search open issues first, comment on a match, otherwise file with the org's plain-language template and the right label. Use when Jesse or a session says "file an issue", "log a bug", "feature request", "it would be nice if", "add this to the wishlist", or notices a defect mid-task that is not being fixed now.
---

# File an issue without a duplicate

Fast path, few tokens: one search, one decision, one create. Never
read the whole issue list; never open the browser.

## 1. Which repo

The repo is the `getmaipai/<name>` of the checkout you are in
(`gh repo view --json nameWithOwner -q .nameWithOwner`). Homelab
matters go to Jesse's Gitea, not here; stop and say so.

## 2. Search before filing (the duplicate gate)

Pick two or three distinctive words from the problem (a component
name, an error phrase, a user-visible symptom; not "bug", "chat", or
"page"). Run one search over open issues only, titles and bodies:

```
gh issue list -R getmaipai/<repo> --state open --search "<words>" \
  --limit 8 --json number,title -q '.[] | "\(.number) \(.title)"'
```

Then decide:

- **A match describes the same defect or request** (same symptom or
  same want, even if a different cause is guessed): do not file. Add
  one comment with the new evidence (`gh issue comment <n> --body`),
  and reply with the issue number and title.
- **A near match on a related symptom**: file, and put "Related: #n"
  as the last line of the body.
- **No match**: file.

If the search returns nothing and the words were specific, one retry
with a broader word is allowed; a second empty search means file.

## 3. Write it like a person

Bug or request is decided by one question: is something broken that
should work (bug), or is this something that does not exist yet and
someone wants (feature request, label `enhancement`)? A request's
search words are the want, not a symptom ("shopping list voice",
"kid profile timer"), and its body answers what someone wants and why
it would help, in a sentence a parent would say; no spec, no design.

The title makes sense on a phone with zero context: what the person
saw, in one sentence, no ticket prefix (GitHub's template adds its
own). The body follows the org template's questions, in plain words
(`CLAUDE.md`, Issues): for a bug, what happened, what was expected
instead, steps if known, where it happened; for a request, what
someone wants and why it would help. Technical detail (file and line,
log lines, the exact command) goes at the bottom under a "Technical
detail" line, never instead of the plain summary. AI writing rules
apply: no em dashes, no filler vocabulary, no exclamation points. No
family names, hostnames, LAN addresses, or secrets; persona-roster
names only in examples.

Keep it short: three to eight sentences of summary, then the detail.
Write the body to a file in the scratchpad and pass it with
`--body-file`, so a long body never has to be quoted on a command line.

## 4. File it

```
gh issue create -R getmaipai/<repo> --title "<title>" \
  --body-file <path> --label <bug|enhancement>
```

Labels: `bug` for something broken, `enhancement` for a request or
idea, plus `accessibility` or `documentation` when that is the
subject. Nothing else; no milestone, no assignee, no project.

## 5. Reply

One line: the new issue's number, title, and URL; or, if it was a
duplicate, the existing number and that a comment was added. If the
defect was found mid-task and is not being fixed now, say so in the
same line so the session's status block can carry it.

## Not this skill's job

Fixing the defect, adding it to `docs/BACKLOG.md` (the backlog tracks
build status, issues track bugs and one-off requests; a finding that
needs a design pass gets a BACKLOG item by the session, separately),
or closing issues (a commit's "Closes #n" line does that).
