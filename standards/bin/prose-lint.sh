#!/usr/bin/env bash
# @maipai/standards: prose lint.
#
# Enforces the org's AI writing standards (CLAUDE.md > Writing style) against
# every tracked Markdown file: no em dashes, no AI filler vocabulary, no
# "not just X, it's Y" constructions, no exclamation points outside fenced
# or inline code. Exits non-zero on any hit.
#
# A line that ends with the literal marker `<!-- prose-lint: allow -->` is
# exempt from every check on this file. Use it only for a line that names a
# banned construct as documentation of the rule itself (a style guide has to
# say the words it bans); never to silence an actual violation.
#
# Written for bash 3.2 (macOS system bash): no mapfile, no associative
# arrays. The scan runs inside a pipeline subshell, so the fail flag is
# passed back through a temp file rather than a variable.
set -uo pipefail
REPO_ROOT="${1:-.}"
cd "$REPO_ROOT"

STATUS_FILE=$(mktemp)
echo 0 > "$STATUS_FILE"
ALLOW_MARKER='<!-- prose-lint: allow -->'

git ls-files '*.md' 2>/dev/null | while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue

  in_code=0
  in_inline=0
  in_html_comment=0
  ln=0
  while IFS= read -r line || [ -n "$line" ]; do
    ln=$((ln + 1))
    case "$line" in
      '```'*) in_code=$((1 - in_code)); continue ;;
    esac
    [ "$in_code" -eq 0 ] || continue

    case "$line" in
      *"$ALLOW_MARKER"*) continue ;;
    esac

    # Strip inline (single-backtick) code spans first: real technical
    # prose leans on `!==`, a non-null assertion, or a shell `!` inside
    # one, and a code span can itself contain a literal `<!--` (e.g.
    # documenting HTML-comment syntax) that must never be mistaken for a
    # real, unmatched comment opener by the HTML-comment pass below -
    # stripping code first removes that content before the comment
    # scanner ever sees it. A span that wraps across a line break
    # (docs/dev.md's own 80-column convention does this) carries the
    # open/closed state in `in_inline` the same way `in_code` already
    # tracks fenced blocks above.
    line_no_inline_code=""
    rest="$line"
    while true; do
      if [ "$in_inline" -eq 1 ]; then
        if [[ "$rest" == *'`'* ]]; then
          rest="${rest#*\`}"
          in_inline=0
        else
          rest=""
          break
        fi
      elif [[ "$rest" == *'`'* ]]; then
        line_no_inline_code="$line_no_inline_code${rest%%\`*}"
        rest="${rest#*\`}"
        if [[ "$rest" == *'`'* ]]; then
          rest="${rest#*\`}"
        else
          in_inline=1
          rest=""
          break
        fi
      else
        line_no_inline_code="$line_no_inline_code$rest"
        rest=""
        break
      fi
    done

    # Then strip HTML comments (`<!-- ... -->`) from what's left: a
    # comment is markup and authoring metadata, not prose a reader ever
    # sees, the same reason code spans are excluded above - every
    # store-card README in home/backend/packages/*/README.md opens with
    # one (`<!-- Store card. ... -->`), and its literal `!` was a real
    # false positive found live (2026-09-06) blocking
    # session-d-packages-and-store.md's step 1 commit on home. Applied
    # to every check below, not just the exclamation one: a banned
    # filler word or an em dash inside a comment is exactly the same
    # kind of false positive, just on a different check. Handles a
    # comment that opens and closes on the same line (the common case)
    # and one that spans multiple lines, mirroring `in_inline`'s own
    # state-carrying shape.
    prose=""
    rest="$line_no_inline_code"
    while true; do
      if [ "$in_html_comment" -eq 1 ]; then
        if [[ "$rest" == *'-->'* ]]; then
          rest="${rest#*-->}"
          in_html_comment=0
        else
          rest=""
          break
        fi
      elif [[ "$rest" == *'<!--'* ]]; then
        prose="$prose${rest%%<!--*}"
        rest="${rest#*<!--}"
        if [[ "$rest" == *'-->'* ]]; then
          rest="${rest#*-->}"
        else
          in_html_comment=1
          rest=""
          break
        fi
      else
        prose="$prose$rest"
        rest=""
        break
      fi
    done

    if [[ "$prose" == *"—"* ]]; then
      echo "em dash (U+2014) in $f:$ln"
      echo 1 > "$STATUS_FILE"
    fi

    if echo "$prose" | grep -qniE 'delve|seamless(ly)?|\brobust\b|leverage|empower|elevate|streamline|game-changer|in today.s world|it.s important to note'; then
      echo "AI filler vocabulary in $f:$ln"
      echo 1 > "$STATUS_FILE"
    fi

    if echo "$prose" | grep -qniE "not just [^,.]+,? (it.s|it is) "; then
      echo "'not just X, it's Y' construction in $f:$ln"
      echo 1 > "$STATUS_FILE"
    fi

    if [[ "$prose" == *"!"* ]]; then
      echo "exclamation point in $f:$ln"
      echo 1 > "$STATUS_FILE"
    fi
  done < "$f"
done

STATUS=$(cat "$STATUS_FILE")
rm -f "$STATUS_FILE"
exit "$STATUS"
