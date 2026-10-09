# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). See AGENTS.md
("Change Discipline") for how entries and commits are written.

## [Unreleased]

### Added
- `fill` on a non-tibble behaves exactly like `cl:fill`. cl-tidyr's `fill`
  shadows `cl:fill`, so in any package using cl-tidyr (or cl-tidyverse)
  `(fill (make-list 3) 0)` used to be misread as a tibble fill; now the
  shadowing is transparent (topic: CL shadowing).

### Fixed
- **cl-tidyr did not load at all**: `no symbol named "SELECT" in
  "CL-DPLYR"`. cl-dplyr renamed its verbs to `.select` etc. (cl-dplyr
  commit 9c62711), and `.select` is a macro, so it cannot be `apply`ed.
  cl-tidyr now selects columns with `cl-tibble:slice` via an internal
  `select-cols`, and **no longer depends on cl-dplyr** at all, so renames
  there cannot break it again (topic: decouple from cl-dplyr).
- **`separate` silently dropped columns**: with `into '("x" "y")`, one
  row having fewer pieces (e.g. `"c"` next to `"a-b"`) removed column `y`
  for *all* rows, because the transpose `(apply #'mapcar #'vector rows)`
  stops at the shortest row. Rows are now padded to `(length into)` with
  NA (tidyr's `fill = "right"`) (topic: separate/unite).
- `separate` signalled a type error on NA cells; NA now yields NA pieces.
- `unite` reordered the remaining columns (`set-difference`); order is now
  preserved, with the united column appended.
- `unite :na-rm t` only dropped `NIL`, not `*na*`, producing `"NA_q"`;
  it now drops both.

### Changed
- AGENTS.md: "Parity work" section listing this repository's parity
  milestones (TR1, TR2, TR3, TR4, TR5) and where the plan and backlog live
  (topic: parity plan).
- Stopped tracking `build/` (219 files, 5.4M): the ASDF/Roswell compile
  cache that `make test` writes via `XDG_CACHE_HOME=$(PWD)/build`. It held
  compiled fasls, including Quicklisp internals and absolute local paths.
  `build/` is now in `.gitignore`; local files are untouched. Old copies
  remain in history (topic: repo hygiene).

### Tests
- `complete-basic`: replaced bare `(is found-missing)` (rejected by current
  FiveAM at macroexpansion) with `(is-true found-missing)`. Suite 56/56.
- 3 new tests in `tests/test-string-verbs.lisp` for separate/unite.
  Suite 63/63.
- New `fill-on-sequences-behaves-like-cl-fill`. Suite 65/65.
