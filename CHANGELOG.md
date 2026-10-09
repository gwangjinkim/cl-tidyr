# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). See AGENTS.md
("Change Discipline") for how entries and commits are written.

## [Unreleased]

### Fixed
- **cl-tidyr did not load at all**: `no symbol named "SELECT" in
  "CL-DPLYR"`. cl-dplyr renamed its verbs to `.select` etc. (cl-dplyr
  commit 9c62711), and `.select` is a macro, so it cannot be `apply`ed.
  cl-tidyr now selects columns with `cl-tibble:slice` via an internal
  `select-cols`, and **no longer depends on cl-dplyr** at all, so renames
  there cannot break it again (topic: decouple from cl-dplyr).

### Tests
- `complete-basic`: replaced bare `(is found-missing)` (rejected by current
  FiveAM at macroexpansion) with `(is-true found-missing)`. Suite 56/56.
