#!/usr/bin/env bash
# @maipai/standards: architect-gate lint (ARCH-GATE-01).
#
# In a repo that keeps docs/design/RULES.md, checks that the rulebook and
# the records it names stay connected:
#   (a) every `## ` area names a Record: line, and every link on it points
#       at a file that exists;
#   (b) every record so named has a `## Supersedes` heading;
#   (c) every `> **Superseded` marker in docs/ links to a file that exists.
# A repo without docs/design/RULES.md still gets check (c) only. Exits non-zero on
# any failure, naming the file and the fix.
set -uo pipefail
ROOT="${1:-.}"
cd "$ROOT"
RULES="docs/design/RULES.md"
HAVE_RULES=1
[ -f "$RULES" ] || HAVE_RULES=0
STATUS=0
fail() { echo "$1"; STATUS=1; }

# Link targets in a chunk of text, anchors and web links dropped.
targets() {
  grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//; s/#.*$//' | grep -vE '^$|^[a-z]+:' || true
}

area=""
rec_seen=0
rec_links=0
records=""
flush_area() {
  if [ -n "$area" ] && [ "$rec_seen" -eq 0 ]; then
    fail "$RULES: area \"$area\" names no design record. Add a line 'Record: [title](../plans/<file>.md)' under its heading."
  elif [ -n "$area" ] && [ "$rec_links" -eq 0 ]; then
    fail "$RULES: area \"$area\" has a Record: line with no link. Link the record file."
  fi
}
in_rec=0
[ "$HAVE_RULES" -eq 1 ] && while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    "## "*)
      flush_area
      area="${line#\#\# }"; rec_seen=0; rec_links=0; in_rec=0 ;;
    "Record:"*)
      rec_seen=1; in_rec=1 ;;
    "") in_rec=0 ;;
  esac
  if [ "$in_rec" -eq 1 ]; then
    t=$(printf '%s\n' "$line" | targets)
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      rec_links=$((rec_links + 1))
      path="docs/design/$rel"
      if [ ! -f "$path" ]; then
        fail "$RULES: area \"$area\" names a record that does not exist: $rel. Fix the link or write the record."
      else
        records="$records
$path"
      fi
    done <<< "$t"
  fi
done < "$RULES"
[ "$HAVE_RULES" -eq 1 ] && flush_area

# (b) every named record has a Supersedes heading.
for rec in $(printf '%s\n' "$records" | sort -u); do
  [ -f "$rec" ] || continue
  if ! grep -qE '^## Supersedes' "$rec"; then
    fail "$rec: named by $RULES but has no '## Supersedes' heading. Add one listing what this record replaces (or 'Nothing.')."
  fi
done

# (c) every '> **Superseded' marker in docs/ links to a file that exists.
if [ -d docs ]; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    dir=$(dirname "$f")
    # Each marker plus the blockquote lines that continue it.
    chunks=$(awk -v F="$f" '
      /^> \*\*Superseded/ { if (blk != "") print blk; blk=NR "\t" $0; inb=1; next }
      inb && /^>/ { blk = blk " " $0; next }
      { if (blk != "") print blk; blk=""; inb=0 }
      END { if (blk != "") print blk }
    ' "$f")
    [ -n "$chunks" ] || continue
    while IFS= read -r chunk; do
      [ -n "$chunk" ] || continue
      ln="${chunk%%$'\t'*}"; body="${chunk#*$'\t'}"
      t=$(printf '%s\n' "$body" | targets)
      if [ -z "$t" ]; then
        fail "$f:$ln: '> **Superseded' marker links to nothing. Link the record that replaced it."
        continue
      fi
      while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        if [ ! -f "$dir/$rel" ] && [ ! -f "$rel" ]; then
          fail "$f:$ln: '> **Superseded' marker points at $rel, which does not exist. Fix the link."
        fi
      done <<< "$t"
    done <<< "$chunks"
  done < <(git ls-files 'docs/*.md' 2>/dev/null; git ls-files --others --exclude-standard 'docs/*.md' 2>/dev/null)
fi

if [ "$HAVE_RULES" -eq 0 ]; then
  [ "$STATUS" -eq 0 ] && echo "architect-check: no $RULES, nothing to check beyond the Superseded markers"
  exit "$STATUS"
fi
[ "$STATUS" -eq 0 ] && echo "architect-check: rulebook, records and Superseded markers are consistent"
exit "$STATUS"
