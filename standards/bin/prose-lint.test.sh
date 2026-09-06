#!/usr/bin/env bash
# Regression test for prose-lint.sh. No shell-test framework exists in this
# repo (standards/tests/{ts,py} round-trip generated schema fixtures, an
# unrelated concern) and this is a small, dependency-free bash script, so
# this is a small, dependency-free bash test: build a throwaway git repo
# with fixture Markdown, run prose-lint.sh against it, and assert the exact
# set of violation lines it reports.
#
# Written the same day (2026-09-06) prose-lint.sh's own false positive on
# home-backend package READMEs' `<!-- Store card ... -->` opener was found
# live, blocking a real commit - per CLAUDE.md's testing standard, "every
# real failure becomes a permanent regression test, first."
set -uo pipefail
cd "$(dirname "$0")/../.."
PROSE_LINT="$(pwd)/standards/bin/prose-lint.sh"

TMP_REPO=$(mktemp -d)
trap 'rm -rf "$TMP_REPO"' EXIT
cd "$TMP_REPO"
git init -q

FAIL=0

assert() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $desc"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    FAIL=1
  fi
}

# Real violations still caught, each on its own file so line numbers in the
# assertions below stay simple and independent of the other cases.
cat > exclamation.md <<'EOF'
This is exciting!
EOF
cat > em-dash.md <<'EOF'
An em dash — right here.
EOF
cat > filler.md <<'EOF'
We should leverage this synergy.
EOF
cat > not-just.md <<'EOF'
This is not just good, it's great.
EOF
git add exclamation.md em-dash.md filler.md not-just.md

# The false positive this fix closes: a single-line HTML comment (the
# store-card opener every home-backend package README carries) must never
# read as an exclamation point.
cat > html-comment.md <<'EOF'
<!-- Store card. Dad test: grade 6, one action per step, no jargon. -->
EOF
git add html-comment.md

# A comment that spans multiple lines: nothing inside it (including a real
# "!") should be reported, and scanning must resume normally once it closes.
cat > multiline-comment.md <<'EOF'
A multi-line
<!-- comment
has an exclamation! inside it
spanning lines -->
after the comment!
EOF
git add multiline-comment.md

# A code span containing a literal, unmatched `<!--` must not be
# mistranscribed as a real HTML-comment opener and swallow the rest of the
# file - the ordering bug a review caught in this fix's first draft.
cat > code-span-with-marker.md <<'EOF'
Docs show `<!-- like this` for details!
This line has an em dash — too, after the code span.
EOF
git add code-span-with-marker.md

# Banned vocabulary or an em dash INSIDE a comment is markup/authoring
# metadata, not prose a reader ever sees, and must not fire either -
# applying the fix's own stripping to every check, not just the
# exclamation one.
cat > vocab-inside-comment.md <<'EOF'
<!-- a comment that mentions leverage and has an em dash — inside it -->
Real prose after, with no violation.
EOF
git add vocab-inside-comment.md

# The explicit allow marker still silences everything on its own line.
cat > allowed.md <<'EOF'
<!-- prose-lint: allow --> this line has an em dash — but is allowed.
EOF
git add allowed.md

# Markdown image syntax's own `!` (immediately before `[`) must not read
# as an exclamation point - found live (2026-09-06, Session E, `home`)
# blocking a commit of real tier-1 docs embedding real screenshots, which
# `docs/STYLE.md`'s own rule calls for. A real exclamation point on the
# same line must still be caught.
cat > image.md <<'EOF'
![alt text](../assets/screens/home.png)
EOF
git add image.md
cat > image-and-real-exclamation.md <<'EOF'
![alt text](../assets/screens/home.png) and this part is exciting!
EOF
git add image-and-real-exclamation.md

OUTPUT=$("$PROSE_LINT" . 2>&1)
STATUS=$?

assert "exit status is non-zero (real violations exist)" "1" "$STATUS"
assert "exclamation.md:1 flagged" "1" "$(echo "$OUTPUT" | grep -c "exclamation point in exclamation.md:1$")"
assert "em-dash.md:1 flagged" "1" "$(echo "$OUTPUT" | grep -c "em dash (U+2014) in em-dash.md:1$")"
assert "filler.md:1 flagged" "1" "$(echo "$OUTPUT" | grep -c "AI filler vocabulary in filler.md:1$")"
assert "not-just.md:1 flagged" "1" "$(echo "$OUTPUT" | grep -c "not just X, it's Y' construction in not-just.md:1$")"
assert "html-comment.md not flagged at all" "0" "$(echo "$OUTPUT" | grep -c "html-comment.md")"
assert "multiline-comment.md's real exclamation (line 5, after the comment) flagged" "1" \
  "$(echo "$OUTPUT" | grep -c "exclamation point in multiline-comment.md:5$")"
assert "multiline-comment.md's in-comment exclamation (line 3) NOT flagged" "0" \
  "$(echo "$OUTPUT" | grep -c "multiline-comment.md:3$")"
assert "code-span-with-marker.md's real exclamation (line 1) flagged" "1" \
  "$(echo "$OUTPUT" | grep -c "exclamation point in code-span-with-marker.md:1$")"
assert "code-span-with-marker.md's real em dash (line 2) still flagged (no swallowed state)" "1" \
  "$(echo "$OUTPUT" | grep -c "em dash (U+2014) in code-span-with-marker.md:2$")"
assert "vocab-inside-comment.md not flagged at all" "0" "$(echo "$OUTPUT" | grep -c "vocab-inside-comment.md")"
assert "allowed.md not flagged at all" "0" "$(echo "$OUTPUT" | grep -c "allowed.md")"
assert "image.md not flagged at all" "0" "$(echo "$OUTPUT" | grep -c "image.md:1$")"
assert "image-and-real-exclamation.md's real exclamation still flagged" "1" \
  "$(echo "$OUTPUT" | grep -c "exclamation point in image-and-real-exclamation.md:1$")"

if [ "$FAIL" -eq 0 ]; then
  echo "prose-lint.test.sh: all assertions passed"
fi
exit "$FAIL"
