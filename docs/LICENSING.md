# Licensing

Pinned from `CLAUDE.md`'s "Topic docs" index. Load this at repo setup,
release time, or when adding a dependency and its license is in doubt.

- **Every repo carries a LICENSE from its first commit: AGPL-3.0.** It fits
  the MaiPai promise (anyone who runs or hosts a modified version must share
  their changes) and it applies to private repos too, so nothing scrambles
  for a license on the day it goes public.
- **Every repo with third-party components carries a NOTICE file** listing
  required attributions. The release skill checks NOTICE against dependency
  changes since the last tag; new components with attribution requirements
  get added before the release cuts.
- READMEs state the license in one line at the bottom, linking to LICENSE.
- Never vendor code whose license is incompatible with AGPL-3.0; when in
  doubt, flag it to Jesse before adding the dependency.
- **Copyright stays 100% with Jesse (dual-licensing and sale stay possible):**
  - Every LICENSE carries the line "Copyright (c) 2026 Jesse Torres" (update
    the year range at each release that touches it).
  - **Never merge an outside contribution without a signed copyright
    assignment.** No exceptions, however small the patch. A drive-by fix
    without paperwork gets reimplemented from the issue description instead
    of merged.
  - Because Jesse is sole copyright holder, he is not bound by the AGPL
    himself: commercial licenses can be sold separately, and the project can
    be sold outright (already-published versions remain AGPL forever).
