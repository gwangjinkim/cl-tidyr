# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). See AGENTS.md
("Change Discipline") for how entries and commits are written.

## [Unreleased]

### Added
- `parity-TR1`: Add `expand-grid`, `crossing`, `nesting`, `extract`,
  `full-seq`, `uncount` and variadic `.fill`, with typed empty results,
  factors/dates/list columns, grouping and shared selection support.
  Independent ICU 76.1 root collation and pinned PCRE2 10.47 captures match
  the pinned reference environment without invoking R at runtime.
- `parity-TS2-adapters`: pivot/unite selection accepts quoted native
  operator and helper expressions, alone or in established selector lists.

- Re-export the shared `cl-tidyselect` TS1 helpers. `pivot-longer` and
  `unite` can use helper thunks evaluated in the input column context;
  explicit names and zero-based index lists continue to work
  (topic: parity-TS1-adapters).
- `fill` on a non-tibble behaves exactly like `cl:fill`. cl-tidyr's `fill`
  shadows `cl:fill`, so in any package using cl-tidyr (or cl-tidyverse)
  `(fill (make-list 3) 0)` used to be misread as a tibble fill; now the
  shadowing is transparent (topic: CL shadowing).

### Fixed
- `parity-TR1`: Preserve duplicate rows in completion and owner prototypes
  in missing-value/expansion results; support all four fill directions,
  actual IEEE NaN, logical FALSE and list NULL distinctly. Keep callable
  `fill`, CL:FILL delegation and existing column names resembling options.
  Packed matrix/frame columns and full extraction conversion remain partial.
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
- `parity-TS2-adapters`: selection predicates receive the actual frame
  context through the shared engine; reshape renaming remains an error.

- The existing internal column selector now uses `cl-tidyselect`, preserves
  typed columns and empty-schema row counts, and consumes the same helper
  indices as dplyr. Renaming selectors signal a shared selection error, matching
  R's reshape contract. Full selection expressions remain TS2;
  reshape parity remains TR1–TR5 (topic: parity-TS1-adapters).
- AGENTS.md: "Parity work" section listing this repository's parity
  milestones (TR1, TR2, TR3, TR4, TR5) and where the plan and backlog live
  (topic: parity plan).
- Stopped tracking `build/` (219 files, 5.4M): the ASDF/Roswell compile
  cache that `make test` writes via `XDG_CACHE_HOME=$(PWD)/build`. It held
  compiled fasls, including Quicklisp internals and absolute local paths.
  `build/` is now in `.gitignore`; local files are untouched. Old copies
  remain in history (topic: repo hygiene).

### Tests
- `parity-TR1`: Native suite grows from 90 to 141 passing checks; all 137
  new R cases pass, including empty/grouped outputs, Unicode captures,
  collation, lossless replacement and NaN. Full ecosystem verification is
  3832 checks and 2820 R cases, all passing; all 56 golden topics reproduce.
  Wrong/missing ICU rejection and loader recovery pass on macOS; bootstrap
  source build and Linux remain unverified.
- `parity-TS2-adapters`: R comparisons and integration regressions cover
  quoted ranges/helpers, owner preservation and prohibited aliases.

- New helper-based pivot/unite, empty schema, positional order, missing-name
  validation, prohibited renaming, and shared-symbol regressions. Full umbrella
  package suite: 90/90 checks (65 before; 25 added) (topic: parity-TS1-adapters).
- `complete-basic`: replaced bare `(is found-missing)` (rejected by current
  FiveAM at macroexpansion) with `(is-true found-missing)`. Suite 56/56.
- 3 new tests in `tests/test-string-verbs.lisp` for separate/unite.
  Suite 63/63.
- New `fill-on-sequences-behaves-like-cl-fill`. Suite 65/65.
