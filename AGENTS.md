# cl-tidyr Agents and Milestones

## M0: Infrastructure
**Goal**: Project setup & CI ready.
- [ ] `cl-tidyr.asd`
- [ ] Test harness (FiveAM)
- [ ] `src/packages.lisp`

## M1: String Verbs
**Goal**: Basic column splitting/combining.
- [ ] Test: `unite` tests
- [ ] Implement: `unite`
- [ ] Test: `separate` tests
- [ ] Implement: `separate`

## M2: Pivot Longer
**Goal**: The `gather` equivalent.
- [ ] Test: Simple gather
- [ ] Implement: `pivot-longer` core
- [ ] Test: Selection logic

## M3: Pivot Wider
**Goal**: The `spread` equivalent.
- [ ] Test: Simple spread
- [ ] Implement: `pivot-wider` core

## M4: Missing Values
**Goal**: NA handling.
- [ ] `drop-na`, `fill`, `replace-na`

## M5: Rectification
- [ ] `complete`, `expand`

## Change Discipline (git + documentation)

Every change to this repository must be reconstructible later: what changed,
why, and what it means for users. Agents and humans follow these rules.

1. **Branch, never commit straight to `main`.** Use a topic branch such as
   `fix/<topic>` or `feat/<topic>` (cross-package work in the tidystat effort
   uses `fix/tidystat-phase0`, `feat/tidystat-phase1`, ...).
2. **One logical change per commit.** Test-suite repairs, bug fixes, new
   features and documentation go in separate commits, so each can be
   reviewed, bisected or reverted on its own.
3. **Commit messages explain the why.** Format:
   ```
   <area>: <imperative summary, <= 72 chars>

   Problem:  what was wrong / missing, with the observable symptom.
   Cause:    the root cause (file:function), if it is a fix.
   Change:   what this commit does.
   Impact:   behaviour change for users; mark BREAKING if any.
   Tests:    which tests were added/changed, and the suite result.
   ```
4. **Every commit updates `CHANGELOG.md`** under `## [Unreleased]`, in the
   sections *Fixed*, *Added*, *Changed*, *Breaking*, *Tests*. Each entry
   says what users will notice and names the commit topic.
5. **Run the full test suite before committing** (`make test`, or from the
   umbrella repo `../cl-tidystat/scripts/run-tests.sh <this-package>`) and put
   the result in the commit message. Never commit with a red suite unless
   the commit message says so and why.
6. **Cross-package changes** (e.g. an API in `cl-vctrs-lite` used by
   `cl-dplyr`) are recorded in both repos' changelogs and in
   `../cl-tidystat/docs/CHANGES-phase*.md`, which links the commits.
7. **Push only after review**; do not rewrite history that has been pushed.

## Parity work (R tidyverse equivalence)

This repository is part of the plan to reach full parity with the current
R tidyverse. Milestones owned by this repository: **TR1, TR2, TR3, TR4, TR5**.

- Plan, conventions (R -> Lisp names, arguments, types, 0-based indices)
  and the step-by-step workflow: `docs/PARITY-PLAN.md` in
  `../cl-tidystat` (GitHub: gwangjinkim/cl-tidystat, private; ask the
  maintainer for access).
- Function lists with status and target names:
  `../cl-tidystat/parity/backlog/<ID>.md`; overview in `INDEX.md`.
- Work on a branch `feat/parity-<ID>`, write conformance cases first,
  and regenerate the parity status in cl-tidystat after each step.
