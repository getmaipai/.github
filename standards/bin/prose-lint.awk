# @maipai/standards: prose lint, the line-scanning half of prose-lint.sh.
#
# Rewritten from a pure-bash version (2026-09-06): stripping inline code
# spans and HTML comments with nested `while` loops of bash parameter
# expansion, per character, across every line of every tracked Markdown
# file, took over a minute on this org's own docs/dev.md files (thousands
# of lines each, dense with inline code) - a real, permanent per-commit
# cost for every repo. The same state-machine logic in awk (C-native
# string ops, no subshells) does the same job in a fraction of a second.
#
# Called as `awk -v allow_marker="..." -f prose-lint.awk file1 file2 ...`.
# Prints one violation line per hit, in the same format the bash version
# used, and exits 1 if any file had one.
BEGIN {
  status = 0
  in_code = 0
  in_inline = 0
  in_html_comment = 0
  em_dash = sprintf("%c%c%c", 226, 128, 148) # U+2014 as raw UTF-8 bytes
}

# A new file resets every carried-across-lines state: a fenced block or an
# inline span can never span a file boundary.
FNR == 1 {
  in_code = 0
  in_inline = 0
  in_html_comment = 0
}

substr($0, 1, 3) == "```" {
  in_code = 1 - in_code
  next
}

in_code { next }

index($0, allow_marker) > 0 { next }

{
  line = $0

  # Strip inline (single-backtick) code spans first: real technical prose
  # leans on `!==`, a non-null assertion, or a shell `!` inside one, and a
  # code span can itself contain a literal `<!--` (documenting HTML-
  # comment syntax) that must never be mistaken for a real, unmatched
  # comment opener by the next pass - stripping code first removes that
  # content before the comment scanner ever sees it. A span that wraps
  # across a line break (this org's own 80-column doc convention does
  # this) carries the open/closed state in `in_inline` across lines, the
  # same way `in_code` does for fenced blocks above.
  out1 = ""
  rest = line
  while (length(rest) > 0) {
    if (in_inline) {
      pos = index(rest, "`")
      if (pos == 0) { rest = ""; break }
      rest = substr(rest, pos + 1)
      in_inline = 0
    } else {
      pos = index(rest, "`")
      if (pos == 0) { out1 = out1 rest; rest = ""; break }
      out1 = out1 substr(rest, 1, pos - 1)
      rest = substr(rest, pos + 1)
      pos2 = index(rest, "`")
      if (pos2 == 0) { in_inline = 1; rest = ""; break }
      rest = substr(rest, pos2 + 1)
    }
  }

  # Then strip HTML comments from what's left: authoring metadata, not
  # prose a reader ever sees - every store-card README in
  # home/backend/packages/*/README.md opens with one, and its literal `!`
  # was a real false positive found live (2026-09-06, Session D) blocking
  # a commit. A filler word or an em dash inside a comment is the same
  # false-positive class, so this applies to every check below, not just
  # the exclamation one. Mirrors `in_inline`'s own state-carrying shape
  # for a comment spanning multiple lines.
  prose = ""
  rest = out1
  while (length(rest) > 0) {
    if (in_html_comment) {
      pos = index(rest, "-->")
      if (pos == 0) { rest = ""; break }
      rest = substr(rest, pos + 3)
      in_html_comment = 0
    } else {
      pos = index(rest, "<!--")
      if (pos == 0) { prose = prose rest; rest = ""; break }
      prose = prose substr(rest, 1, pos - 1)
      rest = substr(rest, pos + 4)
      pos2 = index(rest, "-->")
      if (pos2 == 0) { in_html_comment = 1; rest = ""; break }
      rest = substr(rest, pos2 + 3)
    }
  }

  if (index(prose, em_dash) > 0) {
    print "em dash (U+2014) in " FILENAME ":" FNR
    status = 1
  }

  if (prose ~ /[Dd][Ee][Ll][Vv][Ee]|[Ss][Ee][Aa][Mm][Ll][Ee][Ss][Ss](ly)?|(^|[^A-Za-z])[Rr][Oo][Bb][Uu][Ss][Tt]([^A-Za-z]|$)|[Ll][Ee][Vv][Ee][Rr][Aa][Gg][Ee]|[Ee][Mm][Pp][Oo][Ww][Ee][Rr]|[Ee][Ll][Ee][Vv][Aa][Tt][Ee]|[Ss][Tt][Rr][Ee][Aa][Mm][Ll][Ii][Nn][Ee]|[Gg][Aa][Mm][Ee]-[Cc][Hh][Aa][Nn][Gg][Ee][Rr]|[Ii][Nn] [Tt][Oo][Dd][Aa][Yy].[Ss] [Ww][Oo][Rr][Ll][Dd]|[Ii][Tt].[Ss] [Ii][Mm][Pp][Oo][Rr][Tt][Aa][Nn][Tt] [Tt][Oo] [Nn][Oo][Tt][Ee]/) {
    print "AI filler vocabulary in " FILENAME ":" FNR
    status = 1
  }

  if (prose ~ /[Nn][Oo][Tt] [Jj][Uu][Ss][Tt] [^,.]+,? ([Ii][Tt].[Ss]|[Ii][Tt] [Ii][Ss]) /) {
    print "'not just X, it's Y' construction in " FILENAME ":" FNR
    status = 1
  }

  if (index(prose, "!") > 0) {
    print "exclamation point in " FILENAME ":" FNR
    status = 1
  }
}

END { exit status }
