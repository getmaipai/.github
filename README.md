# getmaipai/.github

The MaiPai org's shared home:

- **[profile/README.md](profile/README.md)**: the org profile shown on
  [github.com/getmaipai](https://github.com/getmaipai).
- **[CLAUDE.md](CLAUDE.md)**: org-wide standards for every repo (git workflow,
  verification, docs, privacy, releases, security). Claude Code sessions load
  this automatically via the directory-level copy on the dev machine.
- **[STACK.md](STACK.md)**: the tech stack standard.
- **[docs/STYLE.md](docs/STYLE.md)**: the three-tier documentation style guide.
- **[SECURITY.md](SECURITY.md)** / **[CONTRIBUTING.md](CONTRIBUTING.md)**:
  org-default community health files (apply to every repo without one).
- **[plugin/](plugin/)**: the `maipai` Claude Code plugin: shared skills
  (`release`, `update-docs`, `verify`, `new-package`, `standards-check`,
  `verify-screenshots`) and hooks (a blind-staging gate, session-start
  repo context; see [plugin/hooks/README.md](plugin/hooks/README.md)).
  Install once: `/plugin marketplace add getmaipai/.github` then
  `/plugin install maipai`.
