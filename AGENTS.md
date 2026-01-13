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
