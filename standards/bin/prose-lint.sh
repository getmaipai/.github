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

    # Strip inline (single-backtick) code spans before the exclamation
    # check below: real technical prose leans on `!==`, a non-null
    # assertion, or a shell `!` inside one. A span that wraps across a
    # line break (docs/dev.md's own 80-column convention does this)
    # carries the open/closed state in `in_inline` the same way `in_code`
    # already tracks fenced blocks above.
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

    if [[ "$line" == *"—"* ]]; then
      echo "em dash (U+2014) in $f:$ln"
      echo 1 > "$STATUS_FILE"
    fi

    if echo "$line" | grep -qniE 'delve|seamless(ly)?|\brobust\b|leverage|empower|elevate|streamline|game-changer|in today.s world|it.s important to note'; then
      echo "AI filler vocabulary in $f:$ln"
      echo 1 > "$STATUS_FILE"
    fi

    if echo "$line" | grep -qniE "not just [^,.]+,? (it.s|it is) "; then
      echo "'not just X, it's Y' construction in $f:$ln"
      echo 1 > "$STATUS_FILE"
    fi

    if [[ "$line_no_inline_code" == *"!"* ]]; then
      echo "exclamation point in $f:$ln"
      echo 1 > "$STATUS_FILE"
    fi
  done < "$f"
done

STATUS=$(cat "$STATUS_FILE")
rm -f "$STATUS_FILE"
exit "$STATUS"
